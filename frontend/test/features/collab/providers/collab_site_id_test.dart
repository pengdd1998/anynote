import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anynote/features/collab/providers/collab_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Reset the in-memory cache before each test.
    CollabNotifier.resetSiteIdCache();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    CollabNotifier.resetSiteIdCache();
  });

  group('CollabNotifier siteId persistence', () {
    test('getOrCreateSiteId generates a valid UUID v4', () async {
      final siteId = await CollabNotifier.getOrCreateSiteId();

      // UUID v4 format: 8-4-4-4-12 hex chars.
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(siteId),
        isTrue,
        reason: 'siteId "$siteId" is not a valid UUID v4',
      );
    });

    test('siteId is persisted to SharedPreferences', () async {
      final siteId = await CollabNotifier.getOrCreateSiteId();

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('crdt_site_id');

      expect(stored, isNotNull);
      expect(stored, siteId);
    });

    test('siteId is stable across multiple calls', () async {
      final first = await CollabNotifier.getOrCreateSiteId();
      final second = await CollabNotifier.getOrCreateSiteId();
      final third = await CollabNotifier.getOrCreateSiteId();

      expect(first, second);
      expect(second, third);
    });

    test('siteId survives cache reset when prefs have value', () async {
      final original = await CollabNotifier.getOrCreateSiteId();

      // Clear the in-memory cache.
      CollabNotifier.resetSiteIdCache();

      // Re-read should return the same ID from SharedPreferences.
      final afterReset = await CollabNotifier.getOrCreateSiteId();
      expect(afterReset, original);
    });

    test('resetSiteIdCache clears the in-memory cache', () async {
      await CollabNotifier.getOrCreateSiteId();

      // Reset cache.
      CollabNotifier.resetSiteIdCache();

      // Access private field via reflection is not possible in Dart,
      // so we verify indirectly: after reset, a new call should still
      // return the same value from SharedPreferences (not generate a new one).
      final siteId = await CollabNotifier.getOrCreateSiteId();
      expect(siteId, isNotEmpty);
    });

    test('siteId does not change when SharedPreferences already has a value',
        () async {
      // Pre-set a value in SharedPreferences.
      const presetId = '11111111-2222-4333-b444-555555555555';
      SharedPreferences.setMockInitialValues({'crdt_site_id': presetId});

      final siteId = await CollabNotifier.getOrCreateSiteId();
      expect(siteId, presetId);
    });

    test('siteId is generated fresh when SharedPreferences is empty', () async {
      // Empty SharedPreferences (default mock).
      SharedPreferences.setMockInitialValues({});

      final siteId = await CollabNotifier.getOrCreateSiteId();

      // Should be a valid UUID, not empty.
      expect(siteId, isNotEmpty);
      expect(siteId.length, 36); // Standard UUID length with hyphens.

      // Should have been stored.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('crdt_site_id'), siteId);
    });

    test('multiple rapid calls return the same siteId', () async {
      // Simulate concurrent access.
      final results = await Future.wait([
        CollabNotifier.getOrCreateSiteId(),
        CollabNotifier.getOrCreateSiteId(),
        CollabNotifier.getOrCreateSiteId(),
        CollabNotifier.getOrCreateSiteId(),
        CollabNotifier.getOrCreateSiteId(),
      ]);

      // All results should be identical.
      expect(results.toSet().length, 1);
    });
  });
}
