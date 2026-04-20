import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../routing/app_router.dart';
import '../network/api_client.dart';
import '../monitoring/error_reporter.dart';

/// Background message handler must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for background isolate.
  await Firebase.initializeApp();
  debugPrint('Background push received: ${message.messageId}');
}

/// Provider for the PushNotificationService singleton.
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref.read(apiClientProvider));
});

/// Manages push notification registration, token lifecycle, and message routing.
///
/// Setup requires:
/// 1. Firebase project configured in Firebase Console
/// 2. google-services.json (Android) in android/app/
/// 3. GoogleService-Info.plist (iOS) in ios/Runner/
/// 4. FirebaseOptions registered via Firebase.configure() or generated
///    flutterfire configure output
///
/// Until Firebase is fully configured, this service operates in a graceful
/// no-op mode -- initialization succeeds but no actual push tokens are obtained.
class PushNotificationService {
  final ApiClient _apiClient;
  String? _currentToken;
  bool _initialized = false;

  PushNotificationService(this._apiClient);

  /// Whether the service has been successfully initialized.
  bool get isInitialized => _initialized;

  /// The current FCM device token, or null if not available.
  String? get currentToken => _currentToken;

  /// Initialize push notifications.
  ///
  /// Must be called after the user is authenticated (so the device token
  /// can be registered with the correct user account). If Firebase is not
  /// configured, this completes silently without error.
  Future<void> init() async {
    if (_initialized) return;

    // Push notifications are not supported on web platform.
    if (kIsWeb) {
      debugPrint('Push notifications not supported on web');
      _initialized = true;
      return;
    }

    try {
      // Firebase may not be configured in development builds.
      // Wrap in try/catch so the app continues to work without Firebase.
      if (!Platform.isLinux && !Platform.isWindows) {
        await Firebase.initializeApp();
      } else {
        // Firebase Messaging is not supported on desktop platforms.
        debugPrint('Push notifications not supported on this platform');
        _initialized = true;
        return;
      }
    } catch (e) {
      debugPrint('Firebase not configured, push notifications disabled: $e');
      _initialized = true;
      return;
    }

    final messaging = FirebaseMessaging.instance;

    // Request notification permission (iOS/macOS/web; no-op on Android).
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Push notification permission denied');
      _initialized = true;
      return;
    }

    // Register background message handler.
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Get the initial FCM token and register with the backend.
    try {
      final token = await messaging.getToken();
      if (token != null) {
        _currentToken = token;
        await _registerToken(token);
      }
    } catch (e) {
      debugPrint('Failed to get FCM token: $e');
    }

    // Listen for token refreshes (e.g. when the user reinstalls the app).
    messaging.onTokenRefresh.listen((token) async {
      // Unregister the old token, then register the new one.
      if (_currentToken != null) {
        await _unregisterToken(_currentToken!);
      }
      _currentToken = token;
      await _registerToken(token);
    });

    // Handle messages received while the app is in the foreground.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle messages that opened the app from a background state.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Check if the app was opened from a terminated state via a notification.
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    _initialized = true;
    debugPrint('Push notification service initialized');
  }

  /// Register the device token with the backend.
  Future<void> _registerToken(String token) async {
    try {
      final platform = _detectPlatform();
      await _apiClient.registerDevice(token, platform);
      debugPrint('Device token registered: ${token.substring(0, 8)}...');
    } catch (e) {
      ErrorReporter.instance.reportError(e, StackTrace.current, context: 'push_register');
    }
  }

  /// Unregister the device token from the backend.
  Future<void> _unregisterToken(String token) async {
    try {
      await _apiClient.unregisterDevice(token);
      debugPrint('Device token unregistered');
    } catch (e) {
      ErrorReporter.instance.reportError(e, StackTrace.current, context: 'push_unregister');
    }
  }

  /// Handle a message received while the app is in the foreground.
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground push received: ${message.messageId}');
    _routeNotification(message);
  }

  /// Handle a notification that opened the app.
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('Push opened app: ${message.messageId}');
    _routeNotification(message);
  }

  /// Route a notification to the appropriate screen based on message data.
  ///
  /// Supported data[type] values:
  /// - "sync_conflict": Navigate to the notes list to resolve conflicts.
  /// - "publish_started": Navigate to publish history.
  /// - "publish_completed": Navigate to the published item.
  /// - "share_received": Navigate to the shared note viewer.
  void _routeNotification(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;

    if (type == null) return;

    debugPrint('Notification routed: type=$type, data=$data');

    try {
      switch (type) {
        case 'sync_conflict':
          // Navigate to the notes list so the user can resolve conflicts.
          appRouter.go('/notes');
          break;

        case 'publish_started':
        case 'publish_completed':
          final publishId = data['publish_id'] as String?;
          if (publishId != null) {
            // Navigate to publish history to show the status update.
            appRouter.push('/publish/history');
          }
          break;

        case 'share_received':
          final shareId = data['share_id'] as String?;
          if (shareId != null) {
            // Navigate to the shared note viewer.
            appRouter.push('/share/$shareId');
          }
          break;
      }
    } catch (e) {
      debugPrint('Failed to route notification: $e');
    }
  }

  /// Detect the current platform for device registration.
  String _detectPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'ios'; // macOS uses APNs-like tokens
    return 'web';
  }

  /// Unregister the current device token (call on logout).
  Future<void> dispose() async {
    if (_currentToken != null) {
      await _unregisterToken(_currentToken!);
      _currentToken = null;
    }
    _initialized = false;
  }
}
