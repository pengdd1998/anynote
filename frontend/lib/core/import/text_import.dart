import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'import_models.dart';

/// Importer for plain text (.txt / .text) files as notes.
///
/// Supports importing individual files or entire directories. For each file,
/// the first non-empty line (up to 100 characters) is used as the title. If
/// the line starts with `# ` (markdown heading prefix), the prefix is stripped.
/// Files that are empty or cannot be decoded as UTF-8 are skipped.
class TextImporter {
  /// Maximum length for a line to be considered a title.
  static const int _maxTitleLength = 100;

  /// Parse a single plain text file into an [ImportedNote].
  ///
  /// Title extraction logic:
  /// - The first non-empty line (up to 100 characters) becomes the title.
  /// - A leading `# ` prefix is stripped from the title line.
  /// - If the file is empty, returns `null`.
  /// - The body is all content after the title line.
  ///
  /// Returns `null` if the file cannot be read, is empty, or cannot be decoded
  /// as UTF-8.
  Future<ImportedNote?> parseTextFile(File file) async {
    if (kIsWeb) return null;
    try {
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      String content;
      try {
        content = utf8.decode(bytes);
      } catch (_) {
        // File is not valid UTF-8.
        return null;
      }

      if (content.trim().isEmpty) return null;

      final modified = await file.lastModified();
      final lines = content.split('\n');

      // Find the first non-empty line.
      String? firstLine;
      var firstLineIndex = -1;
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trim().isNotEmpty) {
          firstLine = lines[i].trim();
          firstLineIndex = i;
          break;
        }
      }

      if (firstLine == null) return null;

      String title;
      String body;

      if (firstLine.length <= _maxTitleLength) {
        // Strip leading "# " prefix if present (markdown heading).
        title = firstLine.replaceFirst(RegExp(r'^#+\s*'), '').trim();
        // Body is everything after the first non-empty line.
        body = lines.sublist(firstLineIndex + 1).join('\n').trim();
      } else {
        title = _filenameToTitle(file.path);
        body = content.trim();
      }

      if (title.isEmpty && body.isEmpty) return null;

      return ImportedNote(
        title: title.isNotEmpty ? title : _filenameToTitle(file.path),
        body: body,
        tags: const [],
        createdAt: modified,
        sourcePath: file.path,
      );
    } catch (_) {
      return null;
    }
  }

  /// Parse all `.txt` and `.text` files in [dir] recursively.
  ///
  /// Files that cannot be decoded as UTF-8 are silently skipped.
  Future<List<ImportedNote>> parseTextDirectory(Directory dir) async {
    if (kIsWeb) return [];
    final notes = <ImportedNote>[];

    try {
      if (!await dir.exists()) return notes;

      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final lower = entity.path.toLowerCase();
          if (lower.endsWith('.txt') || lower.endsWith('.text')) {
            try {
              final note = await parseTextFile(entity);
              if (note != null) {
                notes.add(note);
              }
            } catch (_) {
              // Skip files that fail to parse or decode.
            }
          }
        }
      }
    } catch (_) {
      // Return whatever was collected before the error.
    }

    return notes;
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Derive a title from a file path by removing the extension.
  static String _filenameToTitle(String filePath) {
    final name = filePath.split('/').last;
    final dotIndex = name.lastIndexOf('.');
    return dotIndex > 0 ? name.substring(0, dotIndex) : name;
  }
}
