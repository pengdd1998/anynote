import 'package:flutter/foundation.dart';

/// Manages the fold (collapse) state of heading sections in a note.
///
/// Each heading line is identified by its line index. The controller tracks
/// which headings are currently folded and provides utility methods to query
/// and manipulate fold state.
class SectionFoldController extends ChangeNotifier {
  /// Set of line indices where headings are currently folded.
  final Set<int> _foldedLines = {};

  /// Cached list of heading line indices, sorted ascending.
  /// Must be updated via [updateHeadings] when the document content changes.
  List<int> _headingLines = [];

  /// Returns true if the heading at [lineIndex] is currently folded.
  bool isFolded(int lineIndex) => _foldedLines.contains(lineIndex);

  /// Returns the current set of folded heading line indices.
  Set<int> get foldedLines => Set.unmodifiable(_foldedLines);

  /// Returns the number of currently folded sections.
  int get foldedCount => _foldedLines.length;

  /// Returns the list of heading line indices.
  List<int> get headingLines => List.unmodifiable(_headingLines);

  /// Updates the list of heading line indices from the current document content.
  /// This should be called whenever the editor content changes.
  void updateHeadings(List<int> headingIndices) {
    _headingLines = List.of(headingIndices);
    // Remove fold state for headings that no longer exist.
    _foldedLines.removeWhere((line) => !_headingLines.contains(line));
    notifyListeners();
  }

  /// Toggles the fold state of the heading at [lineIndex].
  /// If the line is folded, it unfolds it; if unfolded, it folds it.
  void toggleFold(int lineIndex) {
    if (_headingLines.isEmpty) return;
    if (!_headingLines.contains(lineIndex)) return;

    if (_foldedLines.contains(lineIndex)) {
      _foldedLines.remove(lineIndex);
    } else {
      _foldedLines.add(lineIndex);
    }
    notifyListeners();
  }

  /// Folds all heading sections.
  void foldAll() {
    _foldedLines.clear();
    _foldedLines.addAll(_headingLines);
    notifyListeners();
  }

  /// Unfolds all heading sections.
  void unfoldAll() {
    _foldedLines.clear();
    notifyListeners();
  }

  /// Returns the number of content lines hidden under the heading at
  /// [headingLine]. This counts all lines from the heading to the next
  /// heading (or document end), excluding the heading line itself.
  int foldedLineCount(int headingLine) {
    if (!_foldedLines.contains(headingLine)) return 0;

    final idx = _headingLines.indexOf(headingLine);
    if (idx < 0) return 0;

    final int startLine = headingLine + 1;
    final int endLine;
    if (idx + 1 < _headingLines.length) {
      endLine = _headingLines[idx + 1];
    } else {
      // Last heading: extend to the end of the document.
      // Returns a sentinel value; callers should use total line count.
      endLine = -1; // sentinel: means "to end of document"
    }

    if (endLine == -1) return -1; // caller must resolve with total lines
    return endLine - startLine;
  }

  /// Returns the number of content lines hidden under the heading at
  /// [headingLine] given the [totalLineCount] of the document.
  int foldedLineCountResolved(int headingLine, int totalLineCount) {
    if (!_foldedLines.contains(headingLine)) return 0;

    final idx = _headingLines.indexOf(headingLine);
    if (idx < 0) return 0;

    final int startLine = headingLine + 1;
    final int endLine;
    if (idx + 1 < _headingLines.length) {
      endLine = _headingLines[idx + 1];
    } else {
      endLine = totalLineCount;
    }

    return (endLine - startLine).clamp(0, totalLineCount);
  }

  /// Returns the line ranges that should be hidden due to folding.
  /// Each entry is a pair of [start, end) line indices.
  List<(int, int)> hiddenRanges(int totalLineCount) {
    final ranges = <(int, int)>[];
    for (final headingLine in _foldedLines) {
      final idx = _headingLines.indexOf(headingLine);
      if (idx < 0) continue;

      final start = headingLine + 1;
      final end = idx + 1 < _headingLines.length
          ? _headingLines[idx + 1]
          : totalLineCount;

      if (start < end) {
        ranges.add((start, end));
      }
    }
    return ranges;
  }

  @override
  void dispose() {
    _foldedLines.clear();
    _headingLines = [];
    super.dispose();
  }
}
