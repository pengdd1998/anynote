// Tests for MarkdownExportService static methods and parseYamlFrontmatter.
//
// Tests cover:
// - sanitizeFilename strips special characters, preserves safe ones
// - generateFrontmatter with tags, properties, pinned status
// - generateFrontmatter returns empty when no metadata and forceInclude=false
// - generateFrontmatter with forceInclude=true always returns frontmatter
// - noteToMarkdown assembles frontmatter + heading + content
// - noteToMarkdown with includeFrontmatter=false omits frontmatter
// - noteToMarkdown ensures trailing newline
// - parseYamlFrontmatter extracts valid frontmatter and body
// - parseYamlFrontmatter with no frontmatter
// - parseYamlFrontmatter with list values
// - parseYamlFrontmatter with quoted values
//
// Only tests pure static methods -- no file I/O.

import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/features/notes/domain/markdown_export_service.dart';

// ---------------------------------------------------------------------------
// Helpers to create minimal Drift dataclass instances for testing.
// ---------------------------------------------------------------------------

Note _makeNote({
  String id = 'test-note-id-12345678',
  bool isPinned = false,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final now = DateTime(2026, 4, 26, 12, 0, 0);
  return Note(
    id: id,
    encryptedContent: '',
    encryptedTitle: null,
    version: 1,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    deletedAt: null,
    isSynced: true,
    isPinned: isPinned,
    plainContent: null,
    plainTitle: null,
    color: null,
    sortOrder: 0,
  );
}

Tag _makeTag(String plainName, {String id = 'tag-1'}) {
  return Tag(
    id: id,
    encryptedName: '',
    plainName: plainName,
    color: null,
    parentId: null,
    version: 1,
    isSynced: false,
  );
}

NoteProperty _makeProperty({
  required String key,
  required String valueType,
  String? valueText,
  double? valueNumber,
  DateTime? valueDate,
}) {
  final now = DateTime(2026, 4, 26);
  return NoteProperty(
    id: 'prop-1',
    noteId: 'note-1',
    key: key,
    valueType: valueType,
    valueText: valueText,
    valueNumber: valueNumber,
    valueDate: valueDate,
    createdAt: now,
    updatedAt: now,
  );
}

ExportableNote _makeExportable({
  String title = 'Test Note',
  String content = 'Some content here.',
  List<Tag> tags = const [],
  List<NoteProperty> properties = const [],
  bool isPinned = false,
}) {
  return ExportableNote(
    note: _makeNote(isPinned: isPinned),
    title: title,
    content: content,
    tags: tags,
    properties: properties,
  );
}

void main() {
  group('MarkdownExportService.sanitizeFilename', () {
    test('removes characters not safe for filenames', () {
      expect(
        MarkdownExportService.sanitizeFilename('my<file>name:test/path|here?*'),
        equals('myfilenametestpathhere'),
      );
    });

    test('preserves safe characters including spaces and hyphens', () {
      const input = 'Hello World - Note (v2).txt';
      expect(MarkdownExportService.sanitizeFilename(input), equals(input));
    });

    test('removes control characters (0x00-0x1f)', () {
      const withControl = 'hello\x00world\x01test\x1f';
      expect(
        MarkdownExportService.sanitizeFilename(withControl),
        equals('helloworldtest'),
      );
    });

    test('trims leading and trailing whitespace', () {
      expect(
        MarkdownExportService.sanitizeFilename('  my note  '),
        equals('my note'),
      );
    });

    test('empty string after sanitization returns empty', () {
      expect(MarkdownExportService.sanitizeFilename(''), isEmpty);
    });
  });

  group('MarkdownExportService.generateFrontmatter', () {
    test('returns empty string when no metadata and forceInclude=false', () {
      final exportable = _makeExportable();
      final result = MarkdownExportService.generateFrontmatter(exportable);
      expect(result, isEmpty);
    });

    test('returns frontmatter with forceInclude=true even without metadata',
        () {
      final exportable = _makeExportable();
      final result = MarkdownExportService.generateFrontmatter(
        exportable,
        forceInclude: true,
      );

      expect(result, isNotEmpty);
      expect(result.startsWith('---\n'), isTrue);
      expect(result, contains('title:'));
      expect(result, contains('created:'));
      expect(result, contains('updated:'));
      expect(result, contains('id:'));
    });

    test('includes tags in frontmatter', () {
      final exportable = _makeExportable(
        tags: [_makeTag('work'), _makeTag('important', id: 'tag-2')],
      );
      final result = MarkdownExportService.generateFrontmatter(exportable);

      expect(result, contains('tags:'));
      expect(result, contains('  - work'));
      expect(result, contains('  - important'));
    });

    test('includes properties in frontmatter', () {
      final exportable = _makeExportable(
        properties: [
          _makeProperty(key: 'status', valueType: 'text', valueText: 'Todo'),
        ],
      );
      final result = MarkdownExportService.generateFrontmatter(exportable);

      expect(result, contains('status: Todo'));
    });

    test('includes pinned: true for pinned notes', () {
      final exportable = _makeExportable(isPinned: true);
      final result = MarkdownExportService.generateFrontmatter(exportable);

      expect(result, contains('pinned: true'));
    });

    test('number property renders as numeric string', () {
      final exportable = _makeExportable(
        properties: [
          _makeProperty(
              key: 'priority_level', valueType: 'number', valueNumber: 42.5,),
        ],
      );
      final result = MarkdownExportService.generateFrontmatter(exportable);

      expect(result, contains('priority_level: 42.5'));
    });

    test('date property renders as YYYY-MM-DD', () {
      final exportable = _makeExportable(
        properties: [
          _makeProperty(
            key: 'due_date',
            valueType: 'date',
            valueDate: DateTime(2026, 3, 15),
          ),
        ],
      );
      final result = MarkdownExportService.generateFrontmatter(exportable);

      expect(result, contains('due_date: 2026-03-15'));
    });

    test('YAML-quotes values with special characters', () {
      final exportable = _makeExportable(
        title: 'Note: A "Special" Title',
      );
      final result = MarkdownExportService.generateFrontmatter(
        exportable,
        forceInclude: true,
      );

      // Title contains colons and quotes, so it should be wrapped.
      expect(result, contains('"Note: A \\"Special\\" Title"'));
    });
  });

  group('MarkdownExportService.noteToMarkdown', () {
    test('assembles frontmatter + heading + content', () {
      final exportable = _makeExportable(
        title: 'My Note',
        content: 'Body text.',
        tags: [_makeTag('test')],
      );
      final md = MarkdownExportService.noteToMarkdown(exportable);

      expect(md, startsWith('---\n'));
      expect(md, contains('tags:'));
      expect(md, contains('# My Note'));
      expect(md, contains('Body text.'));
    });

    test('with includeFrontmatter=false omits frontmatter', () {
      final exportable = _makeExportable(
        title: 'Plain Note',
        content: 'Just content.',
      );
      final md = MarkdownExportService.noteToMarkdown(
        exportable,
        includeFrontmatter: false,
      );

      expect(md, isNot(contains('---')));
      expect(md, startsWith('# Plain Note'));
      expect(md, contains('Just content.'));
    });

    test('ensures trailing newline', () {
      // Content without trailing newline.
      final exportable = _makeExportable(content: 'no trailing newline');
      final md = MarkdownExportService.noteToMarkdown(exportable);

      expect(md.endsWith('\n'), isTrue);
    });

    test('does not add extra newline when content already has one', () {
      final exportable = _makeExportable(content: 'has newline\n');
      final md = MarkdownExportService.noteToMarkdown(exportable);

      // Should end with exactly one newline (the content already provides it).
      expect(md.endsWith('\n'), isTrue);
      // Should not end with double newline.
      expect(md.endsWith('\n\n'), isFalse);
    });
  });

  group('parseYamlFrontmatter', () {
    test('extracts valid frontmatter and body', () {
      const input = '---\ntitle: Hello\n---\n\nBody text here.';
      final result = parseYamlFrontmatter(input);

      expect(result.frontmatter['title'], equals('Hello'));
      expect(result.body, equals('\nBody text here.'));
    });

    test('returns empty map and full body when no frontmatter', () {
      const input = 'Just some markdown\nwith no frontmatter.';
      final result = parseYamlFrontmatter(input);

      expect(result.frontmatter, isEmpty);
      expect(result.body, equals(input));
    });

    test('parses list values (indented)', () {
      const input = '---\ntags:\n  - work\n  - personal\n---\nBody.';
      final result = parseYamlFrontmatter(input);

      final tags = result.frontmatter['tags'] as List;
      expect(tags, containsAll(['work', 'personal']));
      expect(result.body, equals('Body.'));
    });

    test('parses quoted values by stripping surrounding quotes', () {
      const input = '---\ntitle: "My Note"\n---\nContent.';
      final result = parseYamlFrontmatter(input);

      expect(result.frontmatter['title'], equals('My Note'));
    });

    test('parses single-quoted values', () {
      const input = "---\ntitle: 'Another Note'\n---\nContent.";
      final result = parseYamlFrontmatter(input);

      expect(result.frontmatter['title'], equals('Another Note'));
    });

    test('returns empty map for unclosed frontmatter', () {
      const input = '---\ntitle: Hello\nno closing delimiter';
      final result = parseYamlFrontmatter(input);

      expect(result.frontmatter, isEmpty);
      expect(result.body, equals(input));
    });

    test('handles inline YAML list syntax', () {
      const input = '---\ntags: [work, personal]\n---\nBody.';
      final result = parseYamlFrontmatter(input);

      final tags = result.frontmatter['tags'] as List;
      expect(tags, containsAll(['work', 'personal']));
    });

    test('handles numeric and boolean-like values as strings', () {
      const input = '---\ncount: 42\nactive: true\n---\nBody.';
      final result = parseYamlFrontmatter(input);

      // Values are stored as strings (the parser uses _stripQuotes).
      expect(result.frontmatter['count'], equals('42'));
      expect(result.frontmatter['active'], equals('true'));
    });
  });
}
