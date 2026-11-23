/// A composed draft split into the parts a publish needs.
///
/// Compose keeps a draft as one piece of text — the user reads and edits it
/// like a note — and the AI writes it in a fixed layout, stated in the
/// prompts:
///
/// ```text
/// # Title            first line; the `#` is optional
///
/// Body…
///
/// #tag1 #tag2        last line; optional, hashtags only
/// ```
///
/// [parse] splits that layout back and guesses at nothing else. It is the
/// step between what the model writes and what `POST /api/v1/publish` takes,
/// so the model never has to produce JSON, and a user who deletes the title
/// line or types a tag by hand is still understood.
class PlatformDraft {
  const PlatformDraft({
    required this.title,
    required this.content,
    this.tags = const [],
  });

  /// Plain text, without markdown heading or emphasis markers.
  final String title;

  /// The body: everything between the title line and the hashtag line.
  final String content;

  /// Hashtags from the last line, without their `#`.
  final List<String> tags;

  static const empty = PlatformDraft(title: '', content: '');

  bool get isEmpty => title.isEmpty && content.isEmpty && tags.isEmpty;

  // A hashtag is `#` glued to a name; the name stops at whitespace, at the
  // next `#`, or at a separator someone might type between tags.
  static final _hashtag = RegExp(r'#([^\s#,，、;；]+)');
  static final _separators = RegExp(r'[\s,，、;；]+');
  static final _headingMarker = RegExp(r'^#+\s*');

  static PlatformDraft parse(String text) {
    final lines = text.split('\n');

    // The title is the first line that says anything.
    var start = 0;
    while (start < lines.length && lines[start].trim().isEmpty) {
      start++;
    }
    if (start == lines.length) return empty;
    final title = lines[start]
        .trim()
        .replaceFirst(_headingMarker, '')
        .replaceAll('**', '')
        .trim();

    // Tags: reading up from the end, take every line that is hashtags and
    // nothing else. The first line that is not ends the body.
    var end = lines.length;
    final tags = <String>[];
    while (end > start + 1) {
      final line = lines[end - 1].trim();
      if (line.isEmpty) {
        end--;
        continue;
      }
      final found = _hashtagsOnly(line);
      if (found == null) break;
      tags.insertAll(0, found);
      end--;
    }

    // Blank lines between the title and the body are not part of the body;
    // the body's own lines are kept exactly as written, indentation included.
    var bodyStart = start + 1;
    while (bodyStart < end && lines[bodyStart].trim().isEmpty) {
      bodyStart++;
    }

    return PlatformDraft(
      title: title,
      content: lines.sublist(bodyStart, end).join('\n'),
      tags: tags.toSet().toList(),
    );
  }

  /// The tag names if [line] is made of hashtags and separators alone,
  /// otherwise null — a sentence that happens to contain a hashtag stays
  /// part of the body.
  static List<String>? _hashtagsOnly(String line) {
    final names = _hashtag.allMatches(line).map((m) => m.group(1)!).toList();
    if (names.isEmpty) return null;
    final rest =
        line.replaceAll(_hashtag, '').replaceAll(_separators, '').trim();
    return rest.isEmpty ? names : null;
  }

  @override
  String toString() => 'PlatformDraft(title: $title, '
      'content: ${content.length} chars, tags: $tags)';
}
