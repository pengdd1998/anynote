import 'dart:async';

import '../database/app_database.dart';
import '../database/daos/sync_operations_dao.dart';
import 'sync_engine.dart';

/// Manages a persistent queue of sync operations with retry logic.
///
/// The queue provides reliable offline-first sync by persisting operations
/// to the local database. When the app comes back online, the queue is
/// processed in order. Failed operations are retried with exponential
/// backoff (1s, 2s, 4s, 8s, 16s, capped at 5 minutes) up to a maximum
/// of 5 retries before being permanently failed.
///
/// Usage:
///   - Call [enqueue] when a local create/update/delete occurs.
///   - Call [processQueue] during sync cycles or when connectivity is restored.
///   - Watch [watchPendingCount] to show a badge in the UI.
class SyncQueueManager {
  final AppDatabase _db;
  final SyncEngine _syncEngine;
  bool _isProcessing = false;

  SyncQueueManager(this._db, this._syncEngine);

  /// Whether the queue is currently being processed.
  bool get isProcessing => _isProcessing;

  /// Convenience accessor for the sync operations DAO.
  SyncOperationsDao get _dao => _db.syncOperationsDao;

  /// Enqueue a create/update/delete operation for reliable sync.
  ///
  /// If an operation for the same [itemId] is already pending, it is
  /// replaced with the new one.
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
  /// are no-ops.
  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      // First, reset any retryable failed operations back to pending.
      final retryable = await _dao.getRetryableOperations();
      for (final op in retryable) {
        await _dao.resetToPending(op.id);
      }

      // Process all pending operations in order.
      final pending = await _dao.getPendingOperations();
      for (final op in pending) {
        await _processOperation(op);
      }

      // Housekeeping: remove completed operations.
      await _dao.clearCompleted();
    } finally {
      _isProcessing = false;
    }
  }

  /// Process a single operation from the queue.
  Future<void> _processOperation(SyncOperation op) async {
    await _dao.markInProgress(op.id);

    try {
      // The queue manager delegates the actual sync to the SyncEngine.
      // The engine handles encryption, API calls, and conflict resolution.
      // A successful full sync cycle is sufficient to flush all pending
      // local changes to the server.
      await _syncEngine.push();
      await _dao.markCompleted(op.id);
    } catch (e) {
      await _dao.markFailed(
        op.id,
        e.toString(),
        op.retryCount,
        op.maxRetries,
      );
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
