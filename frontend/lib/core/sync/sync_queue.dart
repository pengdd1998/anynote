import 'dart:async';

import 'sync_engine.dart';

/// Manages the sync queue and automatic sync scheduling.
class SyncQueue {
  final SyncEngine _syncEngine;
  Timer? _periodicTimer;
  bool _isSyncing = false;

  SyncQueue(this._syncEngine);

  /// Start periodic sync (every 30 seconds when app is active).
  void startPeriodicSync({Duration interval = const Duration(seconds: 30)}) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) => syncIfNeeded());
  }

  /// Stop periodic sync.
  void stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Trigger a sync if not already syncing.
  Future<SyncResult?> syncIfNeeded() async {
    if (_isSyncing) return null;
    return syncNow();
  }

  /// Force an immediate sync.
  Future<SyncResult> syncNow() async {
    if (_isSyncing) {
      throw StateError('Sync already in progress');
    }

    _isSyncing = true;
    try {
      return await _syncEngine.sync();
    } finally {
      _isSyncing = false;
    }
  }

  /// Whether a sync is currently in progress.
  bool get isSyncing => _isSyncing;

  /// Dispose resources.
  void dispose() {
    stopPeriodicSync();
  }
}
