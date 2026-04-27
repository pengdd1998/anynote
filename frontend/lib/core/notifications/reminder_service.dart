import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/daos/note_properties_dao.dart';
import '../../main.dart';
import 'local_notification_service.dart';

/// Provider for the ReminderService.
final reminderServiceProvider = Provider<ReminderService>((ref) {
  final db = ref.read(databaseProvider);
  final localNotifications = ref.read(localNotificationServiceProvider);
  final service = ReminderService(db, localNotifications);
  ref.onDispose(service.dispose);
  return service;
});

/// Provider that fetches all upcoming reminders. Refresh every 60 seconds
/// via an internal timer when watched by the UI.
final upcomingRemindersProvider =
    AsyncNotifierProvider<UpcomingRemindersNotifier, List<ReminderEntry>>(
  UpcomingRemindersNotifier.new,
);

/// AsyncNotifier that polls for upcoming reminders every 60 seconds.
class UpcomingRemindersNotifier extends AsyncNotifier<List<ReminderEntry>> {
  Timer? _pollTimer;

  @override
  Future<List<ReminderEntry>> build() async {
    ref.onDispose(() {
      _pollTimer?.cancel();
    });

    final db = ref.read(databaseProvider);
    final reminders = await db.notePropertiesDao.getNotesWithReminders();

    // Start a 60-second polling timer to keep the list fresh.
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      try {
        final updated = await db.notePropertiesDao.getNotesWithReminders();
        state = AsyncData(updated);
      } catch (e) {
        debugPrint('Reminder poll error: $e');
      }
    });

    return reminders;
  }

  /// Force-refresh the reminders list.
  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final db = ref.read(databaseProvider);
      final reminders = await db.notePropertiesDao.getNotesWithReminders();
      state = AsyncData(reminders);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

/// Service that manages note reminders using NoteProperties.
///
/// This service handles scheduling, canceling, and checking reminders.
/// It uses both system-level local notifications (via LocalNotificationService)
/// for background delivery and a polling-based fallback that checks for due
/// reminders every 60 seconds while the app is running.
class ReminderService {
  final AppDatabase _db;
  final LocalNotificationService _localNotifications;
  Timer? _pollTimer;

  /// Callback invoked when a reminder fires. The caller (UI layer) is
  /// responsible for displaying the notification to the user.
  void Function(ReminderEntry reminder)? onReminderFired;

  ReminderService(this._db, this._localNotifications);

  /// Schedule a reminder for a note.
  Future<void> scheduleReminder(
    String noteId,
    DateTime dateTime, {
    String? title,
    String? recurring,
  }) async {
    await _db.notePropertiesDao.setReminder(
      noteId,
      dateTime,
      title: title,
      recurring: recurring,
    );

    // Schedule a system local notification for background delivery.
    final notificationTitle = title ?? 'Reminder';
    final notificationBody = title ?? 'You have a reminder';
    await _localNotifications.scheduleNotification(
      id: noteId.hashCode,
      title: notificationTitle,
      body: notificationBody,
      dateTime: dateTime,
      payload: 'note:$noteId',
      recurring: recurring,
    );
  }

  /// Cancel a reminder for a note.
  Future<void> cancelReminder(String noteId) async {
    await _db.notePropertiesDao.clearReminder(noteId);

    // Cancel the corresponding local notification.
    await _localNotifications.cancelNotification(noteId.hashCode);
  }

  /// Start polling for due reminders. The [onFired] callback is invoked
  /// for each due reminder that has not yet been fired.
  void startPolling({void Function(ReminderEntry reminder)? onFired}) {
    if (onFired != null) {
      onReminderFired = onFired;
    }
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      checkDueReminders();
    });
    // Also check immediately.
    checkDueReminders();
  }

  /// Stop the polling timer.
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Check for due reminders and fire callbacks for each one.
  Future<List<ReminderEntry>> checkDueReminders() async {
    try {
      final due = await _db.notePropertiesDao.getDueReminders();
      for (final reminder in due) {
        await _db.notePropertiesDao.markReminderFired(reminder.noteId);
        onReminderFired?.call(reminder);

        // Show a local notification in case the scheduled one was missed
        // (e.g. the device was rebooted or the app was force-stopped).
        await _localNotifications.showNotification(
          id: reminder.noteId.hashCode,
          title: reminder.displayTitle,
          body: reminder.displayTitle,
          payload: 'note:${reminder.noteId}',
        );

        // Handle recurring reminders: schedule the next occurrence.
        if (reminder.isRecurring) {
          await _scheduleNextRecurrence(reminder);
        }
      }
      return due;
    } catch (e) {
      debugPrint('Error checking due reminders: $e');
      return [];
    }
  }

  /// Schedule the next occurrence of a recurring reminder.
  Future<void> _scheduleNextRecurrence(ReminderEntry reminder) async {
    final nextDate = _nextOccurrence(reminder.reminderAt, reminder.recurring);
    if (nextDate != null) {
      await _db.notePropertiesDao.setReminder(
        reminder.noteId,
        nextDate,
        title: reminder.reminderTitle,
        recurring: reminder.recurring,
      );

      // Schedule a local notification for the next occurrence.
      await _localNotifications.scheduleNotification(
        id: reminder.noteId.hashCode,
        title: reminder.displayTitle,
        body: reminder.displayTitle,
        dateTime: nextDate,
        payload: 'note:${reminder.noteId}',
        recurring: reminder.recurring,
      );
    }
  }

  /// Calculate the next occurrence based on the recurring pattern.
  DateTime? _nextOccurrence(DateTime current, String recurring) {
    switch (recurring) {
      case 'daily':
        return current.add(const Duration(days: 1));
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(
          current.year,
          current.month + 1,
          current.day,
          current.hour,
          current.minute,
        );
      default:
        return null;
    }
  }

  /// Get all notes with reminders (both past and future).
  Future<List<ReminderEntry>> getAllReminders() async {
    return _db.notePropertiesDao.getNotesWithReminders();
  }

  /// Get the reminder for a specific note, or null if none set.
  Future<ReminderEntry?> getReminderForNote(String noteId) async {
    final prop = await _db.notePropertiesDao.getProperty(noteId, 'reminder_at');
    if (prop == null || prop.valueText == null) return null;

    final titleProp =
        await _db.notePropertiesDao.getProperty(noteId, 'reminder_title');
    final recurProp =
        await _db.notePropertiesDao.getProperty(noteId, 'reminder_recurring');

    return ReminderEntry(
      noteId: noteId,
      plainTitle: null,
      reminderAt: DateTime.parse(prop.valueText!),
      reminderTitle: titleProp?.valueText,
      recurring: recurProp?.valueText ?? 'none',
    );
  }

  /// Watch the reminder for a specific note reactively.
  Stream<ReminderEntry?> watchReminderForNote(String noteId) {
    return _db.notePropertiesDao.watchReminderForNote(noteId);
  }

  /// Dispose of resources.
  void dispose() {
    stopPolling();
  }
}
