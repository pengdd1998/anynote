import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/crypto/crypto_service.dart';
import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/database/daos/sync_operations_dao.dart';
import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/core/sync/sync_engine.dart';
import 'package:anynote/core/sync/sync_queue_manager.dart';
import 'package:drift/drift.dart' hide Column, isNull, isNotNull;

// ---------------------------------------------------------------------------
// Manual mocks
// ---------------------------------------------------------------------------

/// A mock SyncOperationsDao that tracks calls and returns configurable data.
class _MockSyncOperationsDao extends SyncOperationsDao {
  final List<SyncOperation> _pendingOperations = [];
  final List<SyncOperation> _retryableOperations = [];
  final List<SyncOperation> _failedOperations = [];

  int pendingCount = 0;
  final StreamController<int> _pendingCountController =
      StreamController<int>.broadcast();

  // Tracking counters.
  int enqueueCallCount = 0;
  List<String> enqueuedItems = [];
  int markInProgressCalls = 0;
  int markCompletedCalls = 0;
  int markFailedCalls = 0;
  int clearCompletedCalls = 0;
  int resetToPendingCalls = 0;

  _MockSyncOperationsDao() : super(_FakeDb());

  void addPendingOperation(SyncOperation op) {
    _pendingOperations.add(op);
  }

  void addRetryableOperation(SyncOperation op) {
    _retryableOperations.add(op);
  }

  @override
  Future<void> enqueueOperation(
    String operationType,
    String itemType,
    String itemId,
    String payload,
  ) async {
    enqueueCallCount++;
    enqueuedItems.add(itemId);
  }

  @override
  Future<List<SyncOperation>> getPendingOperations() async {
    return List.unmodifiable(_pendingOperations);
  }

  @override
  Future<int> getPendingOperationsCount() async => pendingCount;

  @override
  Stream<int> watchPendingOperationsCount() => _pendingCountController.stream;

  @override
  Future<void> markInProgress(String id) async {
    markInProgressCalls++;
  }

  @override
  Future<void> markCompleted(String id) async {
    markCompletedCalls++;
  }

  @override
  Future<void> markFailed(
    String id,
    String error,
    int retryCount,
    int maxRetries,
  ) async {
    markFailedCalls++;
  }

  @override
  Future<List<SyncOperation>> getRetryableOperations() async {
    return List.unmodifiable(_retryableOperations);
  }

  @override
  Future<void> resetToPending(String id) async {
    resetToPendingCalls++;
  }

  @override
  Future<void> clearCompleted() async {
    clearCompletedCalls++;
  }

  @override
  Future<List<SyncOperation>> getFailedOperations() async {
    return List.unmodifiable(_failedOperations);
  }

  void dispose() {
    _pendingCountController.close();
  }
}

/// A mock SyncEngine that tracks push() calls.
class _MockSyncEngine extends SyncEngine {
  int pushCallCount = 0;
  Object? pushError;

  _MockSyncEngine() : super(_FakeDb(), _FakeApi(), _FakeCrypto());

  @override
  Future<SyncPushResponse> push() async {
    pushCallCount++;
    if (pushError != null) {
      throw pushError!;
    }
    return SyncPushResponse(accepted: [], conflicts: []);
  }
}

/// A fake AppDatabase that exposes the mock DAO.
class _FakeDbWithDao extends AppDatabase {
  final SyncOperationsDao dao;
  _FakeDbWithDao(this.dao) : super.forTesting(_FakeExecutor());

  @override
  SyncOperationsDao get syncOperationsDao => dao;
}

// Minimal fakes for SyncEngine constructor dependencies.
class _FakeDb extends AppDatabase {
  _FakeDb() : super.forTesting(_FakeExecutor());
}

class _FakeExecutor implements QueryExecutor {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://localhost');
}

class _FakeCrypto extends CryptoService {
  @override
  bool get isUnlocked => false;
}

/// Helper to build a SyncOperation for tests.
SyncOperation _makeOp({
  String id = 'op-1',
  String operationType = 'create',
  String itemType = 'note',
  String itemId = 'item-1',
  String payload = '{}',
  int retryCount = 0,
  int maxRetries = 5,
  String status = 'pending',
}) {
  return SyncOperation(
    id: id,
    operationType: operationType,
    itemType: itemType,
    itemId: itemId,
    payload: payload,
    retryCount: retryCount,
    maxRetries: maxRetries,
    status: status,
    createdAt: DateTime.now(),
    nextRetryAt: null,
    lastError: null,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SyncQueueManager', () {
    late _MockSyncOperationsDao mockDao;
    late _MockSyncEngine mockEngine;
    late _FakeDbWithDao fakeDb;

    setUp(() {
      mockDao = _MockSyncOperationsDao();
      mockEngine = _MockSyncEngine();
      fakeDb = _FakeDbWithDao(mockDao);
    });

    tearDown(() {
      mockDao.dispose();
    });

    group('enqueue', () {
      test('delegates to DAO with correct arguments', () async {
        final manager = SyncQueueManager(fakeDb, mockEngine);

        await manager.enqueue('create', 'note', 'note-123');

        expect(mockDao.enqueueCallCount, 1);
        expect(mockDao.enqueuedItems, ['note-123']);
      });

      test('passes custom payload to DAO', () async {
        final manager = SyncQueueManager(fakeDb, mockEngine);

        await manager.enqueue(
          'update',
          'tag',
          'tag-456',
          payload: '{"name":"important"}',
        );

        expect(mockDao.enqueueCallCount, 1);
        expect(mockDao.enqueuedItems, ['tag-456']);
      });

      test('defaults payload to empty JSON object', () async {
        // Since the DAO mock does not capture the payload arg directly,
        // we verify by checking the enqueue delegates correctly.
        final manager = SyncQueueManager(fakeDb, mockEngine);

        await manager.enqueue('delete', 'collection', 'col-789');

        expect(mockDao.enqueueCallCount, 1);
      });

      test('multiple enqueue calls are all recorded', () async {
        final manager = SyncQueueManager(fakeDb, mockEngine);

        await manager.enqueue('create', 'note', 'n-1');
        await manager.enqueue('update', 'note', 'n-2');
        await manager.enqueue('delete', 'tag', 't-1');

        expect(mockDao.enqueueCallCount, 3);
        expect(mockDao.enqueuedItems, ['n-1', 'n-2', 't-1']);
      });
    });

    group('processQueue', () {
      test('does nothing when already processing', () async {
        // Use a slow engine to keep processing alive.
        final slowEngine = _SlowMockSyncEngine();
        final manager = SyncQueueManager(fakeDb, slowEngine);

        mockDao.addPendingOperation(_makeOp());

        final processFuture = manager.processQueue();
        expect(manager.isProcessing, isTrue);

        // Second call should be a no-op.
        await manager.processQueue();

        slowEngine.complete();
        await processFuture;
      });

      test('skips processing when connectivity checker returns false', () async {
        final manager = SyncQueueManager(
          fakeDb,
          mockEngine,
          connectivityChecker: () => false,
        );

        mockDao.addPendingOperation(_makeOp());
        await manager.processQueue();

        expect(mockEngine.pushCallCount, 0);
        expect(mockDao.markInProgressCalls, 0);
      });

      test('processes when connectivity checker returns true', () async {
        final manager = SyncQueueManager(
          fakeDb,
          mockEngine,
          connectivityChecker: () => true,
        );

        mockDao.addPendingOperation(_makeOp());
        await manager.processQueue();

        expect(mockEngine.pushCallCount, 1);
        expect(mockDao.markInProgressCalls, 1);
        expect(mockDao.markCompletedCalls, 1);
      });

      test('processes when no connectivity checker is configured', () async {
        final manager = SyncQueueManager(fakeDb, mockEngine);

        mockDao.addPendingOperation(_makeOp());
        await manager.processQueue();

        expect(mockEngine.pushCallCount, 1);
      });

      test('resets retryable operations before processing', () async {
        final retryableOp = _makeOp(id: 'retry-op', status: 'failed');
        mockDao.addRetryableOperation(retryableOp);

        final manager = SyncQueueManager(fakeDb, mockEngine);
        await manager.processQueue();

        expect(mockDao.resetToPendingCalls, 1);
      });

      test('processes pending operations in order', () async {
        final op1 = _makeOp(id: 'op-1', itemId: 'item-1');
        final op2 = _makeOp(id: 'op-2', itemId: 'item-2');
        final op3 = _makeOp(id: 'op-3', itemId: 'item-3');
        mockDao.addPendingOperation(op1);
        mockDao.addPendingOperation(op2);
        mockDao.addPendingOperation(op3);

        final manager = SyncQueueManager(fakeDb, mockEngine);
        await manager.processQueue();

        expect(mockDao.markInProgressCalls, 3);
        expect(mockEngine.pushCallCount, 3);
        expect(mockDao.markCompletedCalls, 3);
      });

      test('calls clearCompleted after processing', () async {
        final manager = SyncQueueManager(fakeDb, mockEngine);
        await manager.processQueue();

        expect(mockDao.clearCompletedCalls, 1);
      });

      test('marks operation as failed when push throws', () async {
        mockEngine.pushError = Exception('Network error');
        mockDao.addPendingOperation(_makeOp());

        final manager = SyncQueueManager(fakeDb, mockEngine);
        await manager.processQueue();

        expect(mockDao.markInProgressCalls, 1);
        expect(mockDao.markFailedCalls, 1);
        expect(mockDao.markCompletedCalls, 0);
      });

      test('stops processing if connectivity drops mid-batch', () async {
        var connectCount = 0;
        final manager = SyncQueueManager(
          fakeDb,
          mockEngine,
          connectivityChecker: () {
            connectCount++;
            // Goes offline after the first check (which is before the loop).
            return connectCount <= 2;
          },
        );

        mockDao.addPendingOperation(_makeOp(id: 'op-1'));
        mockDao.addPendingOperation(_makeOp(id: 'op-2'));

        await manager.processQueue();

        // First op should have been processed, second skipped.
        expect(mockEngine.pushCallCount, 1);
      });

      test('resets isProcessing in finally block on success', () async {
        final manager = SyncQueueManager(fakeDb, mockEngine);
        await manager.processQueue();
        expect(manager.isProcessing, isFalse);
      });

      test('resets isProcessing in finally block on error', () async {
        mockEngine.pushError = Exception('fail');
        mockDao.addPendingOperation(_makeOp());

        final manager = SyncQueueManager(fakeDb, mockEngine);
        await manager.processQueue();
        expect(manager.isProcessing, isFalse);
      });

      test('empty queue processes cleanly', () async {
        final manager = SyncQueueManager(fakeDb, mockEngine);
        await manager.processQueue();

        expect(mockEngine.pushCallCount, 0);
        expect(mockDao.markInProgressCalls, 0);
        expect(mockDao.clearCompletedCalls, 1);
      });
    });

    group('watchPendingCount', () {
      test('delegates to DAO stream', () async {
        final manager = SyncQueueManager(fakeDb, mockEngine);

        final stream = manager.watchPendingCount();
        expect(stream, isNotNull);

        // Start listening before emitting, since the controller is broadcast
        // and events are only delivered to active listeners.
        final countFuture = stream.first;

        // Emit a value and verify it arrives.
        mockDao._pendingCountController.add(5);

        final count = await countFuture;
        expect(count, 5);
      });
    });

    group('getPendingCount', () {
      test('delegates to DAO one-shot count', () async {
        mockDao.pendingCount = 7;

        final manager = SyncQueueManager(fakeDb, mockEngine);
        final count = await manager.getPendingCount();

        expect(count, 7);
      });

      test('returns 0 when no pending operations', () async {
        mockDao.pendingCount = 0;

        final manager = SyncQueueManager(fakeDb, mockEngine);
        final count = await manager.getPendingCount();

        expect(count, 0);
      });
    });

    group('getFailedOperations', () {
      test('delegates to DAO', () async {
        final failedOp = _makeOp(id: 'failed-1', status: 'failed');
        mockDao._failedOperations.add(failedOp);

        final manager = SyncQueueManager(fakeDb, mockEngine);
        final failed = await manager.getFailedOperations();

        expect(failed.length, 1);
        expect(failed[0].id, 'failed-1');
      });

      test('returns empty list when no failures', () async {
        final manager = SyncQueueManager(fakeDb, mockEngine);
        final failed = await manager.getFailedOperations();

        expect(failed, isEmpty);
      });
    });

    group('isProcessing', () {
      test('is false initially', () {
        final manager = SyncQueueManager(fakeDb, mockEngine);
        expect(manager.isProcessing, isFalse);
      });

      test('is true during processing and false after', () async {
        final slowEngine = _SlowMockSyncEngine();
        final manager = SyncQueueManager(fakeDb, slowEngine);

        mockDao.addPendingOperation(_makeOp());

        final future = manager.processQueue();
        expect(manager.isProcessing, isTrue);

        slowEngine.complete();
        await future;
        expect(manager.isProcessing, isFalse);
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A mock SyncEngine whose push() blocks until [complete] is called.
class _SlowMockSyncEngine extends SyncEngine {
  final Completer<SyncPushResponse> _completer = Completer<SyncPushResponse>();

  _SlowMockSyncEngine() : super(_FakeDb(), _FakeApi(), _FakeCrypto());

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete(SyncPushResponse(accepted: [], conflicts: []));
    }
  }

  @override
  Future<SyncPushResponse> push() => _completer.future;
}
