import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/widgets/toc_extractor.dart';

void main() {
  // ===========================================================================
  // TocEntry
  // ===========================================================================

  group('TocEntry', () {
    test('creates with required fields', () {
      const entry = TocEntry(
        level: 1,
        text: 'Introduction',
        id: 'toc-0',
        lineIndex: 0,
      );

      expect(entry.level, 1);
      expect(entry.text, 'Introduction');
      expect(entry.id, 'toc-0');
      expect(entry.lineIndex, 0);
    });

    test('equal entries are considered equal', () {
      const a = TocEntry(level: 2, text: 'Foo', id: 'toc-0', lineIndex: 3);
      const b = TocEntry(level: 2, text: 'Foo', id: 'toc-0', lineIndex: 3);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different entries are not equal', () {
      const a = TocEntry(level: 1, text: 'A', id: 'toc-0', lineIndex: 0);
      const b = TocEntry(level: 1, text: 'B', id: 'toc-1', lineIndex: 1);

      expect(a, isNot(equals(b)));
    });

    test('equality differs by level', () {
      const a = TocEntry(level: 1, text: 'X', id: 'toc-0', lineIndex: 0);
      const b = TocEntry(level: 2, text: 'X', id: 'toc-0', lineIndex: 0);

      expect(a, isNot(equals(b)));
    });

    test('equality differs by lineIndex', () {
      const a = TocEntry(level: 1, text: 'X', id: 'toc-0', lineIndex: 0);
      const b = TocEntry(level: 1, text: 'X', id: 'toc-0', lineIndex: 5);

      expect(a, isNot(equals(b)));
    });
  });

  // ===========================================================================
  // extractToc -- ATX headings
  // ===========================================================================

  group('extractToc ATX headings', () {
    test('extracts a single level-1 heading', () {
      final result = extractToc('# Introduction');

      expect(result.length, 1);
      expect(result[0].level, 1);
      expect(result[0].text, 'Introduction');
      expect(result[0].id, 'toc-0');
      expect(result[0].lineIndex, 0);
    });

    test('extracts a single level-2 heading', () {
      final result = extractToc('## Section One');

      expect(result.length, 1);
      expect(result[0].level, 2);
      expect(result[0].text, 'Section One');
    });

    test('extracts heading levels 1 through 6', () {
      const md = '# H1\n## H2\n### H3\n#### H4\n##### H5\n###### H6';
      final result = extractToc(md);

      expect(result.length, 6);
      for (var i = 0; i < 6; i++) {
        expect(result[i].level, i + 1);
        expect(result[i].text, 'H${i + 1}');
      }
    });

    test('assigns sequential IDs', () {
      const md = '# A\n## B\n### C';
      final result = extractToc(md);

      expect(result[0].id, 'toc-0');
      expect(result[1].id, 'toc-1');
      expect(result[2].id, 'toc-2');
    });

    test('assigns correct line indices', () {
      const md = 'some text\n# First\nmore text\n## Second';
      final result = extractToc(md);

      expect(result[0].lineIndex, 1);
      expect(result[1].lineIndex, 3);
    });

    test('strips trailing # from ATX headings', () {
      final result = extractToc('# Heading ##');

      expect(result[0].text, 'Heading');
    });

    test('strips leading and trailing whitespace from heading text', () {
      final result = extractToc('#   My Heading   ');

      expect(result[0].text, 'My Heading');
    });

    test('ignores ATX headings with no text after #', () {
      // The regex requires at least one character after the # and space,
      // but if the text is empty after trim, it should be skipped.
      final result = extractToc('# ');

      expect(result, isEmpty);
    });

    test('handles up to 3 spaces before #', () {
      final result = extractToc('   ## Indented');

      expect(result.length, 1);
      expect(result[0].level, 2);
      expect(result[0].text, 'Indented');
    });
  });

  // ===========================================================================
  // extractToc -- Setext headings
  // ===========================================================================

  group('extractToc Setext headings', () {
    test('extracts Setext level-1 heading (=== underline)', () {
      final result = extractToc('My Title\n========');

      expect(result.length, 1);
      expect(result[0].level, 1);
      expect(result[0].text, 'My Title');
      expect(result[0].lineIndex, 0);
    });

    test('extracts Setext level-2 heading (--- underline)', () {
      final result = extractToc('Section\n-------');

      expect(result.length, 1);
      expect(result[0].level, 2);
      expect(result[0].text, 'Section');
    });

    test('setext underline with single character works', () {
      final result = extractToc('Title\n=');

      expect(result.length, 1);
      expect(result[0].level, 1);
    });

    test('setext underline with many characters works', () {
      final result = extractToc('Title\n===========');

      expect(result.length, 1);
      expect(result[0].level, 1);
    });

    test('setext heading at end of document', () {
      final result = extractToc('Intro\n\nLast Heading\n---');

      expect(result.length, 1);
      expect(result[0].level, 2);
      expect(result[0].text, 'Last Heading');
      expect(result[0].lineIndex, 2);
    });

    test('setext heading does not match if text line is empty', () {
      final result = extractToc('\n===');

      expect(result, isEmpty);
    });
  });

  // ===========================================================================
  // extractToc -- fenced code blocks
  // ===========================================================================

  group('extractToc fenced code blocks', () {
    test('ignores ATX headings inside triple-backtick code blocks', () {
      const md = '# Real Heading\n```\n# Fake Heading\n```\n## Another Real';
      final result = extractToc(md);

      expect(result.length, 2);
      expect(result[0].text, 'Real Heading');
      expect(result[1].text, 'Another Real');
    });

    test('ignores ATX headings inside triple-tilde code blocks', () {
      const md = '~~~\n# Ignored\n~~~';
      final result = extractToc(md);

      expect(result, isEmpty);
    });

    test('handles code block at the end without closing fence', () {
      const md = '# Heading\n```\n# Still in code';
      final result = extractToc(md);

      expect(result.length, 1);
      expect(result[0].text, 'Heading');
    });

    test('handles multiple code blocks', () {
      const md = '# H1\n```\n# skip\n```\n## H2\n```\n# skip again\n```';
      final result = extractToc(md);

      expect(result.length, 2);
      expect(result[0].text, 'H1');
      expect(result[1].text, 'H2');
    });
  });

  // ===========================================================================
  // extractToc -- indented code blocks
  // ===========================================================================

  group('extractToc indented code blocks', () {
    test('ignores headings indented with 4 spaces', () {
      const md = '# Real\n    # Indented';
      final result = extractToc(md);

      expect(result.length, 1);
      expect(result[0].text, 'Real');
    });

    test('ignores headings indented with a tab', () {
      const md = '# Real\n\t# TabIndented';
      final result = extractToc(md);

      expect(result.length, 1);
      expect(result[0].text, 'Real');
    });
  });

  // ===========================================================================
  // extractToc -- empty / edge cases
  // ===========================================================================

  group('extractToc edge cases', () {
    test('returns empty list for empty string', () {
      final result = extractToc('');

      expect(result, isEmpty);
    });

    test('returns empty list for content with no headings', () {
      final result = extractToc('Just some text\nNo headings here\nOr here');

      expect(result, isEmpty);
    });

    test('returns empty list for blank lines only', () {
      final result = extractToc('\n\n\n');

      expect(result, isEmpty);
    });

    test('does not match lines that look like headings but are not', () {
      // No space after #
      final result = extractToc('#NotAHeading');

      expect(result, isEmpty);
    });

    test('does not match more than 6 # characters', () {
      // 7 hashes -- not a valid ATX heading
      final result = extractToc('####### Not a heading');

      expect(result, isEmpty);
    });

    test('handles mixed ATX and Setext headings', () {
      const md = '''# Title

## Section

Sub Heading
-----------

### Subsection''';

      final result = extractToc(md);

      expect(result.length, 4);
      expect(result[0].level, 1);
      expect(result[0].text, 'Title');
      expect(result[1].level, 2);
      expect(result[1].text, 'Section');
      expect(result[2].level, 2);
      expect(result[2].text, 'Sub Heading');
      expect(result[3].level, 3);
      expect(result[3].text, 'Subsection');
    });

    test('line index is correct after skipping setext underline', () {
      const md = 'Title\n===\n## Next';
      final result = extractToc(md);

      // First heading at line 0, second at line 2.
      expect(result.length, 2);
      expect(result[0].lineIndex, 0);
      expect(result[1].lineIndex, 2);
    });

    test('heading with inline code and links is extracted as-is', () {
      final result = extractToc('# Heading with `code` and [link](url)');

      expect(result.length, 1);
      expect(result[0].text, 'Heading with `code` and [link](url)');
    });
  });
}
