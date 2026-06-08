import 'dart:async';

import '../database/app_database.dart';
import '../database/daos/sync_operations_dao.dart';
import '../error/error.dart';
import 'sync_engine.dart';

/// Manages a persistent queue of sync operations with retry logic and
/// connectivity awareness.
///
/// The queue provides reliable offline-first sync by persisting operations
/// to the local database. When the app comes back online, the queue is
/// processed in order. Failed operations are retried with exponential
/// backoff (1s, 2s, 4s, 8s, 16s, capped at 5 minutes) up to a maximum
/// of 5 retries before being permanently failed.
///
/// If a [connectivityChecker] is provided, [processQueue] will skip
/// processing when it reports the device as offline. Operations remain in
/// the queue until connectivity is restored and the queue is flushed (which
/// is typically driven by the [connectivitySyncTriggerProvider]).
///
/// Usage:
///   - Call [enqueue] when a local create/update/delete occurs.
///   - Call [processQueue] during sync cycles or when connectivity is restored.
///   - Watch [watchPendingCount] to show a badge in the UI.
class SyncQueueManager {
  final AppDatabase _db;
  final SyncEngine _syncEngine;

  /// Optional callback that returns whether the device is currently online.
  /// When null, the queue assumes the device is always online (legacy mode).
  final bool Function()? connectivityChecker;

  bool _isProcessing = false;

  SyncQueueManager(
    this._db,
    this._syncEngine, {
    this.connectivityChecker,
  });

  /// Whether the queue is currently being processed.
  bool get isProcessing => _isProcessing;

  /// Convenience accessor for the sync operations DAO.
  SyncOperationsDao get _dao => _db.syncOperationsDao;

  /// Whether the device is currently connected to the network.
  /// Returns true if no connectivity checker is configured.
  bool get _isConnected => connectivityChecker?.call() ?? true;

  /// Enqueue a create/update/delete operation for reliable sync.
  ///
  /// If an operation for the same [itemId] is already pending, it is
  /// replaced with the new one.
  ///
  /// When the device is offline, calling [enqueue] is the primary mechanism
  /// for ensuring the operation will be synced later. The
  /// [connectivitySyncTriggerProvider] will call [processQueue] when the
  /// device reconnects.
  Future<void> enqueue(
    String operationType,
    String itemType,
    String itemId, {
    String? payload,
  }) async {
    await _dao.enqueueOperation(
      operationType,
      itemType,
      itemId,
      payload ?? '{}',
    );
  }

  /// Process all pending and retryable operations in the queue.
  ///
  /// This method is idempotent: if it is already running, subsequent calls
  /// are no-ops. If the device is offline (as reported by
  /// [connectivityChecker]), the call is skipped entirely and operations
  /// remain queued for a future flush.
  ///
  /// All pending operations are marked in-progress first, then a single
  /// [SyncEngine.push] call syncs all local changes at once. This avoids
  /// redundant pushes when N operations would each trigger a full push.
  Future<void> processQueue() async {
    if (_isProcessing) {
      return;
    }

    // Do not attempt to push when offline. Operations stay in the queue
    // and will be flushed when connectivity is restored.
    if (!_isConnected) {
      return;
    }

    _isProcessing = true;

    try {
      // First, reset any retryable failed operations back to pending.
      final retryable = await _dao.getRetryableOperations();
      for (final op in retryable) {
        await _dao.resetToPending(op.id);
      }

      // Collect all pending operations.
      final pending = await _dao.getPendingOperations();
      if (pending.isEmpty) {
        return;
      }

      // Re-check connectivity before processing.
      if (!_isConnected) {
        return;
      }

      // Mark all pending operations as in-progress.
      for (final op in pending) {
        await _dao.markInProgress(op.id);
      }

      // Perform a single push that syncs all local changes at once.
      try {
        await _syncEngine.push();
        // Mark all operations as completed after a successful push.
        for (final op in pending) {
          await _dao.markCompleted(op.id);
        }
      } catch (e) {
        final errorMessage = ErrorMapper.map(e).toString();
        for (final op in pending) {
          await _dao.markFailed(op.id, errorMessage, op.retryCount, op.maxRetries);
        }
      }

      // Housekeeping: remove completed operations.
      await _dao.clearCompleted();
    } finally {
      _isProcessing = false;
    }
  }

  /// Stream of the current pending operations count.
  ///
  /// Useful for displaying a badge on the sync icon in the app bar.
  Stream<int> watchPendingCount() {
    return _dao.watchPendingOperationsCount();
  }

  /// Get the current count of pending operations (one-shot).
  Future<int> getPendingCount() {
    return _dao.getPendingOperationsCount();
  }

  /// Get all permanently failed operations for display in the UI.
  Future<List<SyncOperation>> getFailedOperations() {
    return _dao.getFailedOperations();
  }
}
