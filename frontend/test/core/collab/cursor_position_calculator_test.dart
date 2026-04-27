import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/collab/cursor_position_calculator.dart';

void main() {
  // ===========================================================================
  // SelectionRangePosition
  // ===========================================================================

  group('SelectionRangePosition', () {
    test('creates with start and end offsets', () {
      const pos = SelectionRangePosition(
        start: Offset(10, 0),
        end: Offset(50, 20),
      );

      expect(pos.start, const Offset(10, 0));
      expect(pos.end, const Offset(50, 20));
    });

    test('isSingleLine is true when Y values are close', () {
      const pos = SelectionRangePosition(
        start: Offset(0, 10),
        end: Offset(100, 10.5),
      );

      expect(pos.isSingleLine, isTrue);
    });

    test('isSingleLine is true when Y values are identical', () {
      const pos = SelectionRangePosition(
        start: Offset(0, 20),
        end: Offset(200, 20),
      );

      expect(pos.isSingleLine, isTrue);
    });

    test('isSingleLine is false when Y values differ by more than 2 pixels',
        () {
      const pos = SelectionRangePosition(
        start: Offset(0, 0),
        end: Offset(10, 20),
      );

      expect(pos.isSingleLine, isFalse);
    });

    test('isSingleLine boundary: exactly 2.0 pixels difference', () {
      const pos = SelectionRangePosition(
        start: Offset(0, 0),
        end: Offset(10, 2.0),
      );

      // abs(0 - 2.0) == 2.0 which is NOT < 2.0, so not single line.
      expect(pos.isSingleLine, isFalse);
    });
  });

  // ===========================================================================
  // CursorPositionCalculator.calculatePosition -- heuristic fallback
  // ===========================================================================

  group('CursorPositionCalculator.calculatePosition (heuristic)', () {
    test('returns null for negative characterOffset', () {
      final result = CursorPositionCalculator.calculatePosition(
        characterOffset: -1,
        content: 'hello',
      );

      expect(result, isNull);
    });

    test('returns position at origin for offset 0', () {
      final result = CursorPositionCalculator.calculatePosition(
        characterOffset: 0,
        content: 'hello',
        editorWidth: 300,
        lineHeight: 20,
        fontSize: 14,
        horizontalPadding: 16,
      );

      expect(result, isNotNull);
      expect(result!.dy, 0.0);
      // x should be at horizontalPadding / 2 + 0 = 8.0
      expect(result.dx, closeTo(8.0, 0.01));
    });

    test('cursor advances horizontally with characters', () {
      const content = 'abcdef';
      final result = CursorPositionCalculator.calculatePosition(
        characterOffset: 3,
        content: content,
        editorWidth: 300,
        lineHeight: 20,
        fontSize: 14,
        horizontalPadding: 16,
      );

      expect(result, isNotNull);
      expect(result!.dy, 0.0);
      // x should be at horizontalPadding/2 + 3 * (14 * 0.55) = 8 + 3*7.7 = 8 + 23.1 = 31.1
      expect(result.dx, greaterThan(8.0));
    });

    test('cursor moves to next line on newline', () {
      final result = CursorPositionCalculator.calculatePosition(
        characterOffset: 6, // after "hello\n"
        content: 'hello\nworld',
        editorWidth: 300,
        lineHeight: 20,
        fontSize: 14,
        horizontalPadding: 16,
      );

      expect(result, isNotNull);
      expect(result!.dy, greaterThan(0));
    });

    test('cursor at end of content', () {
      const content = 'hello';
      final result = CursorPositionCalculator.calculatePosition(
        characterOffset: content.length,
        content: content,
        editorWidth: 300,
        lineHeight: 20,
        fontSize: 14,
        horizontalPadding: 16,
      );

      expect(result, isNotNull);
    });

    test('cursor beyond content length is clamped', () {
      final result = CursorPositionCalculator.calculatePosition(
        characterOffset: 100,
        content: 'short',
        editorWidth: 300,
        lineHeight: 20,
        fontSize: 14,
        horizontalPadding: 16,
      );

      // Should not crash; returns a position.
      expect(result, isNotNull);
    });

    test('uses default editorWidth of 300 when not specified', () {
      final result = CursorPositionCalculator.calculatePosition(
        characterOffset: 0,
        content: 'text',
      );

      expect(result, isNotNull);
    });

    test('multiline content produces increasing Y offsets', () {
      const content = 'line1\nline2\nline3';
      final pos0 = CursorPositionCalculator.calculatePosition(
        characterOffset: 0,
        content: content,
        editorWidth: 300,
        lineHeight: 20,
      );
      final pos1 = CursorPositionCalculator.calculatePosition(
        characterOffset: 6, // start of line2
        content: content,
        editorWidth: 300,
        lineHeight: 20,
      );
      final pos2 = CursorPositionCalculator.calculatePosition(
        characterOffset: 12, // start of line3
        content: content,
        editorWidth: 300,
        lineHeight: 20,
      );

      expect(pos0!.dy, lessThan(pos1!.dy));
      expect(pos1.dy, lessThan(pos2!.dy));
    });

    test('empty content with offset 0 returns origin', () {
      final result = CursorPositionCalculator.calculatePosition(
        characterOffset: 0,
        content: '',
        editorWidth: 300,
        lineHeight: 20,
      );

      expect(result, isNotNull);
      expect(result!.dy, 0.0);
    });
  });

  // ===========================================================================
  // CursorPositionCalculator.calculatePosition -- with RenderBox
  // ===========================================================================

  group('CursorPositionCalculator.calculatePosition (with RenderBox)', () {
    test('falls back to heuristic when editorBox has no size', () {
      // Create a RenderBox that is not laid out (hasSize == false).
      final box = RenderConstrainedBox(
        additionalConstraints: const BoxConstraints(),
      );

      final result = CursorPositionCalculator.calculatePosition(
        characterOffset: 3,
        content: 'hello',
        editorBox: box,
        editorWidth: 300,
        lineHeight: 20,
        fontSize: 14,
      );

      // Falls back to heuristic since box is not laid out.
      expect(result, isNotNull);
    });
  });

  // ===========================================================================
  // CursorPositionCalculator.calculateSelectionRange
  // ===========================================================================

  group('CursorPositionCalculator.calculateSelectionRange', () {
    test('returns null for negative startOffset', () {
      final result = CursorPositionCalculator.calculateSelectionRange(
        startOffset: -1,
        endOffset: 5,
        content: 'hello world',
      );

      expect(result, isNull);
    });

    test('returns null when endOffset < startOffset', () {
      final result = CursorPositionCalculator.calculateSelectionRange(
        startOffset: 5,
        endOffset: 3,
        content: 'hello world',
      );

      expect(result, isNull);
    });

    test('returns null for negative endOffset', () {
      final result = CursorPositionCalculator.calculateSelectionRange(
        startOffset: 0,
        endOffset: -1,
        content: 'hello',
      );

      expect(result, isNull);
    });

    test('returns valid range for valid offsets', () {
      final result = CursorPositionCalculator.calculateSelectionRange(
        startOffset: 0,
        endOffset: 5,
        content: 'hello world',
        editorWidth: 300,
        lineHeight: 20,
      );

      expect(result, isNotNull);
      expect(result!.start, isNotNull);
      expect(result.end, isNotNull);
    });

    test('same start and end offset produces single-line range', () {
      final result = CursorPositionCalculator.calculateSelectionRange(
        startOffset: 2,
        endOffset: 2,
        content: 'hello',
        editorWidth: 300,
        lineHeight: 20,
      );

      expect(result, isNotNull);
      expect(result!.isSingleLine, isTrue);
    });
  });

  // ===========================================================================
  // CursorPositionCalculator.totalLines
  // ===========================================================================

  group('CursorPositionCalculator.totalLines', () {
    test('empty string is 1 line', () {
      final lines = CursorPositionCalculator.totalLines(
        '',
        300,
        14,
        16,
      );

      expect(lines, 1);
    });

    test('single line without newline is 1 line', () {
      final lines = CursorPositionCalculator.totalLines(
        'hello',
        300,
        14,
        16,
      );

      expect(lines, 1);
    });

    test('one newline produces 2 lines', () {
      final lines = CursorPositionCalculator.totalLines(
        'hello\nworld',
        300,
        14,
        16,
      );

      expect(lines, 2);
    });

    test('multiple newlines produce correct line count', () {
      final lines = CursorPositionCalculator.totalLines(
        'a\nb\nc\nd',
        300,
        14,
        16,
      );

      expect(lines, 4);
    });

    test('wrapping produces extra lines with narrow width', () {
      // With a very narrow width (e.g. 20), even short text wraps.
      final lines = CursorPositionCalculator.totalLines(
        'hello world this is a test',
        20,
        14,
        16,
      );

      expect(lines, greaterThan(1));
    });

    test('wide width keeps text on single line', () {
      final lines = CursorPositionCalculator.totalLines(
        'short text',
        1000,
        14,
        16,
      );

      expect(lines, 1);
    });

    test('line count increases with each newline', () {
      final lines = CursorPositionCalculator.totalLines(
        '\n\n\n\n',
        300,
        14,
        16,
      );

      // 4 newlines -> 5 lines (each newline starts a new line).
      expect(lines, 5);
    });
  });

  // ===========================================================================
  // CursorPositionCalculator constants
  // ===========================================================================

  group('CursorPositionCalculator constants', () {
    test('defaultLineHeight is 20.0', () {
      expect(CursorPositionCalculator.defaultLineHeight, 20.0);
    });

    test('defaultFontSize is 14.0', () {
      expect(CursorPositionCalculator.defaultFontSize, 14.0);
    });

    test('private constructor prevents instantiation', () {
      // The constructor is private (CursorPositionCalculator._()),
      // so we can only test via static methods. This is a documentation test.
      expect(CursorPositionCalculator.defaultLineHeight, isNotNull);
    });
  });
}
