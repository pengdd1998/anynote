import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/features/settings/domain/plan_model.dart';
import 'package:anynote/features/settings/providers/plan_providers.dart';
import 'package:anynote/main.dart' show apiClientProvider;

// ---------------------------------------------------------------------------
// Mock ApiClient with controlled responses for plan and profile endpoints.
// ---------------------------------------------------------------------------
class MockApiClient extends ApiClient {
  Map<String, dynamic>? planResponse;
  Map<String, dynamic>? meResponse;
  Map<String, dynamic>? upgradeResponse;

  // Error injection -- set to throw on next call.
  Object? planError;
  Object? meError;

  MockApiClient() : super(baseUrl: 'http://localhost:0');

  @override
  Future<Map<String, dynamic>> getPlan() async {
    if (planError != null) throw planError!;
    return planResponse ??
        <String, dynamic>{
          'plan': 'free',
          'limits': <String, dynamic>{},
          'ai_daily_used': 0,
          'storage_bytes': 0,
          'note_count': 0,
        };
  }

  @override
  Future<Map<String, dynamic>> getMe() async {
    if (meError != null) throw meError!;
    return meResponse ??
        <String, dynamic>{
          'display_name': 'Test',
          'bio': '',
        };
  }

  @override
  Future<Map<String, dynamic>> upgradePlan(String plan,
      {String? paymentRef,}) async {
    return upgradeResponse ??
        <String, dynamic>{
          'plan': plan,
          'limits': <String, dynamic>{},
          'ai_daily_used': 0,
          'storage_bytes': 0,
          'note_count': 0,
        };
  }

  @override
  Future<Map<String, dynamic>> updateProfile({
    required String displayName,
    required String bio,
    required bool publicProfileEnabled,
  }) async {
    return <String, dynamic>{
      'display_name': displayName,
      'bio': bio,
      'public_profile_enabled': publicProfileEnabled,
    };
  }
}

// ===========================================================================
// Tests
// ===========================================================================

void main() {
  // =========================================================================
  // PlanInfoNotifier
  // =========================================================================

  group('PlanInfoNotifier', () {
    late MockApiClient mockApi;
    late ProviderContainer container;

    setUp(() {
      mockApi = MockApiClient();
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial build fetches plan from API', () async {
      mockApi.planResponse = <String, dynamic>{
        'plan': 'free',
        'limits': <String, dynamic>{},
        'ai_daily_used': 10,
        'storage_bytes': 5000,
        'note_count': 42,
      };

      final result = await container.read(planInfoProvider.future);

      expect(result.plan, PlanType.free);
      expect(result.aiDailyUsed, 10);
      expect(result.storageBytes, 5000);
      expect(result.noteCount, 42);
    });

    test('refresh reloads from API', () async {
      // First load with default response.
      final first = await container.read(planInfoProvider.future);
      expect(first.plan, PlanType.free);
      expect(first.aiDailyUsed, 0);

      // Change the stub response.
      mockApi.planResponse = <String, dynamic>{
        'plan': 'pro',
        'limits': <String, dynamic>{'max_notes': 10000},
        'ai_daily_used': 50,
        'storage_bytes': 100000,
        'note_count': 200,
      };

      // Refresh.
      await container.read(planInfoProvider.notifier).refresh();
      final second = await container.read(planInfoProvider.future);

      expect(second.plan, PlanType.pro);
      expect(second.aiDailyUsed, 50);
      expect(second.limits.maxNotes, 10000);
    });

    test('upgrade calls API and updates state', () async {
      // Initial load.
      final first = await container.read(planInfoProvider.future);
      expect(first.plan, PlanType.free);

      // Upgrade to pro.
      mockApi.upgradeResponse = <String, dynamic>{
        'plan': 'pro',
        'limits': <String, dynamic>{
          'max_notes': 10000,
          'can_collaborate': true,
        },
        'ai_daily_used': 0,
        'storage_bytes': 0,
        'note_count': 0,
      };

      await container.read(planInfoProvider.notifier).upgrade(PlanType.pro);
      final upgraded = await container.read(planInfoProvider.future);

      expect(upgraded.plan, PlanType.pro);
      expect(upgraded.limits.maxNotes, 10000);
      expect(upgraded.limits.canCollaborate, isTrue);
    });

    test('build sets error state when API fails', () async {
      mockApi.planError = Exception('Network error');

      await expectLater(
        container.read(planInfoProvider.future),
        throwsA(isA<Exception>()),
      );
    });

    test('refresh sets error state on failure', () async {
      // First load succeeds.
      await container.read(planInfoProvider.future);

      // Now API fails.
      mockApi.planError = Exception('Server error');

      await container.read(planInfoProvider.notifier).refresh();

      await expectLater(
        container.read(planInfoProvider.future),
        throwsA(isA<Exception>()),
      );
    });
  });

  // =========================================================================
  // ProfileNotifier
  // =========================================================================

  group('ProfileNotifier', () {
    late MockApiClient mockApi;
    late ProviderContainer container;

    setUp(() {
      mockApi = MockApiClient();
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial build fetches profile from API', () async {
      mockApi.meResponse = {
        'display_name': 'Alice',
        'bio': 'Hello world',
      };

      final result = await container.read(profileProvider.future);

      expect(result['display_name'], 'Alice');
      expect(result['bio'], 'Hello world');
    });

    test('refresh invalidates and reloads', () async {
      // First load with default response.
      final first = await container.read(profileProvider.future);
      expect(first['display_name'], 'Test');

      // Change stub.
      mockApi.meResponse = {
        'display_name': 'Bob',
        'bio': 'Updated bio',
      };

      // Refresh.
      await container.read(profileProvider.notifier).refresh();
      final second = await container.read(profileProvider.future);

      expect(second['display_name'], 'Bob');
      expect(second['bio'], 'Updated bio');
    });

    test('updateProfile calls API then invalidates', () async {
      // Initial load.
      await container.read(profileProvider.future);

      // Update profile. The mock API returns the new values.
      mockApi.meResponse = {
        'display_name': 'New Name',
        'bio': 'New bio',
        'public_profile_enabled': true,
      };

      await container.read(profileProvider.notifier).updateProfile(
            displayName: 'New Name',
            bio: 'New bio',
            publicProfileEnabled: true,
          );

      // After invalidation, the provider re-fetches from the mock.
      final result = await container.read(profileProvider.future);
      expect(result['display_name'], 'New Name');
      expect(result['bio'], 'New bio');
    });

    test('build sets error state when API fails', () async {
      mockApi.meError = Exception('Unauthorized');

      await expectLater(
        container.read(profileProvider.future),
        throwsA(isA<Exception>()),
      );
    });
  });
}
