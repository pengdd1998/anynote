import 'dart:convert';

import 'note_envelope.dart';

/// What the note page reads: a title, and the body under it.
typedef ReadingView = ({String title, String content});

/// The reading view of a note.
///
/// A note has no title of its own, as a rule: the title is the first line of
/// its body, the way the home cards take it, and that line is then not the
/// first line of the body as well. A stored title — left by an older client,
/// an import, a test script — stands in when the body has no line to be the
/// title, and it does not make the body's first line show a second time when
/// the two say the same thing.
ReadingView readingViewOf({
  required String content,
  required String storedTitle,
  required String untitled,
}) {
  final derived = deriveTitleFromBody(content);
  if (derived == null) return (title: storedTitle, content: content);

  final hasStoredTitle = storedTitle.isNotEmpty && storedTitle != untitled;
  if (hasStoredTitle && derived != storedTitle.trim()) {
    return (title: storedTitle, content: content);
  }
  return (title: derived, content: stripFirstLineFromBody(content));
}

/// First non-empty line of the note body, or null when the body is empty.
/// Mirrors NoteCard's title derivation.
String? deriveTitleFromBody(String content) {
  final plain = plainTextFromStoredContent(content);
  for (final line in plain.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

/// Removes everything up to and including the first line break so the
/// derived title line does not duplicate inside the body viewer. Delta
/// JSON loses its first text run's line; plain content loses line one.
String stripFirstLineFromBody(String content) {
  final trimmed = content.trim();
  if (trimmed.startsWith('[')) {
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        final ops = sanitizeDeltaOps(decoded);
        var seenFirstBreak = false;
        final remaining = <Map<String, dynamic>>[];
        for (final op in ops) {
          final insert = op['insert'];
          if (insert is! String) {
            // Embeds (images, tables, links) are body content, never part
            // of the derived title line — title derivation only reads
            // string inserts. Keep them wherever they appear.
            remaining.add(op);
            continue;
          }
          if (!seenFirstBreak) {
            final idx = insert.indexOf('\n');
            if (idx < 0) continue; // whole op is part of the title line
            seenFirstBreak = true;
            final rest = insert.substring(idx + 1);
            if (rest.isNotEmpty) {
              remaining.add({...op, 'insert': rest});
            }
            continue;
          }
          remaining.add(op);
        }
        if (seenFirstBreak) {
          // A Quill document must end with a line break. Stripping the
          // title line can leave an embed-only delta (no trailing "\n"),
          // which Document.fromJson rejects — append the break so the
          // viewer parses it as a Delta instead of raw JSON text.
          final lastInsert =
              remaining.isEmpty ? null : remaining.last['insert'];
          if (lastInsert is! String || !lastInsert.endsWith('\n')) {
            remaining.add(<String, dynamic>{'insert': '\n'});
          }
          return jsonEncode(remaining);
        }
        return content;
      }
    } catch (_) {
      // Not Delta JSON — fall through to plain handling.
    }
  }
  final idx = content.indexOf('\n');
  return idx < 0 ? '' : content.substring(idx + 1);
}
