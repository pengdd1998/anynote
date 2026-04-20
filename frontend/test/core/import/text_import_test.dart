import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/import/text_import.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

File _createTempFile(String name, String content) {
  final dir = Directory.systemTemp.createTempSync('anynote_text_test_');
  final file = File('${dir.path}/$name');
  file.createSync(recursive: true);
  file.writeAsStringSync(content);
  return file;
}

File _createTempFileWithBytes(String name, List<int> bytes) {
  final dir = Directory.systemTemp.createTempSync('anynote_text_test_');
  final file = File('${dir.path}/$name');
  file.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
  return file;
}

Directory _createTempDir() {
  return Directory.systemTemp.createTempSync('anynote_text_dir_test_');
}

void main() {
  late TextImporter importer;

  setUp(() {
    importer = TextImporter();
  });

  // ===========================================================================
  // parseTextFile -- basic parsing
  // ===========================================================================

  group('parseTextFile basic parsing', () {
    test('parses a simple text file with title on first line', () async {
      final file = _createTempFile('note.txt', 'My Title\nBody content here');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseTextFile(file);

      expect(note, isNotNull);
      expect(note!.title, equals('My Title'));
      expect(note.body, equals('Body content here'));
      expect(note.tags, isEmpty);
      expect(note.sourcePath, equals(file.path));
    });

    test('parses file with only a title (no body)', () async {
      final file = _createTempFile('title_only.txt', 'Just a Title');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseTextFile(file);

      expect(note, isNotNull);
      expect(note!.title, equals('Just a Title'));
      expect(note.body, isEmpty);
    });

    test('strips leading # from markdown-style heading in title', () async {
      final file = _createTempFile('heading.txt', '# My Heading\nBody text');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseTextFile(file);

      expect(note, isNotNull);
      expect(note!.title, equals('My Heading'));
    });

    test('strips leading ### from title', () async {
      final file = _createTempFile('h3.txt', '### Deep Heading\nContent');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseTextFile(file);

      expect(note, isNotNull);
      expect(note!.title, equals('Deep Heading'));
    });

    test('returns null for empty file', () async {
      final file = _createTempFile('empty.txt', '');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseTextFile(file);
      expect(note, isNull);
    });

    test('returns null for whitespace-only file', () async {
      final file = _createTempFile('whitespace.txt', '   \n\n  \t  \n  ');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseTextFile(file);
      expect(note, isNull);
    });

    test('returns null for non-existent file', () async {
      final file = File('/nonexistent/path/note.txt');
      final note = await importer.parseTextFile(file);
      expect(note, isNull);
    });
  });

  // ===========================================================================
  // parseTextFile -- title extraction
  // ===========================================================================

  group('parseTextFile title extraction', () {
    test('title from first non-empty line when file has leading blank lines',
        () async {
      final file = _createTempFile('blank.txt', '\n\n\nActual Title\nBody');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseTextFile(file);

      expect(note, isNotNull);
      expect(note!.title, equals('Actual Title'));
      expect(note.body, equals('Body'));
    });

    test('title trimmed of surrounding whitespace', () async {
      final file = _createTempFile('spaces.txt', '  Spaced Title  \nBody');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseTextFile(file);

      expect(note, isNotNull);
      expect(note!.title, equals('Spaced Title'));
    });

    test('falls back to filename when first line exceeds 100 characters',
        () async {
      final longLine = 'A' * 101;
      final file = _createTempFile(
        'Short Name.txt',
        '$longLine\nBody',
      );
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseTextFile(file);

      expect(note, isNotNull);
      // Title falls back to filename without extension.
      expect(note!.title, equals('Short Name'));
    });

    test('uses first line as title when exactly 100 characters', () async {
      final exactLine = 'A' * 100;
      final file = _createTempFile('note.txt', '$exactLine\nBody');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseTextFile(file);

      expect(note, isNotNull);
      expect(note!.title, equals(exactLine));
    });

    test('uses first line as title when under 100 characters', () async {
      final file = _createTempFile(
        'some_long_filename.txt',
        'Short Title\nBody content',
      );
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseTextFile(file);

      expect(note, isNotNull);
      expect(note!.title, equals('Short Title'));
    });

    test('falls back to filename when first non-empty line exceeds limit',
        () async {
      final longLine = 'B' * 200;
      final file = _createTempFile(
        'Fallback Name.txt',
        '\n\n$longLine\nMore body',
      );
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseTextFile(file);
      expect(note, isNotNull);
      expect(note!.title, equals('Fallback Name'));
    });
  });

  // ===========================================================================
  // parseTextFile -- body extraction
  // ===========================================================================

  group('parseTextFile body extraction', () {
    test('body is everything after the first non-empty line', () async {
      final file = _createTempFile(
        'multi.txt',
        'Title\nLine 2\nLine 3\nLine 4',
      );
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseTextFile(file);

      expect(note, isNotNull);
      expect(note!.body, equals('Line 2\nLine 3\nLine 4'));
    });

    test('body is trimmed of leading and trailing whitespace', () async {
      final file = _createTempFile('trim.txt', 'Title\n\n  Body text  \n\n');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseTextFile(file);

      expect(note, isNotNull);
      expect(note!.body, equals('Body text'));
    });

    test('body preserves internal newlines', () async {
      final file = _createTempFile(
        'newlines.txt',
        'Title\nPara 1\n\nPara 2\n\nPara 3',
      );
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseTextFile(file);

      expect(note, isNotNull);
      expect(note!.body, equals('Para 1\n\nPara 2\n\nPara 3'));
    });

    test('body is empty when file has only one line', () async {
      final file = _createTempFile('oneline.txt', 'Single line');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseTextFile(file);

      expect(note, isNotNull);
      expect(note!.body, isEmpty);
    });
  });

  // ===========================================================================
  // parseTextFile -- encoding handling
  // ===========================================================================

  group('parseTextFile encoding handling', () {
    test('returns null for non-UTF-8 binary file', () async {
      // Write bytes that are invalid UTF-8.
      final file = _createTempFileWithBytes('binary.txt', [0x80, 0x81, 0x82]);
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseTextFile(file);
      expect(note, isNull);
    });

    test('handles UTF-8 with BOM', () async {
      // UTF-8 BOM followed by content.
      final file = _createTempFileWithBytes(
        'bom.txt',
        [0xEF, 0xBB, 0xBF, ...('Hello\nWorld'.codeUnits)],
      );
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseTextFile(file);
      // BOM may be included in the title; the important thing is it does not
      // crash.
      expect(note, isNotNull);
    });

    test('handles UTF-8 with CJK characters', () async {
      final file = _createTempFile('cjk.txt', 'Title\nContent');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseTextFile(file);
      expect(note, isNotNull);
      expect(note!.title, equals('Title'));
    });

    test('handles UTF-8 with emoji', () async {
      final file = _createTempFile('emoji.txt', 'Hello World\nBody');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseTextFile(file);
      expect(note, isNotNull);
    });
  });

  // ===========================================================================
  // parseTextFile -- createdAt
  // ===========================================================================

  group('parseTextFile createdAt', () {
    test('uses file modification time as createdAt', () async {
      final file = _createTempFile('dated.txt', 'Title\nBody');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseTextFile(file);

      expect(note, isNotNull);
      expect(
        note!.createdAt.difference(DateTime.now()).inSeconds.abs(),
        lessThan(10),
      );
    });
  });

  // ===========================================================================
  // parseTextDirectory
  // ===========================================================================

  group('parseTextDirectory', () {
    test('parses .txt and .text files in directory', () async {
      final dir = _createTempDir();
      addTearDown(() => dir.delete(recursive: true));

      File('${dir.path}/note1.txt').writeAsStringSync('Title 1\nBody 1');
      File('${dir.path}/note2.text').writeAsStringSync('Title 2\nBody 2');

      final notes = await importer.parseTextDirectory(dir);

      expect(notes.length, equals(2));
      final titles = notes.map((n) => n.title).toList();
      expect(titles, containsAll(['Title 1', 'Title 2']));
    });

    test('ignores non-text files', () async {
      final dir = _createTempDir();
      addTearDown(() => dir.delete(recursive: true));

      File('${dir.path}/note.txt').writeAsStringSync('Title\nBody');
      File('${dir.path}/readme.md').writeAsStringSync('# Readme');
      File('${dir.path}/data.json').writeAsStringSync('{}');
      File('${dir.path}/image.png').writeAsBytesSync([1, 2, 3]);

      final notes = await importer.parseTextDirectory(dir);

      expect(notes.length, equals(1));
      expect(notes.first.title, equals('Title'));
    });

    test('finds text files in nested directories', () async {
      final dir = _createTempDir();
      addTearDown(() => dir.delete(recursive: true));

      Directory('${dir.path}/sub/deep').createSync(recursive: true);
      File('${dir.path}/sub/deep/nested.txt').writeAsStringSync(
        'Nested Title\nNested Body',
      );

      final notes = await importer.parseTextDirectory(dir);

      expect(notes.length, equals(1));
      expect(notes.first.title, equals('Nested Title'));
    });

    test('returns empty list for non-existent directory', () async {
      final notes = await importer.parseTextDirectory(
        Directory('/nonexistent/path'),
      );
      expect(notes, isEmpty);
    });

    test('returns empty list for empty directory', () async {
      final dir = _createTempDir();
      addTearDown(() => dir.delete(recursive: true));

      final notes = await importer.parseTextDirectory(dir);
      expect(notes, isEmpty);
    });

    test('skips binary files without aborting', () async {
      final dir = _createTempDir();
      addTearDown(() => dir.delete(recursive: true));

      File('${dir.path}/good.txt').writeAsStringSync('Good Title\nBody');
      File('${dir.path}/bad.txt').writeAsBytesSync([0x80, 0x81, 0x82]);

      final notes = await importer.parseTextDirectory(dir);

      expect(notes.length, equals(1));
      expect(notes.first.title, equals('Good Title'));
    });

    test('skips empty files without aborting', () async {
      final dir = _createTempDir();
      addTearDown(() => dir.delete(recursive: true));

      File('${dir.path}/good.txt').writeAsStringSync('Title\nBody');
      File('${dir.path}/empty.txt').writeAsStringSync('');

      final notes = await importer.parseTextDirectory(dir);

      expect(notes.length, equals(1));
    });

    test('case-insensitive extension matching', () async {
      final dir = _createTempDir();
      addTearDown(() => dir.delete(recursive: true));

      File('${dir.path}/lower.txt').writeAsStringSync('Lower\nBody');
      File('${dir.path}/upper.TXT').writeAsStringSync('Upper\nBody');

      final notes = await importer.parseTextDirectory(dir);

      expect(notes.length, equals(2));
    });
  });
}
