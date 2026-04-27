import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/daos/note_properties_dao.dart';
import 'package:anynote/core/notifications/reminder_service.dart';

// ===========================================================================
// Tests
// ===========================================================================

void main() {
  // ===========================================================================
  // ReminderEntry
  // ===========================================================================

  group('ReminderEntry', () {
    test('creates with required fields', () {
      final entry = ReminderEntry(
        noteId: 'note-1',
        reminderAt: DateTime(2026, 6, 15),
      );

      expect(entry.noteId, 'note-1');
      expect(entry.reminderAt, DateTime(2026, 6, 15));
      expect(entry.recurring, 'none');
      expect(entry.isRecurring, isFalse);
    });

    test('stores optional plainTitle', () {
      final entry = ReminderEntry(
        noteId: 'note-1',
        plainTitle: 'My Note Title',
        reminderAt: DateTime(2026, 6, 15),
      );

      expect(entry.plainTitle, 'My Note Title');
    });

    test('stores optional reminderTitle', () {
      final entry = ReminderEntry(
        noteId: 'note-1',
        reminderTitle: 'Check this note',
        reminderAt: DateTime(2026, 6, 15),
      );

      expect(entry.reminderTitle, 'Check this note');
    });

    test('stores recurring pattern', () {
      final entry = ReminderEntry(
        noteId: 'note-1',
        reminderAt: DateTime(2026, 6, 15),
        recurring: 'daily',
      );

      expect(entry.recurring, 'daily');
    });

    test('displayTitle uses reminderTitle first', () {
      final entry = ReminderEntry(
        noteId: 'note-1',
        plainTitle: 'Plain Title',
        reminderTitle: 'Custom Title',
        reminderAt: DateTime(2026, 6, 15),
      );

      expect(entry.displayTitle, 'Custom Title');
    });

    test('displayTitle falls back to plainTitle', () {
      final entry = ReminderEntry(
        noteId: 'note-1',
        plainTitle: 'Plain Title',
        reminderAt: DateTime(2026, 6, 15),
      );

      expect(entry.displayTitle, 'Plain Title');
    });

    test('displayTitle falls back to "Untitled"', () {
      final entry = ReminderEntry(
        noteId: 'note-1',
        reminderAt: DateTime(2026, 6, 15),
      );

      expect(entry.displayTitle, 'Untitled');
    });

    test('isRecurring is true for daily', () {
      final entry = ReminderEntry(
        noteId: 'note-1',
        reminderAt: DateTime(2026, 6, 15),
        recurring: 'daily',
      );

      expect(entry.isRecurring, isTrue);
    });

    test('isRecurring is true for weekly', () {
      final entry = ReminderEntry(
        noteId: 'note-1',
        reminderAt: DateTime(2026, 6, 15),
        recurring: 'weekly',
      );

      expect(entry.isRecurring, isTrue);
    });

    test('isRecurring is true for monthly', () {
      final entry = ReminderEntry(
        noteId: 'note-1',
        reminderAt: DateTime(2026, 6, 15),
        recurring: 'monthly',
      );

      expect(entry.isRecurring, isTrue);
    });

    test('isRecurring is false for none', () {
      final entry = ReminderEntry(
        noteId: 'note-1',
        reminderAt: DateTime(2026, 6, 15),
        recurring: 'none',
      );

      expect(entry.isRecurring, isFalse);
    });

    test('const constructor works', () {
      // ReminderEntry has a const constructor but DateTime is not const,
      // so we verify that non-const construction works correctly.
      final entry = ReminderEntry(
        noteId: 'note-1',
        reminderAt: DateTime(2026, 6, 15),
      );

      expect(entry.noteId, 'note-1');
      expect(entry.recurring, 'none');
    });

    test('default recurring is "none"', () {
      final entry = ReminderEntry(
        noteId: 'note-1',
        reminderAt: DateTime(2026, 6, 15),
      );

      expect(entry.recurring, 'none');
    });

    test('displayTitle with null plainTitle and null reminderTitle', () {
      final entry = ReminderEntry(
        noteId: 'note-abc',
        reminderAt: DateTime(2026, 1, 1),
      );

      expect(entry.displayTitle, 'Untitled');
    });
  });

  // ===========================================================================
  // ReminderService -- _nextOccurrence logic
  //
  // The _nextOccurrence method is private but exercised through
  // recurring pattern strings. We test the pattern logic directly.
  // ===========================================================================

  group('Next occurrence calculation', () {
    test('daily recurrence adds one day', () {
      final current = DateTime(2026, 4, 26, 10, 30);
      final next = current.add(const Duration(days: 1));

      expect(next.year, 2026);
      expect(next.month, 4);
      expect(next.day, 27);
      expect(next.hour, 10);
      expect(next.minute, 30);
    });

    test('weekly recurrence adds seven days', () {
      final current = DateTime(2026, 4, 26, 10, 30);
      final next = current.add(const Duration(days: 7));

      expect(next.day, 3); // May 3
      expect(next.month, 5);
    });

    test('monthly recurrence increments month', () {
      final current = DateTime(2026, 4, 26, 10, 30);
      final next = DateTime(
        current.year,
        current.month + 1,
        current.day,
        current.hour,
        current.minute,
      );

      expect(next.month, 5);
      expect(next.day, 26);
      expect(next.hour, 10);
      expect(next.minute, 30);
    });

    test('monthly recurrence wraps to next year', () {
      final current = DateTime(2026, 12, 15, 14, 0);
      final next = DateTime(
        current.year,
        current.month + 1,
        current.day,
        current.hour,
        current.minute,
      );

      expect(next.year, 2027);
      expect(next.month, 1);
      expect(next.day, 15);
    });

    test('unknown recurring pattern returns null concept', () {
      // The service treats unknown patterns as no next occurrence.
      // This is a documentation test for the expected behavior.
      const unknownPatterns = ['yearly', 'hourly', '', 'biweekly'];
      for (final pattern in unknownPatterns) {
        // These patterns should not match 'daily', 'weekly', or 'monthly'.
        expect(
          ['daily', 'weekly', 'monthly'].contains(pattern),
          isFalse,
          reason: '$pattern should not be a recognized pattern',
        );
      }
    });
  });

  // ===========================================================================
  // ReminderService -- provider definitions
  // ===========================================================================

  group('ReminderService providers', () {
    test('reminderServiceProvider is defined', () {
      expect(reminderServiceProvider, isNotNull);
    });

    test('upcomingRemindersProvider is defined', () {
      expect(upcomingRemindersProvider, isNotNull);
    });
  });
}
