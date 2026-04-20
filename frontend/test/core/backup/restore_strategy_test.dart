import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/backup/restore_strategy.dart';

void main() {
  group('ConflictStrategy', () {
    test('has exactly three values', () {
      expect(ConflictStrategy.values.length, 3);
    });

    test('contains skip, overwrite, and keepBoth', () {
      expect(ConflictStrategy.values, contains(ConflictStrategy.skip));
      expect(ConflictStrategy.values, contains(ConflictStrategy.overwrite));
      expect(ConflictStrategy.values, contains(ConflictStrategy.keepBoth));
    });

    test('skip is the first enum value', () {
      expect(ConflictStrategy.values.first, ConflictStrategy.skip);
    });

    test('keepBoth is the last enum value', () {
      expect(ConflictStrategy.values.last, ConflictStrategy.keepBoth);
    });
  });

  group('RestoreResult', () {
    test('default values are zero', () {
      const result = RestoreResult();
      expect(result.restored, 0);
      expect(result.skipped, 0);
      expect(result.conflicts, 0);
      expect(result.errors, isEmpty);
    });

    test('total is sum of restored, skipped, and conflicts', () {
      const result = RestoreResult(
        restored: 5,
        skipped: 2,
        conflicts: 1,
      );
      expect(result.total, 8);
    });

    test('hasErrors returns false when errors is empty', () {
      const result = RestoreResult();
      expect(result.hasErrors, isFalse);
    });

    test('hasErrors returns true when errors is non-empty', () {
      const result = RestoreResult(errors: ['Something went wrong']);
      expect(result.hasErrors, isTrue);
    });

    test('hasErrors returns true for multiple errors', () {
      const result = RestoreResult(errors: ['Error 1', 'Error 2', 'Error 3']);
      expect(result.hasErrors, isTrue);
      expect(result.errors.length, 3);
    });

    test('stores all fields correctly', () {
      const result = RestoreResult(
        restored: 10,
        skipped: 3,
        conflicts: 2,
        errors: ['err'],
      );
      expect(result.restored, 10);
      expect(result.skipped, 3);
      expect(result.conflicts, 2);
      expect(result.errors, ['err']);
      expect(result.total, 15);
    });

    test('toString includes all counts', () {
      const result = RestoreResult(
        restored: 1,
        skipped: 2,
        conflicts: 3,
        errors: ['e'],
      );
      final str = result.toString();
      expect(str, contains('restored: 1'));
      expect(str, contains('skipped: 2'));
      expect(str, contains('conflicts: 3'));
      expect(str, contains('errors: 1'));
    });

    test('total is zero when all counts are zero', () {
      const result = RestoreResult();
      expect(result.total, 0);
    });
  });

  group('RestoreProgress', () {
    test('stores current, total, and step', () {
      const progress = RestoreProgress(
        current: 5,
        total: 10,
        step: 'notes',
      );
      expect(progress.current, 5);
      expect(progress.total, 10);
      expect(progress.step, 'notes');
    });

    test('fraction returns correct ratio', () {
      const progress = RestoreProgress(
        current: 3,
        total: 10,
        step: 'tags',
      );
      expect(progress.fraction, closeTo(0.3, 0.001));
    });

    test('fraction returns 0.5 at halfway', () {
      const progress = RestoreProgress(
        current: 5,
        total: 10,
        step: 'notes',
      );
      expect(progress.fraction, closeTo(0.5, 0.001));
    });

    test('fraction returns 1.0 when complete', () {
      const progress = RestoreProgress(
        current: 10,
        total: 10,
        step: 'collections',
      );
      expect(progress.fraction, closeTo(1.0, 0.001));
    });

    test('fraction returns 0.0 when total is zero', () {
      const progress = RestoreProgress(
        current: 0,
        total: 0,
        step: 'contents',
      );
      expect(progress.fraction, 0.0);
    });

    test('fraction returns 0.0 at the start', () {
      const progress = RestoreProgress(
        current: 0,
        total: 100,
        step: 'notes',
      );
      expect(progress.fraction, 0.0);
    });

    test('step can be any string', () {
      const progress = RestoreProgress(
        current: 1,
        total: 1,
        step: 'custom_step',
      );
      expect(progress.step, 'custom_step');
    });
  });
}
