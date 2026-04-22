import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/crypto/crypto_service.dart';
import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/core/sync/sync_engine.dart';
import 'package:anynote/core/sync/sync_queue.dart';
import 'package:drift/drift.dart' hide Column, isNull, isNotNull;

// ---------------------------------------------------------------------------
// Manual mocks
// ---------------------------------------------------------------------------

/// A mock SyncEngine that records calls and can be configured to succeed/fail.
class _MockSyncEngine extends SyncEngine {
  int syncCallCount = 0;
  SyncResult? syncResultToReturn;
  Object? errorToThrow;

  _MockSyncEngine() : super(_FakeDb(), _FakeApi(), _FakeCrypto());

  @override
  Future<SyncResult> sync() async {
    syncCallCount++;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return syncResultToReturn ??
        SyncResult(pulledCount: 0, pushedCount: 0, conflicts: []);
  }
}

/// A mock CryptoService that reports a configurable unlock state.
class _MockCryptoService extends CryptoService {
  final bool _unlocked;
  _MockCryptoService({bool unlocked = true}) : _unlocked = unlocked;

  @override
  bool get isUnlocked => _unlocked;
}

class _MockCryptoLocked extends CryptoService {
  @override
  bool get isUnlocked => false;
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SyncQueue', () {
    late _MockSyncEngine mockEngine;
    late _MockCryptoService mockCrypto;

    setUp(() {
      mockEngine = _MockSyncEngine();
      mockCrypto = _MockCryptoService(unlocked: true);
    });

    group('startPeriodicSync / stopPeriodicSync', () {
      test('startPeriodicSync creates a recurring timer', () async {
        final queue = SyncQueue(mockEngine, mockCrypto);
        addTearDown(() => queue.dispose());

        queue.startPeriodicSync(interval: const Duration(milliseconds: 100));

        // Wait for at least two intervals.
        await Future<void>.delayed(const Duration(milliseconds: 350));

        queue.stopPeriodicSync();
        expect(mockEngine.syncCallCount, greaterThanOrEqualTo(2));
      });

      test('stopPeriodicSync cancels the timer', () async {
        final queue = SyncQueue(mockEngine, mockCrypto);
        addTearDown(() => queue.dispose());

        queue.startPeriodicSync(interval: const Duration(milliseconds: 100));
        queue.stopPeriodicSync();

        final countAfterStop = mockEngine.syncCallCount;
        await Future<void>.delayed(const Duration(milliseconds: 300));

        // No additional syncs should have been triggered.
        expect(mockEngine.syncCallCount, countAfterStop);
      });

      test('startPeriodicSync replaces previous timer', () async {
        final queue = SyncQueue(mockEngine, mockCrypto);
        addTearDown(() => queue.dispose());

        queue.startPeriodicSync(interval: const Duration(seconds: 30));
        queue.startPeriodicSync(interval: const Duration(milliseconds: 50));

        await Future<void>.delayed(const Duration(milliseconds: 200));

        queue.stopPeriodicSync();
        expect(mockEngine.syncCallCount, greaterThanOrEqualTo(2));
      });
    });

    group('syncIfNeeded', () {
      test('calls syncNow when not already syncing', () async {
        final queue = SyncQueue(mockEngine, mockCrypto);
        addTearDown(() => queue.dispose());

        final result = await queue.syncIfNeeded();

        expect(result, isNotNull);
        expect(mockEngine.syncCallCount, 1);
      });

      test('returns null when already syncing', () async {
        // Use a slow engine whose sync() blocks until we complete it.
        final slowEngine = _SlowMockSyncEngine();
        final queue = SyncQueue(slowEngine, mockCrypto);
        addTearDown(() => queue.dispose());

        // Start a sync that will not complete immediately.
        final syncFuture = queue.syncNow();

        // While the first sync is pending, syncIfNeeded should bail out.
        final result = await queue.syncIfNeeded();
        expect(result, isNull);

        // Complete the slow engine so the pending sync resolves.
        slowEngine.complete();
        await syncFuture;
      });
    });

    group('syncNow', () {
      test('returns SyncResult on success', () async {
        final expected = SyncResult(pulledCount: 5, pushedCount: 2, conflicts: []);
        mockEngine.syncResultToReturn = expected;

        final queue = SyncQueue(mockEngine, mockCrypto);
        addTearDown(() => queue.dispose());

        final result = await queue.syncNow();

        expect(result.pulledCount, 5);
        expect(result.pushedCount, 2);
      });

      test('clears lastError at start of sync', () async {
        final queue = SyncQueue(mockEngine, mockCrypto);
        addTearDown(() => queue.dispose());

        // First, produce an error.
        mockEngine.errorToThrow = Exception('SocketException: Connection refused');
        try {
          await queue.syncNow();
        } catch (_) {}

        expect(queue.lastError, isNotNull);

        // Now succeed -- lastError should be cleared.
        mockEngine.errorToThrow = null;
        await queue.syncNow();

        expect(queue.lastError, isNull);
      });

      test('sets cryptoNotReady warning when crypto is not unlocked', () async {
        final lockedCrypto = _MockCryptoLocked();
        final queue = SyncQueue(mockEngine, lockedCrypto);
        addTearDown(() => queue.dispose());

        final result = await queue.syncNow();

        expect(result, isNotNull);
        expect(queue.lastError, isNotNull);
        expect(queue.lastError!.kind, SyncErrorKind.cryptoNotReady);
        expect(queue.lastError!.message, contains('not unlocked'));
      });

      test('throws StateError if called while already syncing', () async {
        // Use a slow engine to keep sync in-flight.
        final slowEngine = _SlowMockSyncEngine();
        final queue = SyncQueue(slowEngine, mockCrypto);
        addTearDown(() => queue.dispose());

        // Start a sync that will not complete immediately.
        final firstSync = queue.syncNow();

        // Attempting a second syncNow should throw StateError.
        expect(
          () => queue.syncNow(),
          throwsA(isA<StateError>()),
        );

        // Let the first sync complete so tearDown is clean.
        slowEngine.complete();
        await firstSync;
      });

      test('resets isSyncing after error', () async {
        mockEngine.errorToThrow = Exception('Some error');

        final queue = SyncQueue(mockEngine, mockCrypto);
        addTearDown(() => queue.dispose());

        try {
          await queue.syncNow();
        } catch (_) {}

        expect(queue.isSyncing, isFalse);
      });

      test('resets isSyncing after success', () async {
        final queue = SyncQueue(mockEngine, mockCrypto);
        addTearDown(() => queue.dispose());

        await queue.syncNow();

        expect(queue.isSyncing, isFalse);
      });
    });

    group('error classification', () {
      test('classifies crypto-related errors as cryptoNotReady', () async {
        mockEngine.errorToThrow =
            Exception('CryptoService is not unlocked');

        final queue = SyncQueue(mockEngine, mockCrypto);
        addTearDown(() => queue.dispose());

        try {
          await queue.syncNow();
          fail('Expected SyncQueueError');
        } on SyncQueueError catch (e) {
          expect(e.kind, SyncErrorKind.cryptoNotReady);
        }
      });

      test('classifies SocketException as network error', () async {
        mockEngine.errorToThrow =
            Exception('SocketException: Connection refused');

        final queue = SyncQueue(mockEngine, mockCrypto);
        addTearDown(() => queue.dispose());

        try {
          await queue.syncNow();
          fail('Expected SyncQueueError');
        } on SyncQueueError catch (e) {
          expect(e.kind, SyncErrorKind.network);
          expect(e.cause, isNotNull);
        }
      });

      test('classifies Connection timed out as network error', () async {
        mockEngine.errorToThrow =
            Exception('Connection timed out after 30s');

        final queue = SyncQueue(mockEngine, mockCrypto);
        addTearDown(() => queue.dispose());

        try {
          await queue.syncNow();
          fail('Expected SyncQueueError');
        } on SyncQueueError catch (e) {
          expect(e.kind, SyncErrorKind.network);
        }
      });

      test('classifies 401 as auth error', () async {
        mockEngine.errorToThrow =
            Exception('401 Unauthorized: token expired');

        final queue = SyncQueue(mockEngine, mockCrypto);
        addTearDown(() => queue.dispose());

        try {
          await queue.syncNow();
          fail('Expected SyncQueueError');
        } on SyncQueueError catch (e) {
          expect(e.kind, SyncErrorKind.auth);
          expect(e.message, contains('Authentication'));
        }
      });

      test('classifies Unauthorized (without 401) as auth error', () async {
        mockEngine.errorToThrow =
            Exception('Unauthorized access');

        final queue = SyncQueue(mockEngine, mockCrypto);
        addTearDown(() => queue.dispose());

        try {
          await queue.syncNow();
          fail('Expected SyncQueueError');
        } on SyncQueueError catch (e) {
          expect(e.kind, SyncErrorKind.auth);
        }
      });

      test('classifies unknown errors as unknown', () async {
        mockEngine.errorToThrow =
            Exception('Something completely unexpected');

        final queue = SyncQueue(mockEngine, mockCrypto);
        addTearDown(() => queue.dispose());

        try {
          await queue.syncNow();
          fail('Expected SyncQueueError');
        } on SyncQueueError catch (e) {
          expect(e.kind, SyncErrorKind.unknown);
          expect(e.message, contains('Something completely unexpected'));
        }
      });

      test('lastError is populated after classified error', () async {
        mockEngine.errorToThrow =
            Exception('401 Unauthorized');

        final queue = SyncQueue(mockEngine, mockCrypto);
        addTearDown(() => queue.dispose());

        try {
          await queue.syncNow();
        } catch (_) {}

        expect(queue.lastError, isNotNull);
        expect(queue.lastError!.kind, SyncErrorKind.auth);
      });
    });

    group('properties', () {
      test('canEncrypt returns true when crypto is unlocked', () {
        final queue = SyncQueue(mockEngine, mockCrypto);
        addTearDown(() => queue.dispose());

        expect(queue.canEncrypt, isTrue);
      });

      test('canEncrypt returns false when crypto is locked', () {
        final lockedCrypto = _MockCryptoLocked();
        final queue = SyncQueue(mockEngine, lockedCrypto);
        addTearDown(() => queue.dispose());

        expect(queue.canEncrypt, isFalse);
      });

      test('isSyncing is false initially', () {
        final queue = SyncQueue(mockEngine, mockCrypto);
        addTearDown(() => queue.dispose());

        expect(queue.isSyncing, isFalse);
      });
    });

    group('dispose', () {
      test('dispose cancels the periodic timer', () async {
        final queue = SyncQueue(mockEngine, mockCrypto);

        queue.startPeriodicSync(interval: const Duration(milliseconds: 50));
        queue.dispose();

        final countAfterDispose = mockEngine.syncCallCount;
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(mockEngine.syncCallCount, countAfterDispose);
      });
    });
  });

  group('SyncQueueError', () {
    test('toString includes kind and message', () {
      final error = SyncQueueError(
        kind: SyncErrorKind.network,
        message: 'Network error',
        cause: Exception('original'),
      );

      final str = error.toString();
      expect(str, contains('SyncQueueError'));
      expect(str, contains('network'));
      expect(str, contains('Network error'));
    });

    test('cause is optional', () {
      final error = SyncQueueError(
        kind: SyncErrorKind.unknown,
        message: 'test',
      );

      expect(error.cause, isNull);
    });
  });

  group('SyncErrorKind', () {
    test('has all expected values', () {
      expect(SyncErrorKind.values, containsAll([
        SyncErrorKind.cryptoNotReady,
        SyncErrorKind.network,
        SyncErrorKind.auth,
        SyncErrorKind.unknown,
      ]),);
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A mock SyncEngine whose sync() blocks until [complete] is called.
class _SlowMockSyncEngine extends SyncEngine {
  final Completer<SyncResult> _completer = Completer<SyncResult>();

  _SlowMockSyncEngine() : super(_FakeDb(), _FakeApi(), _FakeCrypto());

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete(SyncResult(pulledCount: 0, pushedCount: 0));
    }
  }

  @override
  Future<SyncResult> sync() => _completer.future;
}
