// Tests for the TextDiff and DiffLine domain models.
//
// Tests cover:
// - Identical texts produce isIdentical=true with zero added/removed
// - Empty old text -> all lines added
// - Empty new text -> all lines removed
// - Single-line add/remove
// - Multi-line mixed changes (add, remove, unchanged)
// - DiffLine.toString() prefix formatting
// - linesAdded / linesRemoved / linesUnchanged counts
// - Both empty strings -> isIdentical true
// - Trailing newline handling
// - Large multi-line text diff correctness

import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/domain/text_diff.dart';

void main() {
  group('TextDiff', () {
    test('identical texts produce isIdentical true, 0 added, 0 removed', () {
      const text = 'line one\nline two\nline three';
      final diff = TextDiff.compute(text, text);

      expect(diff.isIdentical, isTrue);
      expect(diff.linesAdded, equals(0));
      expect(diff.linesRemoved, equals(0));
      expect(diff.linesUnchanged, equals(3));
    });

    test('empty old text results in all lines added', () {
      const newText = 'alpha\nbeta\ngamma';
      final diff = TextDiff.compute('', newText);

      expect(diff.isIdentical, isFalse);
      expect(diff.linesAdded, equals(3));
      expect(diff.linesRemoved, equals(0));
      expect(diff.linesUnchanged, equals(0));
      for (final line in diff.lines) {
        expect(line.type, equals(DiffType.added));
      }
    });

    test('empty new text results in all lines removed', () {
      const oldText = 'alpha\nbeta\ngamma';
      final diff = TextDiff.compute(oldText, '');

      expect(diff.isIdentical, isFalse);
      expect(diff.linesAdded, equals(0));
      expect(diff.linesRemoved, equals(3));
      expect(diff.linesUnchanged, equals(0));
      for (final line in diff.lines) {
        expect(line.type, equals(DiffType.removed));
      }
    });

    test('single line added at the end', () {
      const oldText = 'line one\nline two';
      const newText = 'line one\nline two\nline three';
      final diff = TextDiff.compute(oldText, newText);

      expect(diff.isIdentical, isFalse);
      expect(diff.linesAdded, equals(1));
      expect(diff.linesRemoved, equals(0));
      expect(diff.linesUnchanged, equals(2));
    });

    test('single line removed from the middle', () {
      const oldText = 'alpha\nbeta\ngamma';
      const newText = 'alpha\ngamma';
      final diff = TextDiff.compute(oldText, newText);

      expect(diff.isIdentical, isFalse);
      expect(diff.linesAdded, equals(0));
      expect(diff.linesRemoved, equals(1));
      expect(diff.linesUnchanged, equals(2));
      expect(
        diff.lines.where((l) => l.type == DiffType.removed).first.text,
        equals('beta'),
      );
    });

    test('multi-line mixed changes (add, remove, unchanged)', () {
      // old: A B C D E
      // new: A X C Y E
      // removed: B, D
      // added: X, Y
      // unchanged: A, C, E
      const oldText = 'A\nB\nC\nD\nE';
      const newText = 'A\nX\nC\nY\nE';
      final diff = TextDiff.compute(oldText, newText);

      expect(diff.linesAdded, equals(2));
      expect(diff.linesRemoved, equals(2));
      expect(diff.linesUnchanged, equals(3));
      expect(diff.isIdentical, isFalse);

      final addedTexts = diff.lines
          .where((l) => l.type == DiffType.added)
          .map((l) => l.text)
          .toList();
      expect(addedTexts, containsAll(['X', 'Y']));

      final removedTexts = diff.lines
          .where((l) => l.type == DiffType.removed)
          .map((l) => l.text)
          .toList();
      expect(removedTexts, containsAll(['B', 'D']));

      final unchangedTexts = diff.lines
          .where((l) => l.type == DiffType.unchanged)
          .map((l) => l.text)
          .toList();
      expect(unchangedTexts, containsAll(['A', 'C', 'E']));
    });

    test('both empty strings produce isIdentical true', () {
      final diff = TextDiff.compute('', '');

      expect(diff.isIdentical, isTrue);
      expect(diff.lines, isEmpty);
      expect(diff.linesAdded, equals(0));
      expect(diff.linesRemoved, equals(0));
      expect(diff.linesUnchanged, equals(0));
    });

    test('trailing newline is stripped and does not create extra empty line',
        () {
      // Text with trailing newline should not produce an extra empty-line diff entry.
      const oldText = 'line one\nline two\n';
      const newText = 'line one\nline two\n';
      final diff = TextDiff.compute(oldText, newText);

      expect(diff.isIdentical, isTrue);
      expect(diff.linesUnchanged, equals(2));
    });

    test('trailing newline added produces a single added line', () {
      const oldText = 'line one\nline two';
      const newText = 'line one\nline two\nnew line\n';
      final diff = TextDiff.compute(oldText, newText);

      expect(diff.isIdentical, isFalse);
      expect(diff.linesAdded, equals(1));
      expect(diff.linesUnchanged, equals(2));
    });

    test('large multi-line text diff correctness', () {
      // Build a 100-line old text and a 100-line new text where every other
      // line changed.
      final oldLines = List.generate(100, (i) => 'old line $i');
      final newLines = List.generate(100, (i) {
        if (i.isEven) return 'old line $i'; // keep even lines
        return 'new line $i'; // replace odd lines
      });
      final oldText = oldLines.join('\n');
      final newText = newLines.join('\n');

      final diff = TextDiff.compute(oldText, newText);

      // 50 even lines are unchanged, 50 odd lines are removed and 50 are added.
      expect(diff.linesUnchanged, equals(50));
      expect(diff.linesRemoved, equals(50));
      expect(diff.linesAdded, equals(50));
    });
  });

  group('DiffLine', () {
    test('toString prefixes added lines with "+ "', () {
      const line = DiffLine(text: 'hello', type: DiffType.added);
      expect(line.toString(), equals('+ hello'));
    });

    test('toString prefixes removed lines with "- "', () {
      const line = DiffLine(text: 'world', type: DiffType.removed);
      expect(line.toString(), equals('- world'));
    });

    test('toString prefixes unchanged lines with space', () {
      const line = DiffLine(text: 'same', type: DiffType.unchanged);
      expect(line.toString(), equals('  same'));
    });

    test('equality: same text and type are equal', () {
      const a = DiffLine(text: 'x', type: DiffType.added);
      const b = DiffLine(text: 'x', type: DiffType.added);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality: different type are not equal', () {
      const a = DiffLine(text: 'x', type: DiffType.added);
      const b = DiffLine(text: 'x', type: DiffType.removed);
      expect(a, isNot(equals(b)));
    });

    test('equality: different text are not equal', () {
      const a = DiffLine(text: 'a', type: DiffType.unchanged);
      const b = DiffLine(text: 'b', type: DiffType.unchanged);
      expect(a, isNot(equals(b)));
    });
  });
}
