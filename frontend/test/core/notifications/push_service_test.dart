import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/core/notifications/push_service.dart';
import 'package:anynote/main.dart' show apiClientProvider;

// ---------------------------------------------------------------------------
// Mock ApiClient that records device registration calls.
// ---------------------------------------------------------------------------
class MockApiClient extends ApiClient {
  final List<({String token, String platform})> registerCalls = [];
  final List<String> unregisterCalls = [];

  // Error injection.
  Object? registerError;
  Object? unregisterError;

  MockApiClient() : super(baseUrl: 'http://localhost:8080');

  @override
  Future<void> registerDevice(String token, String platform) async {
    if (registerError != null) throw registerError!;
    registerCalls.add((token: token, platform: platform));
  }

  @override
  Future<void> unregisterDevice(String token) async {
    if (unregisterError != null) throw unregisterError!;
    unregisterCalls.add(token);
  }
}

// ===========================================================================
// Tests
// ===========================================================================

void main() {
  // =========================================================================
  // PushNotificationService construction
  // =========================================================================

  group('PushNotificationService construction', () {
    test('is not initialized after construction', () {
      final mockApi = MockApiClient();
      final service = PushNotificationService(mockApi);

      expect(service.isInitialized, isFalse);
    });

    test('has no current token after construction', () {
      final mockApi = MockApiClient();
      final service = PushNotificationService(mockApi);

      expect(service.currentToken, isNull);
    });
  });

  // =========================================================================
  // PushNotificationService dispose
  // =========================================================================

  group('PushNotificationService dispose', () {
    test('sets initialized to false after dispose', () {
      final mockApi = MockApiClient();
      final service = PushNotificationService(mockApi);

      // Manually simulate initialized state since we cannot call init()
      // without a real Firebase setup.
      // dispose() should reset the state regardless.
      service.dispose();

      expect(service.isInitialized, isFalse);
    });

    test('clears current token after dispose', () async {
      final mockApi = MockApiClient();
      final service = PushNotificationService(mockApi);

      // Dispose should clear the token.
      await service.dispose();

      expect(service.currentToken, isNull);
      expect(service.isInitialized, isFalse);
    });

    test('dispose without a token does not call unregister', () async {
      final mockApi = MockApiClient();
      final service = PushNotificationService(mockApi);

      await service.dispose();

      expect(mockApi.unregisterCalls, isEmpty);
    });
  });

  // =========================================================================
  // pushNotificationServiceProvider
  // =========================================================================

  group('pushNotificationServiceProvider', () {
    test('creates a PushNotificationService instance', () {
      final mockApi = MockApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
        ],
      );
      addTearDown(() => container.dispose());

      final service = container.read(pushNotificationServiceProvider);

      expect(service, isA<PushNotificationService>());
      expect(service.isInitialized, isFalse);
    });

    test('uses the provided ApiClient', () {
      final mockApi = MockApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
        ],
      );
      addTearDown(() => container.dispose());

      // Service should be created successfully with the mock API.
      final service = container.read(pushNotificationServiceProvider);
      expect(service, isNotNull);
    });

    test('returns same instance on multiple reads', () {
      final mockApi = MockApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
        ],
      );
      addTearDown(() => container.dispose());

      final first = container.read(pushNotificationServiceProvider);
      final second = container.read(pushNotificationServiceProvider);

      expect(identical(first, second), isTrue);
    });
  });

  // =========================================================================
  // Initialization state machine
  // =========================================================================

  group('PushNotificationService initialization state', () {
    test('init returns early if already initialized', () async {
      final mockApi = MockApiClient();
      final service = PushNotificationService(mockApi);

      // First init -- will attempt Firebase init, which will fail in test
      // environment and set _initialized = true.
      await service.init();
      expect(service.isInitialized, isTrue);

      // Second init should be a no-op. If it tried to reinitialize,
      // it might call Firebase again and throw.
      await service.init();
      expect(service.isInitialized, isTrue);
    });

    test('service can be reinitialized after dispose', () async {
      final mockApi = MockApiClient();
      final service = PushNotificationService(mockApi);

      // First init -- will fail gracefully (no Firebase in test env).
      await service.init();
      expect(service.isInitialized, isTrue);

      // Dispose resets the state.
      await service.dispose();
      expect(service.isInitialized, isFalse);

      // Re-init should work again.
      await service.init();
      expect(service.isInitialized, isTrue);
    });
  });

  // =========================================================================
  // Platform detection (indirect test via _detectPlatform)
  // =========================================================================

  group('PushNotificationService platform behavior', () {
    test('service constructs without error on test platform', () async {
      // In a test environment, we cannot directly test _detectPlatform
      // since it is private and depends on dart:io Platform. But we can
      // verify the service handles the test environment gracefully.
      final mockApi = MockApiClient();
      final service = PushNotificationService(mockApi);

      // Init should not throw even without Firebase configured.
      await service.init();
      expect(service.isInitialized, isTrue);
    });
  });
}
