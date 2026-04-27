import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/daos/note_properties_dao.dart';
import 'package:anynote/core/notifications/reminder_service.dart';
import 'package:anynote/features/notes/presentation/reminders_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('RemindersScreen', () {
    testWidgets('shows empty state when no reminders', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const RemindersScreen(),
        overrides: [
          ...defaultProviderOverrides(db: db),
          upcomingRemindersProvider
              .overrideWith(() => _FakeUpcomingRemindersNotifier([])),
        ],
      );
      addTearDown(() => handle.dispose());

      // Empty state shows notifications_none_outlined icon.
      expect(find.byIcon(Icons.notifications_none_outlined), findsOneWidget);
      expect(find.text('No Reminders'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('renders list of reminders', (tester) async {
      final now = DateTime.now();
      final reminders = [
        ReminderEntry(
          noteId: 'note-1',
          plainTitle: 'Buy groceries',
          reminderAt: now.add(const Duration(hours: 2)),
          recurring: 'none',
        ),
        ReminderEntry(
          noteId: 'note-2',
          plainTitle: 'Meeting prep',
          reminderAt: now.add(const Duration(days: 1)),
          reminderTitle: 'Team standup',
          recurring: 'daily',
        ),
      ];

      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const RemindersScreen(),
        overrides: [
          ...defaultProviderOverrides(db: db),
          upcomingRemindersProvider.overrideWith(
            () => _FakeUpcomingRemindersNotifier(reminders),
          ),
        ],
      );
      addTearDown(() => handle.dispose());

      // Both reminder titles should be visible.
      expect(find.text('Buy groceries'), findsOneWidget);
      expect(find.text('Team standup'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows overdue icon for past reminders', (tester) async {
      final pastReminder = ReminderEntry(
        noteId: 'note-3',
        plainTitle: 'Overdue task',
        reminderAt: DateTime(2020, 1, 1),
        recurring: 'none',
      );

      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const RemindersScreen(),
        overrides: [
          ...defaultProviderOverrides(db: db),
          upcomingRemindersProvider.overrideWith(
            () => _FakeUpcomingRemindersNotifier([pastReminder]),
          ),
        ],
      );
      addTearDown(() => handle.dispose());

      // Overdue reminders should show notifications_active icon.
      expect(find.byIcon(Icons.notifications_active), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows recurring icon for recurring reminders', (tester) async {
      final now = DateTime.now();
      final recurringReminder = ReminderEntry(
        noteId: 'note-4',
        plainTitle: 'Daily standup',
        reminderAt: now.add(const Duration(hours: 1)),
        recurring: 'daily',
      );

      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const RemindersScreen(),
        overrides: [
          ...defaultProviderOverrides(db: db),
          upcomingRemindersProvider.overrideWith(
            () => _FakeUpcomingRemindersNotifier([recurringReminder]),
          ),
        ],
      );
      addTearDown(() => handle.dispose());

      // Recurring reminders should show the repeat icon.
      expect(find.byIcon(Icons.repeat), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows Scaffold and AppBar', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const RemindersScreen(),
        overrides: [
          ...defaultProviderOverrides(db: db),
          upcomingRemindersProvider
              .overrideWith(() => _FakeUpcomingRemindersNotifier([])),
        ],
      );
      addTearDown(() => handle.dispose());

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      await handle.dispose();
    });
  });
}

// ---------------------------------------------------------------------------
// Fake notifier subclass
// ---------------------------------------------------------------------------

/// A fake UpcomingRemindersNotifier that returns a fixed list of reminders.
class _FakeUpcomingRemindersNotifier extends UpcomingRemindersNotifier {
  final List<ReminderEntry> _reminders;

  _FakeUpcomingRemindersNotifier(this._reminders);

  @override
  Future<List<ReminderEntry>> build() async => _reminders;

  @override
  Future<void> refresh() async {
    state = AsyncData(_reminders);
  }
}
