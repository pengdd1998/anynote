/// Line-based text diffing using the Longest Common Subsequence (LCS) algorithm.
///
/// Computes a unified diff between two text strings, classifying each line as
/// added, removed, or unchanged. Designed for note version comparison where
/// texts are typically under 1000 lines, so O(n*m) DP is acceptable.
library;

/// Type of change for a single line in a diff.
enum DiffType {
  /// Line exists only in the new text (added).
  added,

  /// Line exists only in the old text (removed).
  removed,

  /// Line exists in both texts (unchanged).
  unchanged,
}

/// A single line in a diff result with its change type.
class DiffLine {
  /// The text content of this line (without newline).
  final String text;

  /// Whether this line was added, removed, or unchanged.
  final DiffType type;

  const DiffLine({
    required this.text,
    required this.type,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiffLine &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          type == other.type;

  @override
  int get hashCode => Object.hash(text, type);

  @override
  String toString() {
    const prefix = {
      DiffType.added: '+',
      DiffType.removed: '-',
      DiffType.unchanged: ' ',
    };
    return '${prefix[type]} $text';
  }
}

/// Result of comparing two texts with line-level diff information.
class TextDiff {
  /// Ordered list of diff lines from top to bottom.
  final List<DiffLine> lines;

  const TextDiff._(this.lines);

  /// Compute a line-by-line diff between [oldText] and [newText].
  ///
  /// Uses the LCS (Longest Common Subsequence) algorithm via dynamic programming.
  /// Time complexity is O(n * m) where n and m are the line counts of the two
  /// texts. This is acceptable for note content which is typically <1000 lines.
  ///
  /// Returns a [TextDiff] with lines classified as added, removed, or unchanged.
  static TextDiff compute(String oldText, String newText) {
    final oldLines = _splitLines(oldText);
    final newLines = _splitLines(newText);

    // Handle edge cases.
    if (oldLines.isEmpty && newLines.isEmpty) {
      return const TextDiff._([]);
    }
    if (oldLines.isEmpty) {
      return TextDiff._([
        for (final line in newLines) DiffLine(text: line, type: DiffType.added),
      ]);
    }
    if (newLines.isEmpty) {
      return TextDiff._([
        for (final line in oldLines)
          DiffLine(text: line, type: DiffType.removed),
      ]);
    }

    // Compute LCS table.
    final lcsTable = _computeLcsTable(oldLines, newLines);

    // Backtrack to produce the diff.
    final result = <DiffLine>[];
    _backtrack(
      lcsTable,
      oldLines,
      newLines,
      oldLines.length,
      newLines.length,
      result,
    );

    // Backtrack produces lines in reverse order, so reverse them.
    return TextDiff._(result.reversed.toList());
  }

  /// Number of lines that were added.
  int get linesAdded => lines.where((l) => l.type == DiffType.added).length;

  /// Number of lines that were removed.
  int get linesRemoved => lines.where((l) => l.type == DiffType.removed).length;

  /// Number of lines that are unchanged.
  int get linesUnchanged =>
      lines.where((l) => l.type == DiffType.unchanged).length;

  /// Whether the two texts are identical.
  bool get isIdentical => linesAdded == 0 && linesRemoved == 0;

  /// Split text into lines, preserving empty lines but not trailing newlines.
  static List<String> _splitLines(String text) {
    if (text.isEmpty) return [];
    // splitMapJoin approach: split on newlines, keeping empty strings for
    // blank lines but stripping the final empty element from a trailing newline.
    final lines = text.split('\n');
    // If the text ends with a newline, the split produces a trailing empty string.
    if (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    return lines;
  }

  /// Build the LCS dynamic programming table.
  ///
  /// Returns a 2D list where table[i][j] is the length of the LCS of
  /// oldLines[0..i-1] and newLines[0..j-1].
  static List<List<int>> _computeLcsTable(
    List<String> oldLines,
    List<String> newLines,
  ) {
    final m = oldLines.length;
    final n = newLines.length;

    // Create (m+1) x (n+1) table initialized to 0.
    final table = List.generate(
      m + 1,
      (_) => List.filled(n + 1, 0),
    );

    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        if (oldLines[i - 1] == newLines[j - 1]) {
          table[i][j] = table[i - 1][j - 1] + 1;
        } else {
          table[i][j] = table[i - 1][j] > table[i][j - 1]
              ? table[i - 1][j]
              : table[i][j - 1];
        }
      }
    }

    return table;
  }

  /// Backtrack through the LCS table to produce diff lines.
  ///
  /// Lines are appended in reverse order (from the end of both texts to the
  /// beginning) and should be reversed after this method returns.
  static void _backtrack(
    List<List<int>> table,
    List<String> oldLines,
    List<String> newLines,
    int i,
    int j,
    List<DiffLine> result,
  ) {
    while (i > 0 && j > 0) {
      if (oldLines[i - 1] == newLines[j - 1]) {
        // Lines match -- unchanged.
        result.add(DiffLine(text: oldLines[i - 1], type: DiffType.unchanged));
        i--;
        j--;
      } else if (table[i - 1][j] >= table[i][j - 1]) {
        // Line in old but not in new -- removed.
        result.add(DiffLine(text: oldLines[i - 1], type: DiffType.removed));
        i--;
      } else {
        // Line in new but not in old -- added.
        result.add(DiffLine(text: newLines[j - 1], type: DiffType.added));
        j--;
      }
    }

    // Remaining lines in old text are removed.
    while (i > 0) {
      result.add(DiffLine(text: oldLines[i - 1], type: DiffType.removed));
      i--;
    }

    // Remaining lines in new text are added.
    while (j > 0) {
      result.add(DiffLine(text: newLines[j - 1], type: DiffType.added));
      j--;
    }
  }
}
