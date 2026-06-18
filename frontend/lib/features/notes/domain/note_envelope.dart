import 'dart:convert';

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
  final idx = content.indexOf('{"content"');
  if (idx < 0) return content;
  final obj = _extractBalancedJsonObject(content, idx);
  if (obj == null) return content;
  try {
    final decoded = jsonDecode(obj);
    if (decoded is Map && decoded.containsKey('content')) {
      final inner = decoded['content'];
      if (inner is String) return inner;
    }
  } catch (_) {
    // Not a parseable envelope — leave as-is.
  }
  return content;
}

/// Whether [content] is (or contains) a sync envelope `{"content":…}`.
bool containsSyncEnvelope(String content) =>
    content.contains('{"content"') &&
    _extractBalancedJsonObject(content, content.indexOf('{"content"')) != null;

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
