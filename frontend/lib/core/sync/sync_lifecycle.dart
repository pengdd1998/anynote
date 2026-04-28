import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../features/settings/data/settings_providers.dart';
import '../crypto/crypto_service.dart';
import '../database/app_database.dart';
import '../network/connectivity_service.dart';
import 'sync_engine.dart' show SyncResult;

/// Manages automatic periodic sync while the app is in the foreground.
///
/// Starts a 5-minute sync timer when the user is authenticated and the
/// crypto service is unlocked. Stops the timer on logout or lock.
///
/// On each sync cycle, the sync queue is also processed so that any
/// previously-failed offline operations are retried.
///
/// When the device is offline (as reported by [connectivityServiceProvider]),
/// periodic sync attempts are skipped. The sync queue is flushed automatically
/// when connectivity is restored via [connectivitySyncTriggerProvider].
class SyncLifecycle {
  final Ref _ref;
  Timer? _timer;
  DateTime? _lastSyncAt;

  SyncLifecycle(this._ref);

  /// Interval between automatic syncs.
  static const syncInterval = Duration(minutes: 5);

  /// Whether periodic sync is currently active.
  bool get isActive => _timer != null;

  /// When the last successful sync completed.
  DateTime? get lastSyncAt => _lastSyncAt;

  /// Start periodic sync. No-op if already running.
  void start() {
    if (_timer != null) return;
    _scheduleNext();
  }

  /// Stop periodic sync.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Run a single sync cycle immediately.
  ///
  /// If the device is offline, the sync is skipped entirely and null is
  /// returned. The offline queue will be flushed when connectivity is
  /// restored.
  ///
  /// After the main sync engine cycle completes, the sync queue manager
  /// processes any pending offline operations.
  Future<SyncResult?> syncNow() async {
    // Skip sync entirely when offline. The queue will be flushed when
    // the device reconnects.
    final isConnected = _ref.read(connectivityServiceProvider);
    if (!isConnected) {
      return null;
    }

    final engine = _ref.read(syncEngineProvider);
    try {
      final result = await engine.sync();
      _lastSyncAt = DateTime.now();

      // Process the offline operations queue after a successful sync.
      final queueManager = _ref.read(syncQueueManagerProvider);
      await queueManager.processQueue();

      return result;
    } catch (e) {
      // Even if the main sync fails, try to process any retryable
      // operations in case the network issue was transient.
      debugPrint('[SyncLifecycle] sync cycle failed: $e');
      try {
        final queueManager = _ref.read(syncQueueManagerProvider);
        await queueManager.processQueue();
      } catch (e2) {
        // Queue processing failure is non-fatal.
        debugPrint('[SyncLifecycle] queue processing failed: $e2');
      }
      return null;
    }
  }

  void _scheduleNext() {
    _timer = Timer(syncInterval, () {
      _doSync();
    });
  }

  Future<void> _doSync() async {
    final isAuthenticated = _ref.read(authStateProvider);
    if (!isAuthenticated) {
      stop();
      return;
    }

    await syncNow();

    // Schedule next sync regardless of success/failure.
    if (_timer != null) {
      _scheduleNext();
    }
  }

  /// Dispose resources.
  void dispose() {
    stop();
  }
}

/// Provides the SyncLifecycle singleton.
final syncLifecycleProvider = Provider<SyncLifecycle>((ref) {
  final lifecycle = SyncLifecycle(ref);
  ref.onDispose(() => lifecycle.dispose());

  // Auto-start periodic sync when the user is authenticated and crypto
  // is unlocked. Stop when they log out.
  ref.listen(authStateProvider, (previous, next) {
    if (next) {
      // Authenticated -- attempt to unlock crypto and start sync.
      // Wrap async work in a fire-and-forget future since ref.listen
      // callbacks are synchronous.
      Future(() async {
        final crypto = ref.read(cryptoServiceProvider);
        if (!crypto.isUnlocked) {
          await crypto.unlock();
        }
        // Derive and set the database encryption key now that crypto is
        // unlocked. The key is used for SQLCipher PRAGMA on the next
        // database connection.
        if (crypto.isUnlocked) {
          try {
            final dbKey = await crypto.deriveDatabaseKey();
            AppDatabase.setEncryptionKey(dbKey);
          } catch (e) {
            debugPrint(
              '[SyncLifecycle] failed to derive database key: $e',
            );
          }
        }
      });
      lifecycle.start();

      // On first auth, retry any previously-failed operations from the
      // sync queue (e.g. from a prior session that went offline).
      final queueManager = ref.read(syncQueueManagerProvider);
      queueManager.processQueue();
    } else {
      // Logged out -- stop sync.
      lifecycle.stop();
    }
  });

  return lifecycle;
});
