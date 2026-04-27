// Table of Contents extraction from markdown content.
//
// Parses ATX-style (`# Heading`) and Setext-style headings from raw markdown
// and produces a flat list of [TocEntry] items with sequential IDs suitable
// for anchor linking.

/// A single heading entry extracted from markdown content.
class TocEntry {
  /// Heading level (1-6). ATX headings derive level from the number of `#`
  /// prefixes. Setext-style headings are always level 1 (`===`) or 2 (`---`).
  final int level;

  /// The visible heading text with leading `#` symbols and whitespace stripped.
  final String text;

  /// A sequential identifier (e.g. "toc-0", "toc-1") used as an anchor target
  /// for scroll-to-heading navigation.
  final String id;

  /// The zero-based line index in the original markdown where this heading
  /// begins. Used to estimate scroll positions.
  final int lineIndex;

  const TocEntry({
    required this.level,
    required this.text,
    required this.id,
    required this.lineIndex,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TocEntry &&
          runtimeType == other.runtimeType &&
          level == other.level &&
          text == other.text &&
          id == other.id &&
          lineIndex == other.lineIndex;

  @override
  int get hashCode => Object.hash(level, text, id, lineIndex);
}

/// Pre-compiled regex for ATX-style headings: 1-6 `#` characters followed by
/// at least one space, then the heading text.
final _atxRegex = RegExp(r'^ {0,3}(#{1,6})\s+(.+?)(?:\s+#+\s*)?$');

/// Extracts a list of [TocEntry] items from the given [markdownContent].
///
/// Handles both ATX-style (`# Heading`) and Setext-style headings:
/// - Setext level 1: underline of `=` characters
/// - Setext level 2: underline of `-` characters
///
/// Headings inside fenced code blocks (``` ... ```) and indented code blocks
/// are ignored.
List<TocEntry> extractToc(String markdownContent) {
  final lines = markdownContent.split('\n');
  final entries = <TocEntry>[];
  var counter = 0;

  // Track whether we are inside a fenced code block.
  var inFencedCode = false;
  String? fenceMarker;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];

    // Detect fenced code block boundaries.
    final trimmedLine = line.trimLeft();
    if (!inFencedCode) {
      if (trimmedLine.startsWith('```') || trimmedLine.startsWith('~~~')) {
        // Count fence characters to match closing fence.
        final fenceRun = trimmedLine.substring(0, 3);
        fenceMarker = fenceRun;
        inFencedCode = true;
        continue;
      }
      // Skip indented code blocks (4+ spaces or tab).
      if (line.startsWith('    ') || line.startsWith('\t')) {
        continue;
      }
    } else {
      // Inside a fenced code block: check for closing fence.
      if (trimmedLine.startsWith(fenceMarker ?? '```')) {
        inFencedCode = false;
        fenceMarker = null;
      }
      continue;
    }

    // Try ATX-style heading match.
    final atxMatch = _atxRegex.firstMatch(line);
    if (atxMatch != null) {
      final level = atxMatch.group(1)!.length;
      final text = atxMatch.group(2)!.trim();
      if (text.isNotEmpty) {
        entries.add(
          TocEntry(
            level: level,
            text: text,
            id: 'toc-$counter',
            lineIndex: i,
          ),
        );
        counter++;
      }
      continue;
    }

    // Try Setext-style heading: current line is text, next line is underline.
    if (i + 1 < lines.length) {
      final nextTrimmed = lines[i + 1].trim();
      // Setext underline must be at least one character and consist entirely
      // of `=` or `-` characters (with optional trailing whitespace already
      // trimmed). The text line must not be empty.
      if (line.trim().isNotEmpty && nextTrimmed.isNotEmpty) {
        final isSetext1 = RegExp(r'^=+\s*$').hasMatch(nextTrimmed);
        final isSetext2 = RegExp(r'^-+\s*$').hasMatch(nextTrimmed);

        if (isSetext1 || isSetext2) {
          entries.add(
            TocEntry(
              level: isSetext1 ? 1 : 2,
              text: line.trim(),
              id: 'toc-$counter',
              lineIndex: i,
            ),
          );
          counter++;
          // Skip the underline line on next iteration.
          i++;
        }
      }
    }
  }

  return entries;
}
