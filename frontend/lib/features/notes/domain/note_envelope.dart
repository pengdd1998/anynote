import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart' as quill;

/// The sync engine packs a note for push as a JSON envelope
/// `{"content": "...", "title": "..."}` (see SyncEngine._encryptNoteForPush).
///
/// That envelope should only exist on the wire — but a bug previously stored
/// the raw envelope (and, after an editor round-trip, the envelope embedded
/// inside a Quill Delta's text) as the note's content. These helpers detect
/// and unwrap it so the actual body is rendered.

/// If [content] is (or contains) a sync envelope `{"content":…}`, return its
/// inner `"content"` body; otherwise return [content] unchanged.
///
/// Locates the envelope anywhere in the string (so it catches a title that was
/// prepended) and extracts a *balanced* JSON object (so it works even when the
/// envelope is trapped inside a Quill Delta like
/// `[{"insert":"…{\"content\":…}…"}]`, where a naive `jsonDecode` of the
/// remainder would choke on the trailing Delta syntax).
String unwrapSyncEnvelope(String content) {
  // 1. Pure envelope, or envelope after a prepended title (real quotes).
  final direct = _tryExtractEnvelope(content);
  if (direct != null) return direct;
  // 2. Envelope baked into a Quill Delta: the raw Delta JSON escapes the
  //    envelope's quotes (\"), so a raw search misses it. Parse the Delta,
  //    join its insert-op text (escapes resolved) and search there.
  final deltaText = _deltaInsertText(content);
  if (deltaText != null) {
    final fromDelta = _tryExtractEnvelope(deltaText);
    if (fromDelta != null) return fromDelta;
  }
  return content;
}

/// Returns the envelope's inner "content" body if [s] contains a sync
/// envelope `{"content":…}` (with real quotes); otherwise null.
String? _tryExtractEnvelope(String s) {
  final idx = s.indexOf('{"content"');
  if (idx < 0) return null;
  final obj = _extractBalancedJsonObject(s, idx);
  if (obj == null) return null;
  try {
    final decoded = jsonDecode(obj);
    if (decoded is Map && decoded.containsKey('content')) {
      final inner = decoded['content'];
      if (inner is String) return inner;
    }
  } catch (_) {
    // Not a parseable envelope.
  }
  return null;
}

/// If [content] is a Quill Delta JSON array, return the concatenation of its
/// insert-op text (with JSON escapes resolved); otherwise null.
String? _deltaInsertText(String content) {
  try {
    final decoded = jsonDecode(content);
    if (decoded is! List) return null;
    final buf = StringBuffer();
    for (final op in decoded) {
      if (op is Map && op['insert'] is String) {
        buf.write(op['insert'] as String);
      }
    }
    return buf.toString();
  } catch (_) {
    return null;
  }
}

/// Whether [content] is (or contains) a sync envelope `{"content":…}`.
bool containsSyncEnvelope(String content) {
  if (_tryExtractEnvelope(content) != null) return true;
  final deltaText = _deltaInsertText(content);
  return deltaText != null && _tryExtractEnvelope(deltaText) != null;
}

/// Object replacement / noncharacter code points that appear inside stored
/// text (e.g. notes pasted from Apple Notes carry U+FFFC for embedded
/// objects). Flutter renders them as a dotted "[OBJ]" box, so they are
/// stripped from everything the user sees.
final RegExp _objectPlaceholderPattern = RegExp('[\uFFFC\uFFFE\uFFFF]');

/// Removes object-replacement placeholders (U+FFFC/U+FFFE/U+FFFF) from [s].
///
/// Display-time hygiene only — encrypted content is never rewritten.
String stripObjectPlaceholders(String s) {
  if (!s.contains('\uFFFC') && !s.contains('\uFFFE') && !s.contains('\uFFFF')) {
    return s;
  }
  return s.replaceAll(_objectPlaceholderPattern, '');
}

/// If [content] is a Quill Delta JSON array, return its plain text
/// (concatenated insert-op text); otherwise return [content] unchanged.
///
/// Defensive helper for list previews: notes corrupted by an older version
/// restore can carry Delta JSON in `plainContent`, which would otherwise be
/// rendered as raw JSON when the card title is derived from the first line.
String plainTextFromStoredContent(String content) {
  final trimmed = content.trim();
  if (!trimmed.startsWith('[')) return stripObjectPlaceholders(content);
  return stripObjectPlaceholders(_deltaInsertText(trimmed) ?? content);
}

/// Converts stored note content to the plain-text form the editor saves in
/// the `plainContent` column (see NoteEditorScreen._saveNote).
///
/// Version snapshots keep the editor's content format (Quill Delta JSON for
/// rich-editor notes) in their encrypted blob, while the editor stores the
/// plain-text extraction of that Delta in `plainContent`. Parsing the Delta
/// through the same Quill document pipeline keeps restored content
/// byte-equivalent to an editor save, so the home card derives its title and
/// preview correctly. Non-Delta content (plain notes) is returned unchanged.
String storedContentToPlainText(String content) {
  final trimmed = content.trim();
  if (!trimmed.startsWith('[')) return stripObjectPlaceholders(content);
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is List &&
        decoded.isNotEmpty &&
        decoded.first is Map &&
        (decoded.first as Map).containsKey('insert')) {
      return stripObjectPlaceholders(
        quill.Document.fromJson(decoded).toPlainText(),
      );
    }
  } catch (_) {
    // Not Delta JSON — fall through and return as-is.
  }
  return stripObjectPlaceholders(content);
}

/// Strips object-replacement placeholders from every string insert op of a
/// parsed Quill Delta (see [stripObjectPlaceholders]). Returns a new list;
/// embed ops (non-string inserts) are left untouched.
List<Map<String, dynamic>> sanitizeDeltaOps(List<dynamic> ops) {
  return ops.map((op) {
    if (op is Map && op['insert'] is String) {
      return {
        ...op.cast<String, dynamic>(),
        'insert': stripObjectPlaceholders(op['insert'] as String),
      };
    }
    return (op as Map).cast<String, dynamic>();
  }).toList(growable: false);
}

/// Extract the balanced JSON object (`{…}`) beginning at [start], respecting
/// string escapes and nested braces. Returns `null` if no matching `}` is
/// found.
String? _extractBalancedJsonObject(String s, int start) {
  if (start >= s.length || s[start] != '{') return null;
  var depth = 0;
  var inString = false;
  var escape = false;
  for (var i = start; i < s.length; i++) {
    final c = s[i];
    if (escape) {
      escape = false;
      continue;
    }
    if (c == r'\') {
      escape = true;
      continue;
    }
    if (c == '"') {
      inString = !inString;
      continue;
    }
    if (inString) continue;
    if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) return s.substring(start, i + 1);
    }
  }
  return null;
}
