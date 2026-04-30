import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../features/settings/data/settings_providers.dart';

/// Queue status snapshot for UI consumption.
class OfflineQueueStatus {
  final int pendingCount;
  final int failedCount;
  final int inProgressCount;
  final int totalCount;

  const OfflineQueueStatus({
    this.pendingCount = 0,
    this.failedCount = 0,
    this.inProgressCount = 0,
    this.totalCount = 0,
  });

  bool get isEmpty => totalCount == 0;
  bool get hasFailed => failedCount > 0;
  bool get hasPending => pendingCount > 0;
}

/// Riverpod notifier that manages the offline sync queue lifecycle.
///
/// Provides reactive queue status for UI and exposes methods for
/// enqueueing operations, retrying failures, and processing the queue.
class OfflineQueueService extends AsyncNotifier<OfflineQueueStatus> {
  Timer? _refreshTimer;

  @override
  Future<OfflineQueueStatus> build() async {
    ref.onDispose(() {
      _refreshTimer?.cancel();
    });

    final status = await _loadStatus();

    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshStatus(),
    );

    return status;
  }

  /// Enqueue a sync operation for later processing.
  Future<void> enqueueOperation(
    String operationType,
    String entityType,
    String entityId, {
    String? payload,
  }) async {
    final db = ref.read(databaseProvider);
    await db.syncOperationsDao.enqueueOperation(
      operationType,
      entityType,
      entityId,
      payload ?? '',
    );
    await _refreshStatus();
  }

  /// Process the offline queue by delegating to the [SyncQueueManager],
  /// which runs each operation through the [SyncEngine] for actual sync.
  Future<void> processQueue() async {
    try {
      final queueManager = ref.read(syncQueueManagerProvider);
      await queueManager.processQueue();
    } catch (e) {
      debugPrint('[OfflineQueueService] processQueue failed: $e');
    }
    await _refreshStatus();
  }

  /// Retry all failed operations by resetting them to pending.
  Future<void> retryFailed() async {
    final db = ref.read(databaseProvider);
    final dao = db.syncOperationsDao;
    final failed = await dao.getFailedOperations();
    for (final op in failed) {
      await dao.resetToPending(op.id);
    }
    await processQueue();
  }

  /// Clear completed operations from the queue.
  Future<void> clearCompleted() async {
    final db = ref.read(databaseProvider);
    await db.syncOperationsDao.clearCompleted();
    await _refreshStatus();
  }

  Future<OfflineQueueStatus> _loadStatus() async {
    final db = ref.read(databaseProvider);
    final dao = db.syncOperationsDao;

    final pending = await dao.getPendingOperationsCount();
    final failed = await dao.getFailedOperations();

    return OfflineQueueStatus(
      pendingCount: pending,
      failedCount: failed.length,
      inProgressCount: 0,
      totalCount: pending + failed.length,
    );
  }

  Future<void> _refreshStatus() async {
    if (!state.hasValue && state.isLoading) return;
    try {
      final status = await _loadStatus();
      state = AsyncData(status);
    } catch (e) {
      // Keep previous state on refresh failure.
      debugPrint('[OfflineQueueService] status refresh failed: $e');
    }
  }
}

/// Provider for the OfflineQueueService.
final offlineQueueServiceProvider =
    AsyncNotifierProvider<OfflineQueueService, OfflineQueueStatus>(
  OfflineQueueService.new,
);
