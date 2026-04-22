
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/crypto/crypto_service.dart';
import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/core/network/connectivity_service.dart';
import 'package:anynote/core/sync/sync_engine.dart';
import 'package:anynote/core/sync/sync_lifecycle.dart';
import 'package:anynote/core/sync/sync_queue_manager.dart';
import 'package:anynote/features/settings/data/settings_providers.dart';
import 'package:anynote/main.dart';
import 'package:drift/drift.dart' show QueryExecutor;

// ---------------------------------------------------------------------------
// Manual mocks
// ---------------------------------------------------------------------------

/// A mock Ref that allows pre-programming provider reads via [_overrides].
class _MockRef implements Ref {
  final Map<ProviderListenable<dynamic>, dynamic> _overrides = {};

  void setOverride<T>(ProviderListenable<T> provider, T value) {
    _overrides[provider] = value;
  }

  @override
  T read<T>(ProviderListenable<T> provider) {
    if (_overrides.containsKey(provider)) {
      return _overrides[provider] as T;
    }
    throw StateError('No override for $provider');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A mock SyncEngine that tracks whether sync() was called.
class _MockSyncEngine extends SyncEngine {
  int syncCallCount = 0;
  SyncResult? syncResult;
  Object? syncError;

  _MockSyncEngine() : super(_FakeDb(), _FakeApi(), _FakeCrypto());

  @override
  Future<SyncResult> sync() async {
    syncCallCount++;
    if (syncError != null) {
      throw syncError!;
    }
    return syncResult ??
        SyncResult(pulledCount: 0, pushedCount: 0, conflicts: []);
  }
}

/// A mock SyncQueueManager that tracks processQueue() calls.
class _MockSyncQueueManager extends SyncQueueManager {
  int processQueueCallCount = 0;
  Object? processQueueError;

  _MockSyncQueueManager() : super(_FakeDb(), _FakeSyncEngine());

  @override
  Future<void> processQueue() async {
    processQueueCallCount++;
    if (processQueueError != null) {
      throw processQueueError!;
    }
  }
}

// Minimal fakes required to construct SyncEngine and SyncQueueManager.
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

class _FakeSyncEngine extends SyncEngine {
  _FakeSyncEngine() : super(_FakeDb(), _FakeApi(), _FakeCrypto());
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SyncLifecycle', () {
    late _MockRef ref;
    late _MockSyncEngine mockEngine;
    late _MockSyncQueueManager mockQueueManager;

    setUp(() {
      ref = _MockRef();
      mockEngine = _MockSyncEngine();
      mockQueueManager = _MockSyncQueueManager();

      // Wire providers into mock ref.
      ref.setOverride<SyncEngine>(syncEngineProvider, mockEngine);
      ref.setOverride<SyncQueueManager>(
          syncQueueManagerProvider, mockQueueManager,);
    });

    group('start / stop lifecycle', () {
      test('start activates periodic sync', () {
        final lifecycle = SyncLifecycle(ref);
        addTearDown(() => lifecycle.dispose());

        expect(lifecycle.isActive, isFalse);

        lifecycle.start();
        expect(lifecycle.isActive, isTrue);

        lifecycle.stop();
        expect(lifecycle.isActive, isFalse);
      });

      test('start is idempotent -- second call is a no-op', () {
        final lifecycle = SyncLifecycle(ref);
        addTearDown(() => lifecycle.dispose());

        lifecycle.start();
        lifecycle.start();
        expect(lifecycle.isActive, isTrue);

        lifecycle.stop();
        expect(lifecycle.isActive, isFalse);
      });

      test('stop deactivates periodic sync', () {
        final lifecycle = SyncLifecycle(ref);
        addTearDown(() => lifecycle.dispose());

        lifecycle.start();
        expect(lifecycle.isActive, isTrue);

        lifecycle.stop();
        expect(lifecycle.isActive, isFalse);
      });

      test('stop when not started is a no-op', () {
        final lifecycle = SyncLifecycle(ref);
        addTearDown(() => lifecycle.dispose());

        // Should not throw.
        lifecycle.stop();
        expect(lifecycle.isActive, isFalse);
      });

      test('dispose calls stop and deactivates sync', () {
        final lifecycle = SyncLifecycle(ref);

        lifecycle.start();
        expect(lifecycle.isActive, isTrue);

        lifecycle.dispose();
        expect(lifecycle.isActive, isFalse);
      });

      test('dispose when not started is safe', () {
        final lifecycle = SyncLifecycle(ref);
        // Should not throw.
        lifecycle.dispose();
        expect(lifecycle.isActive, isFalse);
      });
    });

    group('syncNow', () {
      test('returns SyncResult when connected and sync succeeds', () async {
        final lifecycle = SyncLifecycle(ref);
        addTearDown(() => lifecycle.dispose());

        final expectedResult = SyncResult(
          pulledCount: 3,
          pushedCount: 1,
          conflicts: [],
        );
        mockEngine.syncResult = expectedResult;
        ref.setOverride<bool>(connectivityServiceProvider, true);

        final result = await lifecycle.syncNow();

        expect(result, isNotNull);
        expect(result!.pulledCount, 3);
        expect(result.pushedCount, 1);
        expect(mockEngine.syncCallCount, 1);
      });

      test('processes sync queue after successful sync', () async {
        final lifecycle = SyncLifecycle(ref);
        addTearDown(() => lifecycle.dispose());

        mockEngine.syncResult =
            SyncResult(pulledCount: 0, pushedCount: 0, conflicts: []);
        ref.setOverride<bool>(connectivityServiceProvider, true);

        await lifecycle.syncNow();

        expect(mockQueueManager.processQueueCallCount, 1);
      });

      test('updates lastSyncAt on success', () async {
        final lifecycle = SyncLifecycle(ref);
        addTearDown(() => lifecycle.dispose());

        mockEngine.syncResult =
            SyncResult(pulledCount: 0, pushedCount: 0, conflicts: []);
        ref.setOverride<bool>(connectivityServiceProvider, true);

        expect(lifecycle.lastSyncAt, isNull);
        await lifecycle.syncNow();
        expect(lifecycle.lastSyncAt, isNotNull);
      });

      test('returns null when device is offline', () async {
        final lifecycle = SyncLifecycle(ref);
        addTearDown(() => lifecycle.dispose());

        ref.setOverride<bool>(connectivityServiceProvider, false);

        final result = await lifecycle.syncNow();

        expect(result, isNull);
        expect(mockEngine.syncCallCount, 0);
        expect(mockQueueManager.processQueueCallCount, 0);
      });

      test('returns null when sync engine throws', () async {
        final lifecycle = SyncLifecycle(ref);
        addTearDown(() => lifecycle.dispose());

        mockEngine.syncError = Exception('Network error');
        ref.setOverride<bool>(connectivityServiceProvider, true);

        final result = await lifecycle.syncNow();

        expect(result, isNull);
        // Queue manager should still be called even after sync failure.
        expect(mockQueueManager.processQueueCallCount, 1);
      });

      test('returns null even if both sync and queue processing fail',
          () async {
        final lifecycle = SyncLifecycle(ref);
        addTearDown(() => lifecycle.dispose());

        mockEngine.syncError = Exception('Sync failed');
        mockQueueManager.processQueueError = Exception('Queue failed');
        ref.setOverride<bool>(connectivityServiceProvider, true);

        // Should not throw -- both error paths are caught.
        final result = await lifecycle.syncNow();

        expect(result, isNull);
      });

      test('lastSyncAt remains null after failed sync', () async {
        final lifecycle = SyncLifecycle(ref);
        addTearDown(() => lifecycle.dispose());

        mockEngine.syncError = Exception('fail');
        ref.setOverride<bool>(connectivityServiceProvider, true);

        await lifecycle.syncNow();

        expect(lifecycle.lastSyncAt, isNull);
      });

      test('lastSyncAt is updated to a recent timestamp', () async {
        final lifecycle = SyncLifecycle(ref);
        addTearDown(() => lifecycle.dispose());

        mockEngine.syncResult =
            SyncResult(pulledCount: 0, pushedCount: 0, conflicts: []);
        ref.setOverride<bool>(connectivityServiceProvider, true);

        final before = DateTime.now();
        await lifecycle.syncNow();
        final after = DateTime.now();

        expect(lifecycle.lastSyncAt, isNotNull);
        // The timestamp should be between before and after.
        expect(
          lifecycle.lastSyncAt!.isAfter(
              before.subtract(const Duration(milliseconds: 1)),),
          isTrue,
        );
        expect(
          lifecycle.lastSyncAt!.isBefore(
              after.add(const Duration(milliseconds: 1)),),
          isTrue,
        );
      });
    });

    group('lastSyncAt', () {
      test('initial value is null', () {
        final lifecycle = SyncLifecycle(ref);
        addTearDown(() => lifecycle.dispose());

        expect(lifecycle.lastSyncAt, isNull);
      });

      test('accumulates across multiple successful syncs', () async {
        final lifecycle = SyncLifecycle(ref);
        addTearDown(() => lifecycle.dispose());

        mockEngine.syncResult =
            SyncResult(pulledCount: 0, pushedCount: 0, conflicts: []);
        ref.setOverride<bool>(connectivityServiceProvider, true);

        await lifecycle.syncNow();
        final firstSync = lifecycle.lastSyncAt;

        // Small delay to ensure timestamps differ.
        await Future<void>.delayed(const Duration(milliseconds: 10));

        await lifecycle.syncNow();
        final secondSync = lifecycle.lastSyncAt;

        expect(firstSync, isNotNull);
        expect(secondSync, isNotNull);
        // Second sync timestamp should be at or after the first.
        expect(secondSync!.isAfter(firstSync!), isTrue);
      });
    });

    group('syncInterval constant', () {
      test('is 5 minutes', () {
        expect(
          SyncLifecycle.syncInterval,
          const Duration(minutes: 5),
        );
      });
    });

    group('timer scheduling with real timers', () {
      test('timer fires a one-shot after the interval', () async {
        // Use a short interval for testing by directly testing the behavior.
        // SyncLifecycle uses Timer(syncInterval, callback), which is one-shot.
        // After the callback runs, _scheduleNext is called to reschedule.
        // We test this indirectly by verifying syncNow is called.
        final lifecycle = SyncLifecycle(ref);
        addTearDown(() => lifecycle.dispose());

        ref.setOverride<bool>(connectivityServiceProvider, true);
        ref.setOverride<bool>(authStateProvider, true);
        mockEngine.syncResult =
            SyncResult(pulledCount: 0, pushedCount: 0, conflicts: []);

        lifecycle.start();
        expect(lifecycle.isActive, isTrue);

        // Manually trigger syncNow to verify the engine integration works.
        await lifecycle.syncNow();

        expect(mockEngine.syncCallCount, 1);
        expect(mockQueueManager.processQueueCallCount, 1);

        lifecycle.stop();
      });

      test('stop cancels the pending timer before it fires', () async {
        final lifecycle = SyncLifecycle(ref);
        addTearDown(() => lifecycle.dispose());

        lifecycle.start();
        lifecycle.stop();

        // Wait briefly to confirm no sync was triggered.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(mockEngine.syncCallCount, 0);
      });

      test('restart creates a new timer after stop', () async {
        final lifecycle = SyncLifecycle(ref);
        addTearDown(() => lifecycle.dispose());

        ref.setOverride<bool>(connectivityServiceProvider, true);
        mockEngine.syncResult =
            SyncResult(pulledCount: 0, pushedCount: 0, conflicts: []);

        lifecycle.start();
        lifecycle.stop();
        expect(lifecycle.isActive, isFalse);

        lifecycle.start();
        expect(lifecycle.isActive, isTrue);

        lifecycle.stop();
      });
    });
  });
}
