import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Utility class that computes cursor screen position from a character offset
/// within an editor widget.
///
/// Uses the editor's [RenderBox] for accurate layout when available, and falls
/// back to a line-counting heuristic based on editor width and font metrics.
class CursorPositionCalculator {
  CursorPositionCalculator._();

  /// Default line height used by the heuristic when no better value exists.
  static const double defaultLineHeight = 20.0;

  /// Default font size used by the heuristic for chars-per-line estimation.
  static const double defaultFontSize = 14.0;

  /// Approximate average character width as a fraction of font size.
  /// For a typical proportional font at 14px this works out to roughly 7-8px.
  static const double _charWidthFraction = 0.55;

  /// Calculate the (x, y) position for a cursor at [characterOffset] within
  /// the editor content.
  ///
  /// When [editorBox] is available and attached, this uses
  /// [RenderBox.getLocalForInvalid] / text layout information for precise
  /// positioning. Otherwise it falls back to a line-counting heuristic.
  ///
  /// [content] is the plain text content of the editor, used by the fallback
  /// heuristic to count explicit newlines and estimate line wrapping.
  ///
  /// [editorWidth] overrides the detected width when no [editorBox] is present.
  /// [lineHeight] overrides the line height for the heuristic.
  /// [fontSize] overrides the font size for chars-per-line calculation.
  /// [horizontalPadding] accounts for left/right padding inside the editor.
  static Offset? calculatePosition({
    required int characterOffset,
    required String content,
    RenderBox? editorBox,
    double? editorWidth,
    double lineHeight = defaultLineHeight,
    double fontSize = defaultFontSize,
    double horizontalPadding = 16.0,
  }) {
    if (characterOffset < 0) return null;

    // Attempt precise positioning via RenderBox.
    if (editorBox != null && editorBox.hasSize) {
      final precise = _positionFromRenderBox(
        editorBox,
        characterOffset,
        content,
        lineHeight,
      );
      if (precise != null) return precise;
    }

    // Fallback heuristic.
    return _positionFromHeuristic(
      characterOffset: characterOffset,
      content: content,
      width: editorWidth ?? 300.0,
      lineHeight: lineHeight,
      fontSize: fontSize,
      horizontalPadding: horizontalPadding,
    );
  }

  /// Try to obtain position from the [RenderBox] by creating a [TextPainter]
  /// that mirrors the editor's text layout.
  static Offset? _positionFromRenderBox(
    RenderBox editorBox,
    int characterOffset,
    String content,
    double lineHeight,
  ) {
    try {
      // Clamp offset to content length.
      final clamped = characterOffset.clamp(0, content.length);
      final span =
          TextSpan(text: content, style: const TextStyle(fontSize: 14.0));

      final painter = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
        maxLines: null,
      );

      painter.layout(maxWidth: editorBox.size.width);

      final position =
          TextPosition(offset: clamped, affinity: TextAffinity.downstream);
      final cursorOffset = painter.getOffsetForCaret(position, Rect.zero);

      painter.dispose();

      // Return offset relative to the editor box top-left.
      return Offset(
        cursorOffset.dx.clamp(0.0, editorBox.size.width),
        cursorOffset.dy,
      );
    } catch (_) {
      // If TextPainter fails for any reason, return null to trigger fallback.
      return null;
    }
  }

  /// Heuristic: walk through the content up to [characterOffset], counting
  /// explicit newlines and estimating wrapped lines based on available width.
  static Offset _positionFromHeuristic({
    required int characterOffset,
    required String content,
    required double width,
    required double lineHeight,
    required double fontSize,
    required double horizontalPadding,
  }) {
    final availableWidth = width - horizontalPadding;
    final charWidth = fontSize * _charWidthFraction;
    final charsPerLine = (availableWidth / charWidth).floor().clamp(1, 10000);

    // Walk through the content up to the target offset, counting lines.
    var currentLine = 0;
    var currentCol = 0;
    var charsOnCurrentLine = 0;

    final end = characterOffset.clamp(0, content.length);
    for (var i = 0; i < end; i++) {
      final ch = content[i];
      if (ch == '\n') {
        currentLine++;
        charsOnCurrentLine = 0;
        currentCol = 0;
      } else {
        charsOnCurrentLine++;
        currentCol++;
        // Wrap to next line when exceeding chars per line.
        if (charsOnCurrentLine >= charsPerLine) {
          currentLine++;
          charsOnCurrentLine = 0;
          currentCol = 0;
        }
      }
    }

    final xOffset = (currentCol * charWidth).clamp(0.0, availableWidth);
    final yOffset = currentLine * lineHeight;

    return Offset(horizontalPadding / 2 + xOffset, yOffset);
  }

  /// Calculate positions for a selection range (start and end offsets).
  /// Returns a [SelectionRangePosition] with offsets for both the start and
  /// end of the selection, or null if the offsets are invalid.
  static SelectionRangePosition? calculateSelectionRange({
    required int startOffset,
    required int endOffset,
    required String content,
    RenderBox? editorBox,
    double? editorWidth,
    double lineHeight = defaultLineHeight,
    double fontSize = defaultFontSize,
    double horizontalPadding = 16.0,
  }) {
    if (startOffset < 0 || endOffset < startOffset) return null;

    final startPos = calculatePosition(
      characterOffset: startOffset,
      content: content,
      editorBox: editorBox,
      editorWidth: editorWidth,
      lineHeight: lineHeight,
      fontSize: fontSize,
      horizontalPadding: horizontalPadding,
    );
    final endPos = calculatePosition(
      characterOffset: endOffset,
      content: content,
      editorBox: editorBox,
      editorWidth: editorWidth,
      lineHeight: lineHeight,
      fontSize: fontSize,
      horizontalPadding: horizontalPadding,
    );

    if (startPos == null || endPos == null) return null;
    return SelectionRangePosition(start: startPos, end: endPos);
  }

  /// Compute the full height (in lines) of the given [content] string using
  /// the same heuristic parameters. Useful for sizing the overlay.
  static int totalLines(
    String content,
    double width,
    double fontSize,
    double horizontalPadding,
  ) {
    final availableWidth = width - horizontalPadding;
    final charWidth = fontSize * _charWidthFraction;
    final charsPerLine = (availableWidth / charWidth).floor().clamp(1, 10000);

    var lines = 1;
    var charsOnLine = 0;

    for (final ch in content.runes) {
      if (ch == '\n'.codeUnitAt(0)) {
        lines++;
        charsOnLine = 0;
      } else {
        charsOnLine++;
        if (charsOnLine >= charsPerLine) {
          lines++;
          charsOnLine = 0;
        }
      }
    }

    return lines;
  }
}

/// Holds the start and end offsets for a selection range within the editor.
class SelectionRangePosition {
  final Offset start;
  final Offset end;

  const SelectionRangePosition({required this.start, required this.end});

  /// Whether start and end are on the same line (close Y values).
  bool get isSingleLine => (start.dy - end.dy).abs() < 2.0;
}
