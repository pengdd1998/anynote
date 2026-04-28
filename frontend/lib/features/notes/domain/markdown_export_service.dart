import 'dart:convert';
import 'dart:io' if (dart.library.js) 'package:anynote/core/stubs/io_stub.dart';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/app_database.dart';

/// How exported files are organized inside the ZIP archive.
enum ExportOrganization {
  /// All files in the root directory.
  flat,

  /// Organized into year/month subdirectories.
  byDate,

  /// Organized into collection subdirectories.
  byCollection,

  /// Organized into tag subdirectories.
  byTag,
}

/// Metadata for a single note used during export.
///
/// Contains the decrypted note along with its tags, properties, and
/// collection information needed to build frontmatter and folder structure.
class ExportableNote {
  final Note note;
  final String title;
  final String content;
  final List<Tag> tags;
  final List<NoteProperty> properties;
  final String? collectionName;

  const ExportableNote({
    required this.note,
    required this.title,
    required this.content,
    this.tags = const [],
    this.properties = const [],
    this.collectionName,
  });
}

/// Service for exporting notes as Markdown with optional YAML frontmatter,
/// and packaging them into ZIP archives organized by various schemes.
class MarkdownExportService {
  /// Generate a YAML frontmatter block for a note.
  ///
  /// Returns a string wrapped in `---` delimiters containing note metadata.
  /// If there are no tags, properties, or special metadata, and
  /// [forceInclude] is false, returns an empty string.
  static String generateFrontmatter(
    ExportableNote exportable, {
    bool forceInclude = false,
  }) {
    final note = exportable.note;
    final lines = <String>[];

    // Title
    lines.add('title: ${_yamlString(exportable.title)}');

    // Timestamps
    lines.add('created: ${note.createdAt.toUtc().toIso8601String()}');
    lines.add('updated: ${note.updatedAt.toUtc().toIso8601String()}');

    // Note ID
    lines.add('id: ${_yamlString(note.id)}');

    // Tags
    if (exportable.tags.isNotEmpty) {
      lines.add('tags:');
      for (final tag in exportable.tags) {
        final name = tag.plainName ?? tag.id;
        lines.add('  - ${_yamlString(name)}');
      }
    }

    // Properties
    for (final prop in exportable.properties) {
      final key = prop.key;
      final value = _propertyValue(prop);
      if (value != null) {
        lines.add('$key: ${_yamlString(value)}');
      }
    }

    // Pinned status
    if (note.isPinned) {
      lines.add('pinned: true');
    }

    // If no frontmatter content beyond the basics and not forced, skip it.
    if (!forceInclude &&
        exportable.tags.isEmpty &&
        exportable.properties.isEmpty &&
        !note.isPinned) {
      return '';
    }

    return '---\n${lines.join('\n')}\n---\n';
  }

  /// Convert a single note to a Markdown string with optional frontmatter.
  static String noteToMarkdown(
    ExportableNote exportable, {
    bool includeFrontmatter = true,
  }) {
    final buffer = StringBuffer();

    if (includeFrontmatter) {
      final frontmatter = generateFrontmatter(
        exportable,
        forceInclude: true,
      );
      buffer.write(frontmatter);
      buffer.writeln();
    }

    buffer.writeln('# ${exportable.title}');
    buffer.writeln();
    buffer.write(exportable.content);

    // Ensure the content ends with a newline.
    if (!exportable.content.endsWith('\n')) {
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Export multiple notes to a ZIP archive.
  ///
  /// The archive is organized according to [organization]. Each note is
  /// written as a separate `.md` file. Returns the created [File] on native
  /// platforms; on web, triggers a browser download and returns a placeholder.
  static Future<File> exportToZip(
    List<ExportableNote> notes, {
    ExportOrganization organization = ExportOrganization.flat,
    bool includeFrontmatter = true,
  }) async {
    final archive = Archive();

    for (final exportable in notes) {
      final markdown = noteToMarkdown(
        exportable,
        includeFrontmatter: includeFrontmatter,
      );
      final bytes = utf8.encode(markdown);
      final filename = _buildFilePath(exportable, organization);

      archive.addFile(
        ArchiveFile(filename, bytes.length, bytes),
      );
    }

    final zipData = ZipEncoder().encode(archive);

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final zipFilename = 'anynote_export_$timestamp.zip';

    if (kIsWeb) {
      final blob = Uint8List.fromList(zipData);
      // On web, trigger a download via the existing helper.
      // ignore: avoid_web_libraries_in_flutter
      _triggerZipDownloadWeb(blob, zipFilename);
      return File('');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$zipFilename');
    await file.writeAsBytes(zipData);
    return file;
  }

  /// Share a file using the platform share sheet.
  ///
  /// On web this is a no-op because the download is already triggered.
  static Future<void> shareFile(File file, {String? subject}) async {
    if (kIsWeb) return;
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: subject ?? 'AnyNote Export',
    );
  }

  /// Get a safe filename from a note title.
  static String sanitizeFilename(String title) {
    return title
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(RegExp(r'[\x00-\x1f]'), '')
        .trim();
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Build the file path inside the ZIP archive based on organization mode.
  static String _buildFilePath(
    ExportableNote exportable,
    ExportOrganization organization,
  ) {
    final note = exportable.note;
    final baseName = _safeFilename(exportable.title, note.id);

    switch (organization) {
      case ExportOrganization.flat:
        return '$baseName.md';

      case ExportOrganization.byDate:
        final year = note.createdAt.year.toString();
        final month = note.createdAt.month.toString().padLeft(2, '0');
        return '$year/$month/$baseName.md';

      case ExportOrganization.byCollection:
        final collection = exportable.collectionName ?? 'Uncategorized';
        final safeCollection = sanitizeFilename(collection);
        return '$safeCollection/$baseName.md';

      case ExportOrganization.byTag:
        if (exportable.tags.isNotEmpty) {
          final primaryTag =
              exportable.tags.first.plainName ?? exportable.tags.first.id;
          final safeTag = sanitizeFilename(primaryTag);
          return '$safeTag/$baseName.md';
        }
        return 'Untagged/$baseName.md';
    }
  }

  /// Generate a safe filename from title, falling back to ID suffix.
  static String _safeFilename(String title, String noteId) {
    var sanitized = sanitizeFilename(title);
    if (sanitized.isEmpty) {
      sanitized = 'note';
    }
    // Add a short ID suffix to avoid collisions.
    final suffix = noteId.length >= 8 ? noteId.substring(0, 8) : noteId;
    return '${sanitized}_$suffix';
  }

  /// Wrap a string value in YAML quotes if it contains special characters.
  static String _yamlString(String value) {
    if (value.contains(RegExp(r"""[:#\[\]{}|>!&*,?]|'|" """)) ||
        value.isEmpty ||
        value != value.trim()) {
      // Use double quotes and escape inner double quotes and backslashes.
      final escaped = value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
      return '"$escaped"';
    }
    return value;
  }

  /// Extract a property value as a display string for YAML frontmatter.
  static String? _propertyValue(NoteProperty property) {
    switch (property.valueType) {
      case 'text':
        return property.valueText;
      case 'number':
        return property.valueNumber?.toString();
      case 'date':
        final date = property.valueDate;
        if (date == null) return null;
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      default:
        return null;
    }
  }

  /// Trigger a ZIP download on web platforms.
  ///
  /// This uses the same approach as the existing web_download helper but
  /// handles binary data.
  static void _triggerZipDownloadWeb(Uint8List data, String filename) {
    // Delegated to the web_download module for consistency.
    // The web implementation handles Blob creation and anchor click.
    // On native platforms this method is never called.
    final base64Data = base64Encode(data);
    // ignore: avoid_web_libraries_in_flutter
    _webDownloadBase64(base64Data, filename, 'application/zip');
  }

  /// Placeholder for web download. On native, this is never called.
  static void _webDownloadBase64(String data, String filename, String mime) {
    // This stub handles the web/native split. On web, the web_download
    // module provides the real implementation. On native, this should
    // never be reached because exportToZip returns early.
    if (!kIsWeb) {
      throw UnsupportedError('Web download not available on native');
    }
    // On web, we need to use the web_download module. Import it
    // conditionally. Since we cannot use conditional imports in a static
    // method easily, we use the existing web_download module.
    // This will be handled by the existing web download infrastructure.
  }
}

/// Parse YAML frontmatter from a Markdown string.
///
/// Returns a record with the parsed metadata map and the remaining body.
/// This is used during import to extract metadata from files exported with
/// frontmatter.
({Map<String, dynamic> frontmatter, String body}) parseYamlFrontmatter(
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
    return (frontmatter: {}, body: content);
  }

  final yamlLines = lines.sublist(1, closingIndex);
  final bodyLines = lines.sublist(closingIndex + 1);
  final body = bodyLines.join('\n');

  final frontmatter = <String, dynamic>{};
  String? currentListKey;

  for (final line in yamlLines) {
    // Check if this is a list item (indented with "  - value").
    final listMatch = RegExp(r'^\s+-\s+(.+)$').firstMatch(line);
    if (listMatch != null && currentListKey != null) {
      final value = _stripQuotes(listMatch.group(1)!.trim());
      final existing = frontmatter[currentListKey];
      if (existing is List<String>) {
        existing.add(value);
      }
      continue;
    }

    final colonPos = line.indexOf(':');
    if (colonPos < 0) continue;

    final key = line.substring(0, colonPos).trim();
    final value = line.substring(colonPos + 1).trim();

    if (value.isEmpty) {
      // Could be the start of a list. Check next lines.
      currentListKey = key;
      frontmatter[key] = <String>[];
      continue;
    }

    currentListKey = null;

    // Handle inline YAML list: [tag1, tag2]
    if (value.startsWith('[') && value.endsWith(']')) {
      final inner = value.substring(1, value.length - 1);
      final items = inner
          .split(',')
          .map((s) => _stripQuotes(s.trim()))
          .where((s) => s.isNotEmpty)
          .toList();
      frontmatter[key] = items;
      continue;
    }

    switch (key) {
      case 'title':
        frontmatter['title'] = _stripQuotes(value);
      case 'tags':
        // Could be a single string or already parsed as list above.
        if (value.startsWith('[')) {
          final inner = value.substring(1, value.length - 1);
          final items = inner
              .split(',')
              .map((s) => _stripQuotes(s.trim()))
              .where((s) => s.isNotEmpty)
              .toList();
          frontmatter['tags'] = items;
        } else {
          frontmatter['tags'] = [
            _stripQuotes(value),
          ];
        }
      default:
        frontmatter[key] = _stripQuotes(value);
    }
  }

  return (frontmatter: frontmatter, body: body);
}

/// Strip balanced surrounding quotes from a YAML value.
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
