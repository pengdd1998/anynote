import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/import/import_models.dart';

void main() {
  // ===========================================================================
  // ImportedNote
  // ===========================================================================

  group('ImportedNote', () {
    test('creates with required fields', () {
      final note = ImportedNote(
        title: 'My Note',
        body: '# Hello\nWorld',
        tags: ['dart', 'flutter'],
        createdAt: DateTime(2024, 1, 15),
        sourcePath: '/home/user/notes/my_note.md',
      );

      expect(note.title, 'My Note');
      expect(note.body, '# Hello\nWorld');
      expect(note.tags, ['dart', 'flutter']);
      expect(note.createdAt, DateTime(2024, 1, 15));
      expect(note.sourcePath, '/home/user/notes/my_note.md');
    });

    test('accepts empty tags list', () {
      final note = ImportedNote(
        title: 'No Tags',
        body: 'content',
        tags: [],
        createdAt: DateTime(2024),
        sourcePath: '/path/note.md',
      );

      expect(note.tags, isEmpty);
    });

    test('accepts empty body', () {
      final note = ImportedNote(
        title: 'Empty',
        body: '',
        tags: [],
        createdAt: DateTime(2024),
        sourcePath: '/path/empty.md',
      );

      expect(note.body, isEmpty);
    });

    test('const constructor works', () {
      final note = ImportedNote(
        title: 'Const',
        body: 'body',
        tags: ['t'],
        createdAt: DateTime(2024),
        sourcePath: '/p.md',
      );

      expect(note.title, 'Const');
    });

    test('stores tags in the provided order', () {
      final note = ImportedNote(
        title: 'Ordered Tags',
        body: 'body',
        tags: ['alpha', 'beta', 'gamma'],
        createdAt: DateTime(2024),
        sourcePath: '/p.md',
      );

      expect(note.tags[0], 'alpha');
      expect(note.tags[1], 'beta');
      expect(note.tags[2], 'gamma');
    });
  });

  // ===========================================================================
  // ImportStatus
  // ===========================================================================

  group('ImportStatus', () {
    test('has four enum values', () {
      expect(ImportStatus.values.length, 4);
    });

    test('contains parsing status', () {
      expect(ImportStatus.values, contains(ImportStatus.parsing));
    });

    test('contains importing status', () {
      expect(ImportStatus.values, contains(ImportStatus.importing));
    });

    test('contains done status', () {
      expect(ImportStatus.values, contains(ImportStatus.done));
    });

    test('contains failed status', () {
      expect(ImportStatus.values, contains(ImportStatus.failed));
    });
  });

  // ===========================================================================
  // ImportProgress
  // ===========================================================================

  group('ImportProgress', () {
    test('creates with required fields', () {
      const progress = ImportProgress(
        current: 5,
        total: 10,
        currentFile: 'note_5.md',
        status: ImportStatus.parsing,
      );

      expect(progress.current, 5);
      expect(progress.total, 10);
      expect(progress.currentFile, 'note_5.md');
      expect(progress.status, ImportStatus.parsing);
    });

    test('progress calculates correct ratio at midpoint', () {
      const progress = ImportProgress(
        current: 5,
        total: 10,
        currentFile: 'mid.md',
        status: ImportStatus.importing,
      );

      expect(progress.progress, closeTo(0.5, 0.001));
    });

    test('progress is 0 at start', () {
      const progress = ImportProgress(
        current: 0,
        total: 10,
        currentFile: 'start.md',
        status: ImportStatus.parsing,
      );

      expect(progress.progress, 0.0);
    });

    test('progress is 1.0 when complete', () {
      const progress = ImportProgress(
        current: 10,
        total: 10,
        currentFile: 'last.md',
        status: ImportStatus.done,
      );

      expect(progress.progress, 1.0);
    });

    test('progress is 0 when total is 0 (avoids division by zero)', () {
      const progress = ImportProgress(
        current: 0,
        total: 0,
        currentFile: '',
        status: ImportStatus.parsing,
      );

      expect(progress.progress, 0.0);
    });

    test('progress handles single file', () {
      const progress = ImportProgress(
        current: 0,
        total: 1,
        currentFile: 'only.md',
        status: ImportStatus.importing,
      );

      expect(progress.progress, 0.0);

      const done = ImportProgress(
        current: 1,
        total: 1,
        currentFile: 'only.md',
        status: ImportStatus.done,
      );

      expect(done.progress, 1.0);
    });

    test('progress handles large totals', () {
      const progress = ImportProgress(
        current: 500,
        total: 1000,
        currentFile: 'file_500.md',
        status: ImportStatus.importing,
      );

      expect(progress.progress, closeTo(0.5, 0.001));
    });

    test('const constructor works', () {
      const progress = ImportProgress(
        current: 0,
        total: 1,
        currentFile: 'test.md',
        status: ImportStatus.parsing,
      );

      expect(progress.current, 0);
    });
  });

  // ===========================================================================
  // ImportResult
  // ===========================================================================

  group('ImportResult', () {
    test('creates with required fields', () {
      const result = ImportResult(
        importedCount: 10,
        skippedCount: 2,
      );

      expect(result.importedCount, 10);
      expect(result.skippedCount, 2);
      expect(result.errors, isEmpty);
    });

    test('hasErrors is false when no errors', () {
      const result = ImportResult(
        importedCount: 5,
        skippedCount: 0,
      );

      expect(result.hasErrors, isFalse);
    });

    test('hasErrors is true when errors exist', () {
      const result = ImportResult(
        importedCount: 4,
        skippedCount: 1,
        errors: [
          ImportError(
            filePath: '/bad.md',
            message: 'Unreadable encoding',
          ),
        ],
      );

      expect(result.hasErrors, isTrue);
    });

    test('default errors list is empty', () {
      const result = ImportResult(importedCount: 3, skippedCount: 0);

      expect(result.errors, isEmpty);
    });

    test('stores multiple errors', () {
      const result = ImportResult(
        importedCount: 3,
        skippedCount: 0,
        errors: [
          ImportError(filePath: '/a.md', message: 'error a'),
          ImportError(filePath: '/b.md', message: 'error b'),
          ImportError(filePath: '/c.md', message: 'error c'),
        ],
      );

      expect(result.errors.length, 3);
      expect(result.errors[0].filePath, '/a.md');
      expect(result.errors[1].message, 'error b');
    });

    test('zero counts are valid', () {
      const result = ImportResult(importedCount: 0, skippedCount: 0);

      expect(result.importedCount, 0);
      expect(result.skippedCount, 0);
      expect(result.hasErrors, isFalse);
    });

    test('const constructor works', () {
      const result = ImportResult(importedCount: 0, skippedCount: 0);

      expect(result.importedCount, 0);
    });
  });

  // ===========================================================================
  // ImportError
  // ===========================================================================

  group('ImportError', () {
    test('creates with required fields', () {
      const error = ImportError(
        filePath: '/home/user/notes/broken.md',
        message: 'Invalid UTF-8 encoding',
      );

      expect(error.filePath, '/home/user/notes/broken.md');
      expect(error.message, 'Invalid UTF-8 encoding');
    });

    test('const constructor works', () {
      const error = ImportError(filePath: '/p.md', message: 'msg');

      expect(error.filePath, '/p.md');
    });

    test('accepts various file paths', () {
      const error = ImportError(
        filePath: 'C:\\Users\\docs\\note.md',
        message: 'Windows path',
      );

      expect(error.filePath, 'C:\\Users\\docs\\note.md');
    });

    test('accepts long error messages', () {
      const message = 'A very long error message that describes in detail '
          'what went wrong during the import process for this specific file. '
          'It could include stack traces, encoding issues, or format problems.';
      const error = ImportError(filePath: '/f.md', message: message);

      expect(error.message, message);
    });
  });
}
