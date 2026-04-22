// Tests for the discover feed providers extracted in Phase 51.
//
// Tests cover:
// - discoverFeedProvider family resolves with the correct offset parameter
// - reactionStateProvider initializes with an empty map
// - reactionStateProvider can be updated to track reaction state
// - Providers correctly depend on apiClientProvider

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/features/share/data/discover_providers.dart';
import 'package:anynote/main.dart';

// ---------------------------------------------------------------------------
// Fake ApiClient that returns a predictable discover feed
// ---------------------------------------------------------------------------

class _FakeApiClient extends ApiClient {
  final List<Map<String, dynamic>> _feed;
  final Map<String, dynamic> Function(String shareId, String reactionType)?
      _onToggleReaction;

  _FakeApiClient({
    List<Map<String, dynamic>>? feed,
    Map<String, dynamic> Function(String shareId, String reactionType)?
        onToggleReaction,
  })  : _feed = feed ?? [],
        _onToggleReaction = onToggleReaction,
        super(baseUrl: 'http://localhost:8080');

  @override
  Future<List<Map<String, dynamic>>> discoverFeed({
    int limit = 20,
    int offset = 0,
  }) async {
    // Return a slice of the feed based on offset.
    if (offset >= _feed.length) return [];
    final end = (offset + limit).clamp(0, _feed.length);
    return _feed.sublist(offset, end);
  }

  @override
  Future<Map<String, dynamic>> toggleReaction(
      String shareId, String reactionType,) async {
    if (_onToggleReaction != null) {
      return _onToggleReaction(shareId, reactionType);
    }
    return {'active': true, 'count': 1};
  }
}

void main() {
  group('discoverFeedProvider', () {
    test('returns empty list when API returns no items', () async {
      final container = ProviderContainer(overrides: [
        apiClientProvider
            .overrideWithValue(_FakeApiClient(feed: [])),
      ],);

      final result = await container.read(discoverFeedProvider(0).future);
      expect(result, isEmpty);

      container.dispose();
    });

    test('returns items from the API for offset 0', () async {
      final feedItems = [
        {
          'id': 'share-1',
          'encrypted_title': 'Test Note',
          'view_count': 5,
          'reaction_heart': 2,
          'reaction_bookmark': 1,
          'has_password': false,
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'share-2',
          'encrypted_title': 'Another Note',
          'view_count': 10,
          'reaction_heart': 0,
          'reaction_bookmark': 3,
          'has_password': true,
          'created_at': DateTime.now().toIso8601String(),
        },
      ];

      final container = ProviderContainer(overrides: [
        apiClientProvider
            .overrideWithValue(_FakeApiClient(feed: feedItems)),
      ],);

      final result = await container.read(discoverFeedProvider(0).future);
      expect(result.length, 2);
      expect(result[0]['id'], 'share-1');
      expect(result[1]['id'], 'share-2');

      container.dispose();
    });

    test('respects the offset parameter for pagination', () async {
      final feedItems = List.generate(
        25,
        (i) => {
          'id': 'share-$i',
          'encrypted_title': 'Note $i',
          'view_count': i,
          'reaction_heart': 0,
          'reaction_bookmark': 0,
          'has_password': false,
          'created_at': DateTime.now().toIso8601String(),
        },
      );

      final container = ProviderContainer(overrides: [
        apiClientProvider
            .overrideWithValue(_FakeApiClient(feed: feedItems)),
      ],);

      // Offset 0 should return the first 20 items (default limit).
      final firstPage = await container.read(discoverFeedProvider(0).future);
      expect(firstPage.length, 20);
      expect(firstPage.first['id'], 'share-0');

      // Offset 20 should return the remaining 5 items.
      final secondPage = await container.read(discoverFeedProvider(20).future);
      expect(secondPage.length, 5);
      expect(secondPage.first['id'], 'share-20');

      container.dispose();
    });

    test('family provider caches results for the same offset', () async {
      final feedItems = [
        {
          'id': 'share-1',
          'encrypted_title': 'Cached Note',
          'view_count': 1,
          'reaction_heart': 0,
          'reaction_bookmark': 0,
          'has_password': false,
          'created_at': DateTime.now().toIso8601String(),
        },
      ];

      final container = ProviderContainer(overrides: [
        apiClientProvider.overrideWithValue(_FakeApiClient(
          feed: feedItems,
        ),),
      ],);

      // Read the same offset twice.
      final result1 = await container.read(discoverFeedProvider(0).future);
      final result2 = await container.read(discoverFeedProvider(0).future);
      // Both reads return the same data.
      expect(result1, equals(result2));

      container.dispose();
    });

    test('different offset values produce different providers', () async {
      final feedItems = List.generate(
        30,
        (i) => {
          'id': 'share-$i',
          'encrypted_title': 'Note $i',
          'view_count': i,
          'reaction_heart': 0,
          'reaction_bookmark': 0,
          'has_password': false,
          'created_at': DateTime.now().toIso8601String(),
        },
      );

      final container = ProviderContainer(overrides: [
        apiClientProvider
            .overrideWithValue(_FakeApiClient(feed: feedItems)),
      ],);

      final page0 = await container.read(discoverFeedProvider(0).future);
      final page10 = await container.read(discoverFeedProvider(10).future);

      // Different offsets should yield different first items.
      expect(page0.first['id'], 'share-0');
      expect(page10.first['id'], 'share-10');

      container.dispose();
    });
  });

  group('reactionStateProvider', () {
    test('initializes with an empty map', () {
      final container = ProviderContainer();
      final state = container.read(reactionStateProvider('share-1'));
      expect(state, isA<Map<String, bool>>());
      expect(state, isEmpty);
      container.dispose();
    });

    test('each share ID gets its own independent state', () {
      final container = ProviderContainer();

      final state1 = container.read(reactionStateProvider('share-1'));
      final state2 = container.read(reactionStateProvider('share-2'));

      expect(identical(state1, state2), isFalse);
      expect(state1, isEmpty);
      expect(state2, isEmpty);

      container.dispose();
    });

    test('can be updated to track heart reaction', () {
      final container = ProviderContainer();

      // Set a heart reaction for share-1.
      container.read(reactionStateProvider('share-1').notifier).update(
            (state) => {...state, 'share-1:heart': true},
          );

      final state = container.read(reactionStateProvider('share-1'));
      expect(state['share-1:heart'], isTrue);
      expect(state.length, 1);

      container.dispose();
    });

    test('can be updated to track multiple reaction types', () {
      final container = ProviderContainer();

      container.read(reactionStateProvider('share-1').notifier).update(
            (state) => {
              ...state,
              'share-1:heart': true,
              'share-1:bookmark': false,
            },
          );

      final state = container.read(reactionStateProvider('share-1'));
      expect(state['share-1:heart'], isTrue);
      expect(state['share-1:bookmark'], isFalse);
      expect(state.length, 2);

      container.dispose();
    });

    test('can toggle reaction from true to false', () {
      final container = ProviderContainer();

      // Set heart to true.
      container.read(reactionStateProvider('share-1').notifier).update(
            (state) => {...state, 'share-1:heart': true},
          );
      expect(container.read(reactionStateProvider('share-1'))['share-1:heart'],
          isTrue,);

      // Toggle back to false.
      container.read(reactionStateProvider('share-1').notifier).update(
            (state) => {...state, 'share-1:heart': false},
          );
      expect(container.read(reactionStateProvider('share-1'))['share-1:heart'],
          isFalse,);

      container.dispose();
    });

    test('updating one share ID does not affect another', () {
      final container = ProviderContainer();

      // Set heart on share-1.
      container.read(reactionStateProvider('share-1').notifier).update(
            (state) => {...state, 'share-1:heart': true},
          );

      // share-2 should still be empty.
      expect(container.read(reactionStateProvider('share-2')), isEmpty);

      container.dispose();
    });
  });
}
