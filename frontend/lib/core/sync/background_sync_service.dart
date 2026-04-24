import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../platform/platform_utils.dart';

/// Background sync callback dispatcher for WorkManager.
///
/// Must be a top-level function so it can be resolved by the platform
/// plugin when the app is launched in the background.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (kDebugMode) {
      debugPrint('Background sync task: $task');
    }
    // Perform a lightweight pull-only sync.
    // We cannot use Riverpod providers here since this runs in a
    // separate isolate. Instead, we do a direct API call.
    // For now, this is a placeholder that signals success.
    // Full implementation requires initializing services in the
    // background isolate.
    return true;
  });
}

/// Service for registering and managing periodic background sync.
///
/// On Android this uses WorkManager; on iOS it maps to BGTaskScheduler
/// under the hood via the workmanager plugin. On desktop and web the
/// feature is a no-op.
///
/// Background sync is OFF by default -- the user must opt in via the
/// settings toggle.
class BackgroundSyncService {
  static const _prefKey = 'background_sync_enabled';
  static const _taskName = 'anynote_background_sync';
  static const _tag = 'sync';

  // Retained for future use when background isolate can access providers
  // directly (e.g. to read auth tokens).
  // ignore: unused_field
  final Ref _ref;

  // ignore: unused_element
  BackgroundSyncService(this._ref);

  /// Whether background sync is currently enabled.
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// Enable or disable background sync.
  ///
  /// Persists the preference and registers/cancels the periodic task
  /// accordingly. No-op on desktop or web.
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);

    if (kIsWeb || PlatformUtils.isDesktop) return;

    if (enabled) {
      await _registerTask();
    } else {
      await _cancelTask();
    }
  }

  /// Initialize WorkManager with the callback dispatcher.
  ///
  /// Call once during app startup. If background sync was previously
  /// enabled, the periodic task is re-registered automatically.
  static Future<void> initialize() async {
    if (kIsWeb || PlatformUtils.isDesktop) return;

    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );

    final enabled = await isEnabled();
    if (enabled) {
      await Workmanager().registerPeriodicTask(
        _taskName,
        _taskName,
        tag: _tag,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 5),
      );
    }
  }

  Future<void> _registerTask() async {
    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      tag: _tag,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
  }

  Future<void> _cancelTask() async {
    await Workmanager().cancelByTag(_tag);
  }
}

/// Provider for the background sync service.
final backgroundSyncProvider = Provider<BackgroundSyncService>((ref) {
  return BackgroundSyncService(ref);
});

/// Provider that exposes whether background sync is enabled.
final backgroundSyncEnabledProvider = FutureProvider<bool>((ref) async {
  return BackgroundSyncService.isEnabled();
});
