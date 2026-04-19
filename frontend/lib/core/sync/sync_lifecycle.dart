import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../features/settings/data/settings_providers.dart';
import '../crypto/crypto_service.dart';
import 'sync_engine.dart' show SyncResult;

/// Manages automatic periodic sync while the app is in the foreground.
///
/// Starts a 5-minute sync timer when the user is authenticated and the
/// crypto service is unlocked. Stops the timer on logout or lock.
///
/// On each sync cycle, the sync queue is also processed so that any
/// previously-failed offline operations are retried.
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
  /// After the main sync engine cycle completes, the sync queue manager
  /// processes any pending offline operations.
  Future<SyncResult?> syncNow() async {
    final engine = _ref.read(syncEngineProvider);
    try {
      final result = await engine.sync();
      _lastSyncAt = DateTime.now();

      // Process the offline operations queue after a successful sync.
      final queueManager = _ref.read(syncQueueManagerProvider);
      await queueManager.processQueue();

      return result;
    } catch (_) {
      // Even if the main sync fails, try to process any retryable
      // operations in case the network issue was transient.
      try {
        final queueManager = _ref.read(syncQueueManagerProvider);
        await queueManager.processQueue();
      } catch (_) {
        // Queue processing failure is non-fatal.
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
      final crypto = ref.read(cryptoServiceProvider);
      if (!crypto.isUnlocked) {
        crypto.unlock();
      }
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
