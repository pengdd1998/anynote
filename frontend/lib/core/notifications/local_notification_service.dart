import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../platform/platform_utils.dart';
import '../../routing/app_router.dart';

/// Callback type for notification tap events.
typedef OnNotificationTap = void Function(String? payload);

/// Provider for the LocalNotificationService singleton.
final localNotificationServiceProvider =
    Provider<LocalNotificationService>((ref) {
  return LocalNotificationService();
});

/// Service that schedules system-level local notifications using
/// flutter_local_notifications.
///
/// On web and desktop platforms (Linux/Windows/macOS) this service operates in
/// graceful no-op mode because the plugin does not support those platforms.
class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  OnNotificationTap? _onTap;

  /// Whether the service has been successfully initialized.
  bool get isInitialized => _initialized;

  /// Returns true on platforms that support local notifications (Android, iOS).
  bool get _isSupported {
    return !kIsWeb && (PlatformUtils.isMobile);
  }

  /// Initialize the flutter_local_notifications plugin with platform-specific
  /// configuration. Safe to call on all platforms -- returns immediately on
  /// web/desktop.
  Future<void> init() async {
    if (_initialized) return;
    if (!_isSupported) {
      debugPrint('Local notifications not supported on this platform');
      _initialized = true;
      return;
    }

    try {
      // Initialize timezone database for scheduled notifications.
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(DateTime.now().timeZoneName));

      // Android configuration.
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS settings: request alert, badge, and sound permissions.
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );

      // Create the notification channel explicitly for Android 8.0+ (API 26).
      // While flutter_local_notifications may auto-create it, explicit creation
      // is more robust and prevents silent notification failures.
      if (PlatformUtils.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin
            ?.createNotificationChannel(const AndroidNotificationChannel(
          'note_reminders',
          'Note Reminders',
          description: 'Notifications for note reminders',
          importance: Importance.high,
        ));
      }

      _initialized = true;
      debugPrint('Local notification service initialized');
    } catch (e) {
      debugPrint('Failed to initialize local notifications: $e');
      // Mark as initialized so we don't retry on every schedule call.
      _initialized = true;
    }
  }

  /// Handle a notification tap by routing to the appropriate screen.
  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    _onTap?.call(payload);

    // Default behavior: navigate to the note referenced in the payload.
    if (payload.startsWith('note:')) {
      final noteId = payload.substring(5);
      try {
        appRouter.push('/notes/$noteId');
      } catch (e) {
        debugPrint('Failed to navigate to note from notification: $e');
      }
    }
  }

  /// Set a callback for when a notification is tapped.
  void setOnNotificationTap(OnNotificationTap onTap) {
    _onTap = onTap;
  }

  /// Request notification permissions. Required on Android 13+ and iOS.
  /// Returns true if permissions were granted.
  Future<bool> requestPermissions() async {
    if (!_initialized || !_isSupported) return false;

    try {
      if (PlatformUtils.isIOS) {
        final result = await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        return result ?? false;
      }

      if (PlatformUtils.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        // requestNotificationsPermission is only available on Android 13+.
        // On older versions it returns true (permission is granted by default).
        final result = await androidPlugin?.requestNotificationsPermission();
        return result ?? false;
      }
    } catch (e) {
      debugPrint('Failed to request notification permissions: $e');
    }
    return false;
  }

  /// Schedule a local notification for a specific [dateTime].
  ///
  /// [id] is used as the notification ID -- use the noteId hash to keep IDs
  /// unique per note while fitting into a 32-bit int.
  /// [title] is the notification title.
  /// [body] is the notification body text.
  /// [payload] is an optional payload string (e.g. 'note:<noteId>').
  /// [recurring] can be 'daily', 'weekly', or 'monthly' for repeating
  /// notifications. Use null or 'none' for one-shot.
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
    String? payload,
    String? recurring,
  }) async {
    if (!_initialized || !_isSupported) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'note_reminders',
        'Note Reminders',
        channelDescription: 'Notifications for note reminders',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final scheduledDate = tz.TZDateTime.from(
        dateTime,
        tz.local,
      );

      if (recurring != null && recurring != 'none') {
        await _scheduleRecurring(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          platformDetails: platformDetails,
          payload: payload,
          recurring: recurring,
        );
      } else {
        // One-shot scheduled notification.
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          platformDetails,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
      debugPrint(
        'Scheduled notification $id for $dateTime (recurring: $recurring)',
      );
    } catch (e) {
      debugPrint('Failed to schedule notification: $e');
    }
  }

  /// Schedule a recurring notification.
  Future<void> _scheduleRecurring({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails platformDetails,
    required String recurring,
    String? payload,
  }) async {
    switch (recurring) {
      case 'daily':
        // Repeat daily at the same time.
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          platformDetails,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        break;

      case 'weekly':
        // Repeat weekly on the same day-of-week and time.
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          platformDetails,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
        break;

      case 'monthly':
        // flutter_local_notifications does not have a monthly component match,
        // so we schedule it as a one-shot and the polling fallback in
        // ReminderService will reschedule it when it fires.
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          platformDetails,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        break;
    }
  }

  /// Cancel a previously scheduled notification by its [id].
  Future<void> cancelNotification(int id) async {
    if (!_initialized || !_isSupported) return;

    try {
      await _plugin.cancel(id);
      debugPrint('Cancelled notification $id');
    } catch (e) {
      debugPrint('Failed to cancel notification $id: $e');
    }
  }

  /// Cancel all pending notifications.
  Future<void> cancelAllNotifications() async {
    if (!_initialized || !_isSupported) return;

    try {
      await _plugin.cancelAll();
      debugPrint('Cancelled all notifications');
    } catch (e) {
      debugPrint('Failed to cancel all notifications: $e');
    }
  }

  /// Show an immediate notification (used by the polling fallback when a
  /// reminder fires while the app is in the foreground).
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized || !_isSupported) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'note_reminders',
        'Note Reminders',
        channelDescription: 'Notifications for note reminders',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.show(id, title, body, platformDetails, payload: payload);
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }
}
