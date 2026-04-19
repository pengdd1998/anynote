import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'sync_operations_dao.g.dart';

@DriftAccessor(tables: [SyncOperations])
class SyncOperationsDao extends DatabaseAccessor<AppDatabase>
    with _$SyncOperationsDaoMixin {
  SyncOperationsDao(super.db);

  /// Enqueue a new sync operation.
  Future<void> enqueueOperation(
    String operationType,
    String itemType,
    String itemId,
    String payload,
  ) async {
    await into(syncOperations).insert(
      SyncOperationsCompanion.insert(
        id: itemId,
        operationType: operationType,
        itemType: itemType,
        itemId: itemId,
        payload: payload,
      ),
      mode: InsertMode.replace,
    );
  }

  /// Get all pending operations ordered by creation time.
  Future<List<SyncOperation>> getPendingOperations() {
    return (select(syncOperations)
          ..where((s) => s.status.equals('pending'))
          ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]))
        .get();
  }

  /// Count of pending operations.
  Future<int> getPendingOperationsCount() async {
    final count = countAll();
    final query = selectOnly(syncOperations)
      ..addColumns([count])
      ..where(syncOperations.status.equals('pending'));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Stream of pending operations count for reactive UI updates.
  Stream<int> watchPendingOperationsCount() {
    final count = countAll();
    final query = selectOnly(syncOperations)
      ..addColumns([count])
      ..where(syncOperations.status.equals('pending'));
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// Mark an operation as currently being processed.
  Future<void> markInProgress(String id) async {
    await (update(syncOperations)..where((s) => s.id.equals(id))).write(
      const SyncOperationsCompanion(
        status: Value('in_progress'),
      ),
    );
  }

  /// Mark an operation as successfully completed.
  Future<void> markCompleted(String id) async {
    await (update(syncOperations)..where((s) => s.id.equals(id))).write(
      const SyncOperationsCompanion(
        status: Value('completed'),
      ),
    );
  }

  /// Mark an operation as failed with error details and schedule a retry.
  ///
  /// Sets [nextRetryAt] using exponential backoff: 2^retryCount seconds,
  /// capped at 5 minutes. If [retryCount] reaches [maxRetries], the
  /// operation is permanently failed (no next retry scheduled).
  Future<void> markFailed(String id, String error, int retryCount, int maxRetries) async {
    final isPermanentlyFailed = retryCount >= maxRetries;
    final nextRetry = isPermanentlyFailed
        ? const Value<DateTime?>(null)
        : Value<DateTime?>(_calculateNextRetry(retryCount));

    await (update(syncOperations)..where((s) => s.id.equals(id))).write(
      SyncOperationsCompanion(
        status: const Value('failed'),
        retryCount: Value(retryCount + 1),
        lastError: Value(error),
        nextRetryAt: nextRetry,
      ),
    );
  }

  /// Get failed operations that are ready for retry (nextRetryAt has passed).
  Future<List<SyncOperation>> getRetryableOperations() {
    final now = DateTime.now();
    return (select(syncOperations)
          ..where((s) =>
              s.status.equals('failed') & s.nextRetryAt.isSmallerOrEqualValue(now)))
        .get();
  }

  /// Reset a failed operation back to pending so it can be retried.
  Future<void> resetToPending(String id) async {
    await (update(syncOperations)..where((s) => s.id.equals(id))).write(
      const SyncOperationsCompanion(
        status: Value('pending'),
        nextRetryAt: Value(null),
      ),
    );
  }

  /// Remove all completed operations (housekeeping).
  Future<void> clearCompleted() async {
    await (delete(syncOperations)..where((s) => s.status.equals('completed'))).go();
  }

  /// Get all failed operations (for display in the UI).
  Future<List<SyncOperation>> getFailedOperations() {
    return (select(syncOperations)..where((s) => s.status.equals('failed'))).get();
  }

  /// Calculate exponential backoff: 2^retryCount seconds, max 5 minutes.
  DateTime _calculateNextRetry(int retryCount) {
    final delaySeconds = (1 << retryCount).clamp(1, 300);
    return DateTime.now().add(Duration(seconds: delaySeconds));
  }
}
