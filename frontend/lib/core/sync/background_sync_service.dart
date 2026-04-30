import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../database/app_database.dart';
import '../network/api_client.dart';
import '../platform/platform_utils.dart';

/// Background sync callback dispatcher for WorkManager.
///
/// Must be a top-level function so it can be resolved by the platform
/// plugin when the app is launched in the background.
///
/// This performs a **pull-only** sync using a lightweight HTTP client.
/// The sync engine is not used because it requires a [CryptoService] with
/// unlocked keys, which are generally not available in the background isolate.
///
/// Instead, we fetch the latest sync version and store it. On the next
/// foreground sync, the [SyncLifecycle] will pull any new blobs and
/// decrypt them properly.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (kDebugMode) {
      debugPrint('Background sync task: $task');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = prefs.getString('api_base_url');
      final accessToken = prefs.getString('access_token');

      if (baseUrl == null || accessToken == null) {
        if (kDebugMode) {
          debugPrint('Background sync: no auth credentials, skipping');
        }
        return true;
      }

      // Open the database to read the last synced version.
      final db = AppDatabase();
      try {
        final sinceVersion = await db.syncMetaDao.getLastSyncedVersion('all');

        // Perform a lightweight sync pull using the API client.
        final apiClient = ApiClient(baseUrl: baseUrl);
        apiClient.setAccessToken(accessToken);

        final response = await apiClient.syncPull(sinceVersion);

        if (response.blobs.isEmpty) {
          if (kDebugMode) {
            debugPrint('Background sync: no new items');
          }
          return true;
        }

        // Store the latest sync version in SharedPreferences (not in the
        // sync_meta table) so the foreground SyncEngine can use it as a hint.
        // We do NOT advance syncMeta here because the blobs have not been
        // processed — advancing would cause the foreground sync to skip them,
        // resulting in silent data loss.
        //
        // The foreground SyncEngine will pull blobs starting from its own
        // sinceVersion and process them with the crypto service.
        await prefs.setInt(
            'background_sync_latest_version', response.latestVersion);

        if (kDebugMode) {
          debugPrint(
            'Background sync: synced to version ${response.latestVersion}'
            ' (${response.blobs.length} items noted)',
          );
        }
        return true;
      } finally {
        await db.close();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Background sync failed: $e');
      }
      return false;
    }
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
