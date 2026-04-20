import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';

import '../crypto/crypto_service.dart';
import '../database/app_database.dart';
import 'import_models.dart';

/// Service for importing Markdown files into the AnyNote database.
///
/// The import pipeline has two stages:
///   1. **Parsing** -- recursively scans a directory for `.md` files and
///      extracts frontmatter metadata (title, date, tags).
///   2. **Importing** -- encrypts each parsed note with [CryptoService] and
///      persists it via [NotesDao], creating tag associations as needed.
///
/// Both stages emit [ImportProgress] events so the UI can display a progress
/// indicator. The convenience method [importFromDirectory] chains both stages
/// and returns a final [ImportResult].
class MarkdownImportService {
  MarkdownImportService({
    required CryptoService cryptoService,
    required AppDatabase database,
  })  : _crypto = cryptoService,
        _db = database;

  final CryptoService _crypto;
  final AppDatabase _db;

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

    for (var i = 0; i < notes.length; i++) {
      final imported = notes[i];
      final fileName =
          imported.sourcePath.split('/').last;

      yield ImportProgress(
        current: i,
        total: total,
        currentFile: fileName,
        status: ImportStatus.importing,
      );

      try {
        final noteId = _uuid.v4();

        // Encrypt title and body.
        final encryptedContent = await _crypto.encryptForItem(
          noteId,
          imported.body,
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
          plainContent: imported.body,
          plainTitle: imported.title,
        );

        // Create / resolve tags and associate them with the note.
        for (final tagName in imported.tags) {
          final tagId = await _resolveTag(
            tagName: tagName,
            existingTags: existingTags,
          );
          await notesDao.addTagToNote(noteId, tagId);
        }

        _importedCount++;
      } catch (e) {
        _errors.add(ImportError(
          filePath: imported.sourcePath,
          message: e.toString(),
        ),);
      }
    }

    yield ImportProgress(
      current: total,
      total: total,
      currentFile: '',
      status: ImportStatus.done,
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

    await for (final entity
        in dir.list(recursive: true, followLinks: false)) {
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
      _errors.add(ImportError(
        filePath: file.path,
        message: 'Failed to decode as UTF-8: $e',
      ),);
      _skippedCount++;
      return null;
    }

    if (raw.trim().isEmpty) {
      _skippedCount++;
      return null;
    }

    final (:frontmatter, :body) = _parseFrontmatter(raw);

    // Title: frontmatter > filename (without .md).
    final title =
        (frontmatter['title'] as String?) ?? _filenameWithoutExt(file);

    // Date: frontmatter > file lastModified.
    DateTime createdAt;
    final dateValue = frontmatter['date'];
    if (dateValue is String) {
      createdAt = DateTime.tryParse(dateValue) ?? await _fileModified(file);
    } else {
      createdAt = await _fileModified(file);
    }

    // Tags.
    final tags = _parseTagsField(frontmatter['tags']);

    return ImportedNote(
      title: title,
      body: body,
      tags: tags,
      createdAt: createdAt,
      sourcePath: file.path,
    );
  }

  /// Extract YAML frontmatter delimited by `---` lines.
  ///
  /// Supports the common format:
  /// ```markdown
  /// ---
  /// title: My Note
  /// date: 2025-04-19
  /// tags: [tag1, tag2]
  /// ---
  /// Body content here.
  /// ```
  ///
  /// Returns a record with the parsed frontmatter map and the remaining body.
  ({Map<String, dynamic> frontmatter, String body}) _parseFrontmatter(
    String content,
  ) {
    final lines = content.split('\n');

    // Frontmatter must start on the very first line.
    if (lines.isEmpty || lines.first.trim() != '---') {
      return (frontmatter: {}, body: content);
    }

    // Find the closing ---.
    int closingIndex = -1;
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim() == '---') {
        closingIndex = i;
        break;
      }
    }

    if (closingIndex < 0) {
      // No closing delimiter -- treat entire content as body.
      return (frontmatter: {}, body: content);
    }

    final yamlLines = lines.sublist(1, closingIndex);
    final bodyLines = lines.sublist(closingIndex + 1);
    final body = bodyLines.join('\n');

    final frontmatter = <String, dynamic>{};
    for (final line in yamlLines) {
      final colonPos = line.indexOf(':');
      if (colonPos < 0) continue;

      final key = line.substring(0, colonPos).trim();
      final value = line.substring(colonPos + 1).trim();

      if (value.isEmpty) continue;

      switch (key) {
        case 'title':
          frontmatter['title'] = _stripQuotes(value);
        case 'date':
          frontmatter['date'] = value;
        case 'tags':
          frontmatter['tags'] = value;
        default:
          // Store as-is for forward compatibility.
          frontmatter[key] = value;
      }
    }

    return (frontmatter: frontmatter, body: body);
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

  /// Return the file's last-modified timestamp.
  Future<DateTime> _fileModified(File file) async {
    try {
      return await file.lastModified();
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
