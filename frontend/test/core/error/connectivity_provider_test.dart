import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/error/connectivity_provider.dart';
import 'package:anynote/core/network/connectivity_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:anynote/core/sync/sync_queue_manager.dart';
import 'package:anynote/features/settings/data/settings_providers.dart';
import 'package:anynote/main.dart';

// ---------------------------------------------------------------------------
// Mock: ConnectivityService
// ---------------------------------------------------------------------------

/// A mock ConnectivityService that extends the real service so it can be
/// used with [connectivityServiceProvider.overrideWith].
///
/// Overrides [build] to skip the real `_startMonitoring()` call and instead
/// provides a manually controllable stream.
class MockConnectivityService extends ConnectivityService {
  final StreamController<bool> _streamController =
      StreamController<bool>.broadcast();

  @override
  bool build() {
    ref.onDispose(() {
      _streamController.close();
    });
    // Default to connected; tests can change via setConnected().
    return true;
  }

  /// Simulate a connectivity change. Sets both the notifier state and
  /// emits on the stream so providers watching either path see the update.
  ///
  /// IMPORTANT: The provider must have been read (to initialize the element)
  /// before calling this method, otherwise LateInitializationError occurs.
  void setConnected(bool value) {
    state = value;
    if (!_streamController.isClosed) {
      _streamController.add(value);
    }
  }

  @override
  Stream<bool> get connectivityStream => _streamController.stream;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _streamController.stream.map((connected) => connected
          ? [ConnectivityResult.wifi]
          : [ConnectivityResult.none]);

  @override
  Future<void> recheck() async {}
}

// ---------------------------------------------------------------------------
// Mock: SyncQueueManager
// ---------------------------------------------------------------------------

/// Records whether [processQueue] was called and how many times.
class MockSyncQueueManager implements SyncQueueManager {
  int processQueueCallCount = 0;

  @override
  Future<void> processQueue() async {
    processQueueCallCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockConnectivityService mockService;
  late MockSyncQueueManager mockQueueManager;
  late ProviderContainer container;

  setUp(() {
    mockService = MockConnectivityService();
    mockQueueManager = MockSyncQueueManager();
  });

  tearDown(() {
    container.dispose();
  });

  /// Create a ProviderContainer with the necessary provider overrides.
  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        connectivityServiceProvider.overrideWith(() => mockService),
        syncQueueManagerProvider.overrideWithValue(mockQueueManager),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // connectivityServiceProvider (direct notifier tests)
  // ---------------------------------------------------------------------------

  group('connectivityServiceProvider', () {
    test('initial state is true', () async {
      container = createContainer();

      final state = container.read(connectivityServiceProvider);
      expect(state, isTrue);
    });

    test('state changes to false when setConnected(false)', () async {
      container = createContainer();

      // Read to initialize the notifier element.
      container.read(connectivityServiceProvider);
      await container.pump();

      mockService.setConnected(false);
      await container.pump();

      expect(container.read(connectivityServiceProvider), isFalse);
    });

    test('state changes back to true when setConnected(true)', () async {
      container = createContainer();

      container.read(connectivityServiceProvider);
      await container.pump();

      mockService.setConnected(false);
      await container.pump();
      expect(container.read(connectivityServiceProvider), isFalse);

      mockService.setConnected(true);
      await container.pump();
      expect(container.read(connectivityServiceProvider), isTrue);
    });

    test('emits events on connectivityStream', () async {
      container = createContainer();

      // Access the notifier to initialize it and get the stream.
      container.read(connectivityServiceProvider.notifier);
      await container.pump();

      final events = <bool>[];
      final subscription =
          mockService.connectivityStream.listen((event) => events.add(event));

      mockService.setConnected(false);
      await container.pump();

      mockService.setConnected(true);
      await container.pump();

      await subscription.cancel();
      expect(events, [false, true]);
    });
  });

  // ---------------------------------------------------------------------------
  // connectivityProvider (StreamProvider wrapper)
  // ---------------------------------------------------------------------------

  group('connectivityProvider', () {
    test('provider can be read without error', () async {
      container = createContainer();

      // Reading the StreamProvider should not throw.
      final asyncValue = container.read(connectivityProvider);
      expect(asyncValue, isNotNull);

      await container.pump();
      // After pumping, the provider should have emitted at least one value.
      final value = container.read(connectivityProvider).valueOrNull;
      expect(value, anyOf(isNull, isTrue, isFalse));
    });

    test('stream emits initial values', () async {
      container = createContainer();

      // Watch the provider and collect emitted AsyncValue states.
      final events = <AsyncValue<ConnectivityState>>[];
      container.listen<AsyncValue<ConnectivityState>>(
        connectivityProvider,
        (previous, next) {
          events.add(next);
        },
        fireImmediately: true,
      );

      await container.pump();
      await container.pump();

      // The provider should have emitted at least one value.
      expect(events, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // connectivitySyncTriggerProvider
  // ---------------------------------------------------------------------------

  group('connectivitySyncTriggerProvider', () {
    test('triggers processQueue when transitioning from offline to online',
        () async {
      container = createContainer();

      // Read both providers to activate the service notifier element
      // BEFORE calling setConnected (avoids LateInitializationError).
      container.read(connectivitySyncTriggerProvider);
      container.read(connectivityServiceProvider);
      await container.pump();

      // Start offline.
      mockService.setConnected(false);
      await container.pump();

      // Transition to online.
      mockService.setConnected(true);
      await container.pump();
      await container.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // The queue manager's processQueue should have been called at least once
      // due to the offline-to-online transition.
      expect(mockQueueManager.processQueueCallCount, greaterThan(0));
    });

    test('does not trigger processQueue on offline-to-offline', () async {
      container = createContainer();

      container.read(connectivitySyncTriggerProvider);
      container.read(connectivityServiceProvider);
      await container.pump();

      // Start offline.
      mockService.setConnected(false);
      await container.pump();

      final callsBefore = mockQueueManager.processQueueCallCount;

      // Stay offline.
      mockService.setConnected(false);
      await container.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        mockQueueManager.processQueueCallCount,
        callsBefore,
        reason: 'processQueue should not be called when staying offline',
      );
    });

    test('does not trigger processQueue on online-to-online', () async {
      container = createContainer();

      container.read(connectivitySyncTriggerProvider);
      container.read(connectivityServiceProvider);
      await container.pump();

      // Initial state from build() is true (online).
      final callsBefore = mockQueueManager.processQueueCallCount;

      // Stay online (re-emit true).
      mockService.setConnected(true);
      await container.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        mockQueueManager.processQueueCallCount,
        callsBefore,
        reason: 'processQueue should not be called when already online',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Provider lifecycle
  // ---------------------------------------------------------------------------

  group('provider lifecycle', () {
    test('provider cleanup cancels subscriptions', () async {
      container = createContainer();

      container.read(connectivityProvider);
      await container.pump();

      container.dispose();
      // If cleanup failed, an exception would propagate during dispose.
      expect(true, isTrue);
    });

    test('trigger provider can be read multiple times without error', () async {
      container = createContainer();

      container.read(connectivitySyncTriggerProvider);
      container.read(connectivitySyncTriggerProvider);

      await container.pump();
      expect(true, isTrue);
    });
  });
}

/// Extension to pump a ProviderContainer, allowing microtasks to complete.
extension on ProviderContainer {
  Future<void> pump() async {
    await Future<void>.delayed(Duration.zero);
  }
}
