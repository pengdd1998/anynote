import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js) 'package:anynote/core/stubs/io_stub.dart';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../crypto/crypto_service.dart';
import '../database/app_database.dart';
import '../database/daos/note_properties_dao.dart';
import '../storage/image_storage.dart';
import '../../features/notes/domain/markdown_export_service.dart';
import 'import_models.dart';

/// Configuration options for the import pipeline.
class ImportOptions {
  /// Whether to preserve dates from YAML frontmatter.
  final bool preserveDates;

  /// Whether to import tags from frontmatter.
  final bool importTags;

  /// Whether to import recognized properties (status, priority, etc.).
  final bool importProperties;

  /// Whether this is an Obsidian vault import (enables wiki link and
  /// image handling).
  final bool isObsidianImport;

  /// Root directory of the Obsidian vault (used for resolving relative image
  /// paths). Only used when [isObsidianImport] is true.
  final String? obsidianVaultPath;

  const ImportOptions({
    this.preserveDates = true,
    this.importTags = true,
    this.importProperties = true,
    this.isObsidianImport = false,
    this.obsidianVaultPath,
  });
}

/// Recognized frontmatter keys that map to [NoteProperties].
/// Values indicate the property type: 'text' or 'date'.
const _propertyKeys = <String, String>{
  'status': 'text',
  'priority': 'text',
  'due_date': 'date',
  'start_date': 'date',
};

/// Image extensions handled during Obsidian vault import.
const _imageExtensions = {
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
  '.svg',
  '.bmp',
};

/// Service for importing Markdown files into the AnyNote database.
///
/// The import pipeline has two stages:
///   1. **Parsing** -- recursively scans a directory for `.md` files and
///      extracts frontmatter metadata (title, date, tags, properties).
///   2. **Importing** -- encrypts each parsed note with [CryptoService] and
///      persists it via [NotesDao], creating tag associations and note
///      properties as needed.
///
/// Both stages emit [ImportProgress] events so the UI can display a progress
/// indicator. The convenience method [importFromDirectory] chains both stages
/// and returns a final [ImportResult].
///
/// When [ImportOptions.isObsidianImport] is true, the service additionally:
///   - Converts `[[wiki links]]` to the app's internal `[[title]]` format.
///   - Copies referenced images to the app's image storage.
///   - Handles `![[image.png]]` embed syntax.
class MarkdownImportService {
  MarkdownImportService({
    required CryptoService cryptoService,
    required AppDatabase database,
    ImportOptions options = const ImportOptions(),
  })  : _crypto = cryptoService,
        _db = database,
        _options = options;

  final CryptoService _crypto;
  final AppDatabase _db;
  final ImportOptions _options;

  static const _uuid = Uuid();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Recursively scan [dir] for `.md` files and yield progress events.
  ///
  /// Files that cannot be decoded as UTF-8 or are empty are skipped. Their
  /// paths are tracked in the returned [_ParsedBatch] so the caller (or
  /// [importFromDirectory]) can report accurate skip/error counts.
  Stream<ImportProgress> parseDirectory(Directory dir) async* {
    if (kIsWeb) {
      yield const ImportProgress(
        current: 0,
        total: 0,
        currentFile: '',
        status: ImportStatus.done,
      );
      return;
    }
    final mdFiles = await _collectMarkdownFiles(dir);
    final total = mdFiles.length;

    if (total == 0) {
      yield const ImportProgress(
        current: 0,
        total: 0,
        currentFile: '',
        status: ImportStatus.done,
      );
      return;
    }

    final parsed = <ImportedNote>[];
    final errors = <ImportError>[];
    var skippedCount = 0;

    for (var i = 0; i < mdFiles.length; i++) {
      final file = mdFiles[i];
      final fileName = file.path.split('/').last;

      yield ImportProgress(
        current: i,
        total: total,
        currentFile: fileName,
        status: ImportStatus.parsing,
      );

      final result = await _parseFile(file);
      if (result != null) {
        parsed.add(result);
      } else {
        skippedCount++;
      }
    }

    yield ImportProgress(
      current: total,
      total: total,
      currentFile: '',
      status: ImportStatus.done,
    );

    // Stash results for the import stage.
    _lastParsedBatch = _ParsedBatch(
      notes: parsed,
      skippedCount: skippedCount,
      errors: errors,
    );
  }

  /// Encrypt and persist a batch of [ImportedNote]s into the database.
  ///
  /// For each note:
  ///   - A UUID is generated as the note ID.
  ///   - The content (and title) are encrypted via
  ///     [CryptoService.encryptForItem].
  ///   - The note row is created via [NotesDao.createNote].
  ///   - Tags are looked up or created and associated via
  ///     [NotesDao.addTagToNote].
  ///   - Properties from frontmatter are persisted via
  ///     [NotePropertiesDao].
  Stream<ImportProgress> importNotes(List<ImportedNote> notes) async* {
    final total = notes.length;
    final notesDao = _db.notesDao;

    if (total == 0) {
      yield const ImportProgress(
        current: 0,
        total: 0,
        currentFile: '',
        status: ImportStatus.done,
      );
      return;
    }

    // Pre-load existing tags so we avoid redundant lookups inside the loop.
    final existingTags = await _loadTagMap();

    // For Obsidian imports, build a title-to-id map so we can resolve
    // [[wiki links]] to note IDs after all notes are inserted.
    final titleToId = <String, String>{};

    for (var i = 0; i < notes.length; i++) {
      final imported = notes[i];
      final fileName = imported.sourcePath.split('/').last;

      yield ImportProgress(
        current: i,
        total: total,
        currentFile: fileName,
        status: ImportStatus.importing,
      );

      try {
        final noteId = _uuid.v4();

        // Resolve body content: for Obsidian imports, convert wiki links
        // and copy referenced images.
        var body = imported.body;
        if (_options.isObsidianImport) {
          body = _convertObsidianWikiLinks(body);
          await _copyObsidianImages(imported.sourcePath, body, noteId);
        }

        // Encrypt title and body.
        final encryptedContent = await _crypto.encryptForItem(
          noteId,
          body,
        );
        final encryptedTitle = await _crypto.encryptForItem(
          noteId,
          imported.title,
        );

        // Persist the note row.
        await notesDao.createNote(
          id: noteId,
          encryptedContent: encryptedContent,
          encryptedTitle: encryptedTitle,
          plainContent: body,
          plainTitle: imported.title,
        );

        // Track title for wiki link resolution.
        titleToId[imported.title.toLowerCase()] = noteId;

        // Create / resolve tags and associate them with the note.
        if (_options.importTags) {
          for (final tagName in imported.tags) {
            final tagId = await _resolveTag(
              tagName: tagName,
              existingTags: existingTags,
            );
            await notesDao.addTagToNote(noteId, tagId);
          }
        }

        // Create properties from frontmatter.
        if (_options.importProperties) {
          await _importProperties(
            noteId: noteId,
            frontmatter: imported.frontmatter,
            isPinned: imported.isPinned,
          );
        }

        _importedCount++;
      } catch (e) {
        _errors.add(
          ImportError(
            filePath: imported.sourcePath,
            message: e.toString(),
          ),
        );
      }
    }

    // Second pass for Obsidian imports: create note links.
    if (_options.isObsidianImport && titleToId.isNotEmpty) {
      await _createNoteLinks(notes, titleToId);
    }

    yield ImportProgress(
      current: total,
      total: total,
      currentFile: '',
      status: ImportStatus.done,
    );
  }

  /// Import notes from a ZIP archive containing `.md` files.
  ///
  /// Each `.md` file inside the archive is parsed and imported. The ZIP
  /// may be an AnyNote export or a generic collection of markdown files.
  Future<ImportResult> importFromZip(Uint8List zipBytes) async {
    if (kIsWeb) {
      return const ImportResult(importedCount: 0, skippedCount: 0);
    }

    // Reset per-batch counters.
    _importedCount = 0;
    _skippedCount = 0;
    _errors.clear();
    _lastParsedBatch = null;

    final archive = ZipDecoder().decodeBytes(zipBytes);
    final parsedNotes = <ImportedNote>[];

    for (final file in archive) {
      final name = file.name;
      if (!name.endsWith('.md') && !name.endsWith('.markdown')) continue;
      if (file.isFile) {
        final content = String.fromCharCodes(file.content as List<int>);
        if (content.trim().isEmpty) {
          _skippedCount++;
          continue;
        }
        final note = _parseContent(
          raw: content,
          sourcePath: name,
        );
        if (note != null) {
          parsedNotes.add(note);
        } else {
          _skippedCount++;
        }
      }
    }

    if (parsedNotes.isEmpty) {
      return ImportResult(
        importedCount: 0,
        skippedCount: _skippedCount,
        errors: _errors,
      );
    }

    // Stage 2: encrypt and persist.
    await importNotes(parsedNotes).drain<void>();

    return ImportResult(
      importedCount: _importedCount,
      skippedCount: _skippedCount,
      errors: _errors,
    );
  }

  /// Convenience method that chains [parseDirectory] + [importNotes] and
  /// returns a final [ImportResult].
  ///
  /// The returned future resolves when all notes have been processed (or
  /// skipped). Progress events from both stages are not exposed here; use the
  /// two individual methods if you need streaming progress.
  Future<ImportResult> importFromDirectory(Directory dir) async {
    if (kIsWeb) {
      return const ImportResult(importedCount: 0, skippedCount: 0);
    }

    // Reset per-batch counters.
    _importedCount = 0;
    _skippedCount = 0;
    _errors.clear();
    _lastParsedBatch = null;

    // Stage 1: parse all files.
    await parseDirectory(dir).drain<void>();

    final batch = _lastParsedBatch;
    if (batch == null || batch.notes.isEmpty) {
      return ImportResult(
        importedCount: 0,
        skippedCount: _skippedCount,
        errors: _errors,
      );
    }

    _skippedCount = batch.skippedCount;
    _errors.addAll(batch.errors);

    // Stage 2: encrypt and persist.
    await importNotes(batch.notes).drain<void>();

    return ImportResult(
      importedCount: _importedCount,
      skippedCount: _skippedCount,
      errors: _errors,
    );
  }

  // ---------------------------------------------------------------------------
  // Internal state
  // ---------------------------------------------------------------------------

  int _importedCount = 0;
  int _skippedCount = 0;
  final List<ImportError> _errors = [];
  _ParsedBatch? _lastParsedBatch;

  // ---------------------------------------------------------------------------
  // File discovery
  // ---------------------------------------------------------------------------

  /// Recursively collect all `.md` files under [dir].
  Future<List<File>> _collectMarkdownFiles(Directory dir) async {
    if (kIsWeb) return [];
    final results = <File>[];
    if (!await dir.exists()) return results;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.md')) {
        results.add(entity);
      }
    }
    return results;
  }

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  /// Parse a single Markdown file into an [ImportedNote].
  ///
  /// Returns `null` if the file is empty or cannot be decoded as UTF-8.
  Future<ImportedNote?> _parseFile(File file) async {
    String raw;
    try {
      raw = await file.readAsString(encoding: utf8);
    } catch (e) {
      _errors.add(
        ImportError(
          filePath: file.path,
          message: 'Failed to decode as UTF-8: $e',
        ),
      );
      _skippedCount++;
      return null;
    }

    if (raw.trim().isEmpty) {
      _skippedCount++;
      return null;
    }

    return _parseContent(raw: raw, sourcePath: file.path, file: file);
  }

  /// Parse markdown content into an [ImportedNote].
  ///
  /// [file] is optional -- used to read last-modified time. If null, the
  /// current time is used.
  ImportedNote? _parseContent({
    required String raw,
    required String sourcePath,
    File? file,
  }) {
    if (raw.trim().isEmpty) return null;

    // Use the shared frontmatter parser from markdown_export_service.dart.
    final (:frontmatter, :body) = parseYamlFrontmatter(raw);

    // Title: frontmatter > filename (without .md).
    String title;
    if (frontmatter['title'] is String) {
      title = frontmatter['title'] as String;
    } else if (file != null) {
      title = _filenameWithoutExt(file);
    } else {
      // Extract from sourcePath for ZIP entries.
      final name = sourcePath.split('/').last;
      title = name.endsWith('.md')
          ? name.substring(0, name.length - 3)
          : (name.endsWith('.markdown')
              ? name.substring(0, name.length - 9)
              : name);
    }

    // Date: frontmatter > file lastModified > now.
    DateTime createdAt = DateTime.now();
    final dateValue =
        frontmatter['date'] ?? frontmatter['created'] ?? frontmatter['updated'];
    if (_options.preserveDates && dateValue is String) {
      createdAt = DateTime.tryParse(dateValue) ?? createdAt;
    }
    if (file != null && !_options.preserveDates) {
      createdAt = _fileModifiedSync(file);
    }

    // Tags.
    List<String> tags = const [];
    if (_options.importTags) {
      tags = _parseTagsField(frontmatter['tags']);
    }

    // Pinned status.
    final isPinned =
        frontmatter['pinned'] == 'true' || frontmatter['pinned'] == true;

    return ImportedNote(
      title: title,
      body: body,
      tags: tags,
      createdAt: createdAt,
      sourcePath: sourcePath,
      frontmatter: Map<String, dynamic>.from(frontmatter),
      isPinned: isPinned,
    );
  }

  /// Parse the tags field which may be either a comma-separated string or a
  /// YAML flow sequence (`[tag1, tag2]`).
  List<String> _parseTagsField(dynamic value) {
    if (value == null) return [];
    if (value is! String) return [];

    var raw = value.trim();
    if (raw.isEmpty) return [];

    // YAML flow sequence: [tag1, tag2, tag3]
    if (raw.startsWith('[') && raw.endsWith(']')) {
      raw = raw.substring(1, raw.length - 1);
    }

    return raw
        .split(',')
        .map((t) => _stripQuotes(t.trim()))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Tag resolution
  // ---------------------------------------------------------------------------

  /// Load all existing tags as a map of plainName -> tagId.
  Future<Map<String, String>> _loadTagMap() async {
    final all = await _db.tagsDao.getAllTags();
    return {
      for (final tag in all)
        if (tag.plainName != null) tag.plainName!: tag.id,
    };
  }

  /// Return the ID for [tagName], creating the tag if it does not exist.
  ///
  /// [existingTags] is mutated in-place when a new tag is created so that
  /// subsequent calls for the same tag name hit the cache.
  Future<String> _resolveTag({
    required String tagName,
    required Map<String, String> existingTags,
  }) async {
    final existing = existingTags[tagName];
    if (existing != null) return existing;

    final tagId = _uuid.v4();
    final encryptedName = await _crypto.encryptForItem(tagId, tagName);

    await _db.tagsDao.createTag(
      id: tagId,
      encryptedName: encryptedName,
      plainName: tagName,
    );

    existingTags[tagName] = tagId;
    return tagId;
  }

  // ---------------------------------------------------------------------------
  // Property import
  // ---------------------------------------------------------------------------

  /// Import recognized properties from frontmatter into the database.
  Future<void> _importProperties({
    required String noteId,
    required Map<String, dynamic> frontmatter,
    required bool isPinned,
  }) async {
    final propsDao = _db.notePropertiesDao;

    for (final entry in _propertyKeys.entries) {
      final key = entry.key;
      final type = entry.value;
      final value = frontmatter[key];
      if (value == null) continue;
      final strValue = value is String ? _stripQuotes(value) : value.toString();
      if (strValue.isEmpty) continue;

      final propId = _uuid.v4();
      if (type == 'date') {
        final parsed = DateTime.tryParse(strValue);
        if (parsed != null) {
          await propsDao.createDateProperty(
            id: propId,
            noteId: noteId,
            key: key,
            value: parsed,
          );
        }
      } else {
        await propsDao.createTextProperty(
          id: propId,
          noteId: noteId,
          key: key,
          value: strValue,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Obsidian-specific handling
  // ---------------------------------------------------------------------------

  /// Convert Obsidian `[[Wiki Links]]` in [content] to the app's internal
  /// `[[title]]` format.
  ///
  /// Obsidian links may include alias syntax: `[[target|display text]]`.
  /// The alias is stripped, keeping only the target name.
  /// The `![[image.png]]` embed syntax is preserved as-is for image handling.
  String _convertObsidianWikiLinks(String content) {
    // Match [[link target]] and [[link target|display text]]
    // but NOT ![[(image embeds)]] -- those are handled separately.
    final wikiLinkRegex = RegExp(r'(?<!!)\[\[([^\]]+)\]\]');
    return content.replaceAllMapped(wikiLinkRegex, (match) {
      var target = match.group(1)!.trim();
      // Strip alias: [[target|display]] -> target
      final pipeIndex = target.indexOf('|');
      if (pipeIndex >= 0) {
        target = target.substring(0, pipeIndex).trim();
      }
      // Strip .md extension if present: [[Note.md]] -> [[Note]]
      if (target.toLowerCase().endsWith('.md')) {
        target = target.substring(0, target.length - 3);
      }
      if (target.toLowerCase().endsWith('.markdown')) {
        target = target.substring(0, target.length - 9);
      }
      return '[[$target]]';
    });
  }

  /// Copy images referenced by `![[image.png]]` embeds from the Obsidian vault
  /// to the app's image storage.
  ///
  /// Images are located by searching for the filename within the vault
  /// directory tree. If the vault path is not set or the image is not found,
  /// the embed is left as-is in the content.
  Future<void> _copyObsidianImages(
    String sourcePath,
    String content,
    String noteId,
  ) async {
    final vaultPath = _options.obsidianVaultPath;
    if (vaultPath == null || vaultPath.isEmpty) return;

    // Find all ![[(image)]] embeds.
    final imageEmbedRegex = RegExp(r'!\[\[([^\]]+)\]\]');
    final matches = imageEmbedRegex.allMatches(content);

    for (final match in matches) {
      final fileName = match.group(1)!.trim();
      final ext = p.extension(fileName).toLowerCase();
      if (!_imageExtensions.contains(ext)) continue;

      // Search for the image file in the vault.
      final imageFile = await _findFileInVault(
        Directory(vaultPath),
        fileName,
      );
      if (imageFile == null) continue;

      try {
        final bytes = await imageFile.readAsBytes();
        await ImageStorage.saveImage(bytes, noteId);
      } catch (_) {
        // Image copy failure is non-fatal -- the embed remains in the text.
      }
    }
  }

  /// Search for a file by name within the vault directory tree.
  Future<File?> _findFileInVault(Directory vault, String fileName) async {
    if (!await vault.exists()) return null;

    await for (final entity
        in vault.list(recursive: true, followLinks: false)) {
      if (entity is File && p.basename(entity.path) == fileName) {
        return entity;
      }
    }
    return null;
  }

  /// Create [NoteLink] entries for all [[wiki links]] found in imported notes.
  ///
  /// Uses [titleToId] to resolve link targets to their note IDs. Links to
  /// notes that were not imported are silently skipped.
  Future<void> _createNoteLinks(
    List<ImportedNote> notes,
    Map<String, String> titleToId,
  ) async {
    final linksDao = _db.noteLinksDao;
    final wikiLinkRegex = RegExp(r'\[\[([^\]]+)\]\]');

    for (final note in notes) {
      final sourceId = titleToId[note.title.toLowerCase()];
      if (sourceId == null) continue;

      final matches = wikiLinkRegex.allMatches(note.body);
      for (final match in matches) {
        var target = match.group(1)!.trim();
        // Strip alias.
        final pipeIndex = target.indexOf('|');
        if (pipeIndex >= 0) {
          target = target.substring(0, pipeIndex).trim();
        }
        final targetId = titleToId[target.toLowerCase()];
        if (targetId == null || targetId == sourceId) continue;

        try {
          await linksDao.createLink(
            id: _uuid.v4(),
            sourceId: sourceId,
            targetId: targetId,
            linkType: 'wiki',
          );
        } catch (_) {
          // Link creation failure is non-fatal.
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Utility helpers
  // ---------------------------------------------------------------------------

  /// Strip balanced surrounding quotes (single or double) from [value].
  String _stripQuotes(String value) {
    if (value.length >= 2) {
      final first = value[0];
      final last = value[value.length - 1];
      if ((first == '"' || first == "'") && first == last) {
        return value.substring(1, value.length - 1);
      }
    }
    return value;
  }

  /// Extract the filename without the `.md` extension for use as a fallback
  /// title.
  String _filenameWithoutExt(File file) {
    final name = file.path.split('/').last;
    return name.endsWith('.md') ? name.substring(0, name.length - 3) : name;
  }

  /// Return the file's last-modified timestamp synchronously (used when
  /// preserve-dates is off and we want the file mtime).
  DateTime _fileModifiedSync(File file) {
    try {
      return file.lastModifiedSync();
    } catch (_) {
      return DateTime.now();
    }
  }
}

/// Internal container for the results of the parse stage, passed between
/// [parseDirectory] and [importNotes] when called via [importFromDirectory].
class _ParsedBatch {
  final List<ImportedNote> notes;
  final int skippedCount;
  final List<ImportError> errors;

  _ParsedBatch({
    required this.notes,
    required this.skippedCount,
    required this.errors,
  });
}
