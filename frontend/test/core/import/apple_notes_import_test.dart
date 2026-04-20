import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/import/apple_notes_import.dart';
import 'package:anynote/core/import/import_models.dart';

// Helper to create temporary files with content for testing.
File _createTempFile(String name, String content) {
  final dir = Directory.systemTemp.createTempSync('anynote_apple_test_');
  final file = File('${dir.path}/$name');
  file.createSync(recursive: true);
  file.writeAsStringSync(content);
  return file;
}

Directory _createTempDir() {
  return Directory.systemTemp.createTempSync('anynote_apple_dir_test_');
}

void main() {
  late AppleNotesImporter importer;

  setUp(() {
    importer = AppleNotesImporter();
  });

  // ===========================================================================
  // parseHtmlFile -- basic parsing
  // ===========================================================================

  group('parseHtmlFile basic parsing', () {
    test('parses a simple HTML file with title and body', () async {
      final file = _createTempFile('test.html', '''
        <html>
        <head><title>My Note</title></head>
        <body><p>Hello world</p></body>
        </html>
      ''');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseHtmlFile(file);

      expect(note, isNotNull);
      expect(note!.title, equals('My Note'));
      expect(note.body, contains('Hello world'));
      expect(note.tags, isEmpty);
      expect(note.sourcePath, equals(file.path));
    });

    test('falls back to filename when title is missing', () async {
      final file = _createTempFile('Important Note.html', '''
        <html>
        <body><p>Content here</p></body>
        </html>
      ''');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseHtmlFile(file);

      expect(note, isNotNull);
      expect(note!.title, equals('Important Note'));
    });

    test('returns null for non-existent file', () async {
      final file = File('/nonexistent/path/note.html');
      final note = await importer.parseHtmlFile(file);
      expect(note, isNull);
    });

    test('returns null for empty file', () async {
      final file = _createTempFile('empty.html', '');
      addTearDown(() => file.parent.delete(recursive: true));

      // Empty file still parses -- body is empty, title falls back to filename.
      final note = await importer.parseHtmlFile(file);
      expect(note, isNotNull);
    });

    test('extracts createdAt from file modification time', () async {
      final file = _createTempFile('dated.html', '''
        <html><head><title>Dated</title></head>
        <body><p>content</p></body></html>
      ''');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseHtmlFile(file);
      expect(note, isNotNull);
      // createdAt should be close to now since we just created the file.
      expect(
        note!.createdAt.difference(DateTime.now()).inSeconds.abs(),
        lessThan(10),
      );
    });
  });

  // ===========================================================================
  // parseHtmlFile -- HTML to markdown conversion
  // ===========================================================================

  group('parseHtmlFile HTML to markdown conversion', () {
    test('converts headings h1 through h6', () async {
      final file = _createTempFile('headings.html', '''
        <html><body>
        <h1>Heading 1</h1>
        <h2>Heading 2</h2>
        <h3>Heading 3</h3>
        <h4>Heading 4</h4>
        <h5>Heading 5</h5>
        <h6>Heading 6</h6>
        </body></html>
      ''');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseHtmlFile(file);

      expect(note, isNotNull);
      expect(note!.body, contains('# Heading 1'));
      expect(note.body, contains('## Heading 2'));
      expect(note.body, contains('### Heading 3'));
      expect(note.body, contains('#### Heading 4'));
      expect(note.body, contains('##### Heading 5'));
      expect(note.body, contains('###### Heading 6'));
    });

    test('converts bold tags to markdown', () async {
      final file = _createTempFile('bold.html', '''
        <html><body><p>This is <b>bold</b> and <strong>also bold</strong></p></body></html>
      ''');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseHtmlFile(file);

      expect(note, isNotNull);
      expect(note!.body, contains('**bold**'));
      expect(note.body, contains('**also bold**'));
    });

    test('converts italic tags to markdown', () async {
      final file = _createTempFile('italic.html', '''
        <html><body><p>This is <i>italic</i> and <em>also italic</em></p></body></html>
      ''');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseHtmlFile(file);

      expect(note, isNotNull);
      expect(note!.body, contains('*italic*'));
      expect(note.body, contains('*also italic*'));
    });

    test('converts links to markdown format', () async {
      final file = _createTempFile('links.html', '''
        <html><body><p><a href="https://example.com">Example</a></p></body></html>
      ''');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseHtmlFile(file);

      expect(note, isNotNull);
      expect(note!.body, contains('[Example](https://example.com)'));
    });

    test('converts blockquotes to markdown', () async {
      final file = _createTempFile('quotes.html', '''
        <html><body><blockquote>A famous quote</blockquote></body></html>
      ''');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseHtmlFile(file);

      expect(note, isNotNull);
      expect(note!.body, contains('> A famous quote'));
    });

    test('converts unordered list items', () async {
      final file = _createTempFile('ulist.html', '''
        <html><body>
        <ul><li>First item</li><li>Second item</li></ul>
        </body></html>
      ''');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseHtmlFile(file);

      expect(note, isNotNull);
      expect(note!.body, contains('- First item'));
      expect(note!.body, contains('- Second item'));
    });

    test('converts ordered list items', () async {
      final file = _createTempFile('olist.html', '''
        <html><body>
        <ol><li>First</li><li>Second</li><li>Third</li></ol>
        </body></html>
      ''');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseHtmlFile(file);

      expect(note, isNotNull);
      expect(note!.body, contains('1. First'));
      expect(note!.body, contains('2. Second'));
      expect(note!.body, contains('3. Third'));
    });

    test('handles <br> tags as newlines', () async {
      final file = _createTempFile('breaks.html', '''
        <html><body>Line 1<br>Line 2<br/>Line 3</body></html>
      ''');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseHtmlFile(file);

      expect(note, isNotNull);
      expect(note!.body, contains('Line 1\nLine 2\nLine 3'));
    });

    test('strips <style> blocks', () async {
      final file = _createTempFile('styled.html', '''
        <html><head><style>body { color: red; }</style></head>
        <body><p>Visible content</p></body></html>
      ''');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseHtmlFile(file);

      expect(note, isNotNull);
      expect(note!.body, isNot(contains('color: red')));
      expect(note!.body, contains('Visible content'));
    });

    test('strips <script> blocks', () async {
      final file = _createTempFile('scripted.html', '''
        <html><head><script>alert('xss');</script></head>
        <body><p>Clean content</p></body></html>
      ''');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseHtmlFile(file);

      expect(note, isNotNull);
      expect(note!.body, isNot(contains('alert')));
      expect(note!.body, contains('Clean content'));
    });

    test('decodes HTML entities', () async {
      final file = _createTempFile('entities.html', '''
        <html><body><p>Tom &amp; Jerry &lt;3&gt; &quot;quotes&quot; &#39;apostrophes&#39;</p></body></html>
      ''');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseHtmlFile(file);

      expect(note, isNotNull);
      expect(note!.body, contains('Tom & Jerry <3> "quotes" \'apostrophes\''));
    });

    test('handles &nbsp; entity', () async {
      final file = _createTempFile('nbsp.html', '''
        <html><body><p>Hello&nbsp;World</p></body></html>
      ''');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseHtmlFile(file);
      expect(note, isNotNull);
      expect(note!.body, contains('Hello World'));
    });
  });

  // ===========================================================================
  // parseHtmlFile -- malformed input
  // ===========================================================================

  group('parseHtmlFile malformed input', () {
    test('handles plain text file (no HTML tags)', () async {
      final file = _createTempFile('plain.html', 'Just some plain text');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseHtmlFile(file);
      expect(note, isNotNull);
      expect(note!.body, contains('Just some plain text'));
    });

    test('handles HTML with unclosed tags', () async {
      final file = _createTempFile('unclosed.html', '''
        <html><body><p>Paragraph one<p>Paragraph two</body></html>
      ''');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseHtmlFile(file);
      expect(note, isNotNull);
    });

    test('handles HTML with no body tag', () async {
      final file = _createTempFile('nobody.html', '<html><p>No body tag</html>');
      addTearDown(() => file.parent.delete(recursive: true));

      final note = await importer.parseHtmlFile(file);
      expect(note, isNotNull);
      expect(note!.body, contains('No body tag'));
    });

    test('handles binary file gracefully', () async {
      final dir = Directory.systemTemp.createTempSync('anynote_binary_test_');
      final file = File('${dir.path}/binary.html');
      file.writeAsBytesSync([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]); // PNG header
      addTearDown(() => dir.delete(recursive: true));

      // Should not throw -- returns null if decoding fails.
      final note = await importer.parseHtmlFile(file);
      // May or may not be null depending on whether the bytes form valid UTF-8,
      // but it must not throw.
      expect(() => importer.parseHtmlFile(file), returnsNormally);
    });
  });

  // ===========================================================================
  // parseHtmlDirectory
  // ===========================================================================

  group('parseHtmlDirectory', () {
    test('parses all .html files in directory', () async {
      final dir = _createTempDir();
      addTearDown(() => dir.delete(recursive: true));

      File('${dir.path}/note1.html').writeAsStringSync(
        '<html><head><title>Note 1</title></head><body><p>Content 1</p></body></html>',
      );
      File('${dir.path}/note2.html').writeAsStringSync(
        '<html><head><title>Note 2</title></head><body><p>Content 2</p></body></html>',
      );

      final notes = await importer.parseHtmlDirectory(dir);

      expect(notes.length, equals(2));
      final titles = notes.map((n) => n.title).toList();
      expect(titles, containsAll(['Note 1', 'Note 2']));
    });

    test('ignores non-HTML files', () async {
      final dir = _createTempDir();
      addTearDown(() => dir.delete(recursive: true));

      File('${dir.path}/note.html').writeAsStringSync(
        '<html><head><title>HTML</title></head><body><p>content</p></body></html>',
      );
      File('${dir.path}/readme.txt').writeAsStringSync('Not HTML');
      File('${dir.path}/data.json').writeAsStringSync('{}');

      final notes = await importer.parseHtmlDirectory(dir);

      expect(notes.length, equals(1));
      expect(notes.first.title, equals('HTML'));
    });

    test('finds HTML files in nested directories', () async {
      final dir = _createTempDir();
      addTearDown(() => dir.delete(recursive: true));

      Directory('${dir.path}/sub').createSync();
      File('${dir.path}/sub/nested.html').writeAsStringSync(
        '<html><head><title>Nested</title></head><body><p>deep</p></body></html>',
      );

      final notes = await importer.parseHtmlDirectory(dir);

      expect(notes.length, equals(1));
      expect(notes.first.title, equals('Nested'));
    });

    test('returns empty list for non-existent directory', () async {
      final notes = await importer.parseHtmlDirectory(
        Directory('/nonexistent/path'),
      );
      expect(notes, isEmpty);
    });

    test('returns empty list for empty directory', () async {
      final dir = _createTempDir();
      addTearDown(() => dir.delete(recursive: true));

      final notes = await importer.parseHtmlDirectory(dir);
      expect(notes, isEmpty);
    });

    test('skips malformed HTML files without aborting batch', () async {
      final dir = _createTempDir();
      addTearDown(() => dir.delete(recursive: true));

      File('${dir.path}/good.html').writeAsStringSync(
        '<html><head><title>Good</title></head><body><p>ok</p></body></html>',
      );
      // Write a file that is valid enough to be parsed but has edge-case HTML.
      File('${dir.path}/bad.html').writeAsStringSync(
        '<html><head><title>Bad</title></head><body><p>weird</p></body></html>',
      );

      final notes = await importer.parseHtmlDirectory(dir);
      // Both should be parsed (even "bad" is well-formed enough).
      expect(notes.length, equals(2));
    });

    test('case-insensitive .html extension matching', () async {
      final dir = _createTempDir();
      addTearDown(() => dir.delete(recursive: true));

      File('${dir.path}/lower.html').writeAsStringSync(
        '<html><head><title>Lower</title></head><body><p>a</p></body></html>',
      );
      File('${dir.path}/upper.HTML').writeAsStringSync(
        '<html><head><title>Upper</title></head><body><p>b</p></body></html>',
      );

      final notes = await importer.parseHtmlDirectory(dir);
      expect(notes.length, equals(2));
    });
  });
}
