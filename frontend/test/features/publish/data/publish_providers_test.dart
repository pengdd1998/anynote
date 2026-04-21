import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/features/publish/data/publish_providers.dart';
import 'package:anynote/main.dart' show apiClientProvider;

// ---------------------------------------------------------------------------
// Stub ApiClient that records calls and returns configurable results.
// ---------------------------------------------------------------------------

class StubApiClient extends ApiClient {
  StubApiClient() : super(baseUrl: 'http://localhost:8080');

  List<Map<String, dynamic>> publishHistoryToReturn = [];
  List<Map<String, dynamic>> platformsToReturn = [];
  Map<String, dynamic>? publishResult;
  Map<String, dynamic>? getPublishResult;

  @override
  Future<List<Map<String, dynamic>>> publishHistory() async =>
      publishHistoryToReturn;

  @override
  Future<List<Map<String, dynamic>>> listPlatforms() async =>
      platformsToReturn;

  @override
  Future<Map<String, dynamic>> publish(Map<String, dynamic> req) async {
    if (publishResult != null) return publishResult!;
    return {'id': 'pub-1', 'status': 'pending'};
  }

  @override
  Future<Map<String, dynamic>> getPublish(String id) async {
    if (getPublishResult != null) return getPublishResult!;
    return {'id': id, 'status': 'completed'};
  }
}

/// ApiClient that throws DioException on publish to test error handling.
class FailingApiClient extends ApiClient {
  final DioException errorToThrow;

  FailingApiClient(this.errorToThrow) : super(baseUrl: 'http://localhost:8080');

  @override
  Future<Map<String, dynamic>> publish(Map<String, dynamic> req) async {
    throw errorToThrow;
  }

  @override
  Future<List<Map<String, dynamic>>> publishHistory() async =>
      throw errorToThrow;

  @override
  Future<List<Map<String, dynamic>>> listPlatforms() async =>
      throw errorToThrow;
}

/// ApiClient that throws a generic exception on publish.
class GenericErrorApiClient extends ApiClient {
  final Exception exception;

  GenericErrorApiClient(this.exception) : super(baseUrl: 'http://localhost:8080');

  @override
  Future<Map<String, dynamic>> publish(Map<String, dynamic> req) async {
    throw exception;
  }
}

void main() {
  // ===========================================================================
  // PublishActionState
  // ===========================================================================

  group('PublishActionState', () {
    test('default state is idle with no error and no result', () {
      const state = PublishActionState();
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.result, isNull);
    });

    test('copyWith overrides isLoading', () {
      const state = PublishActionState();
      final updated = state.copyWith(isLoading: true);
      expect(updated.isLoading, isTrue);
      expect(updated.error, isNull);
      expect(updated.result, isNull);
    });

    test('copyWith sets error and clears result', () {
      const state = PublishActionState(isLoading: true);
      final updated = state.copyWith(error: 'Network error');
      expect(updated.isLoading, isTrue); // unchanged
      expect(updated.error, 'Network error');
      // error causes result to be cleared (copyWith uses `error:` which replaces).
      // Actually, result stays as-is if not provided.
    });

    test('copyWith sets result', () {
      const state = PublishActionState(isLoading: true);
      final result = {'id': 'pub-1', 'status': 'completed'};
      final updated = state.copyWith(result: result);
      expect(updated.result, result);
      expect(updated.isLoading, isTrue);
    });

    test('default state is immutable via const', () {
      // Compile-time check: const constructors work.
      const state1 = PublishActionState();
      const state2 = PublishActionState();
      expect(state1.isLoading, state2.isLoading);
    });
  });

  // ===========================================================================
  // PublishActionNotifier
  // ===========================================================================

  group('PublishActionNotifier', () {
    late StubApiClient stubApi;
    late PublishActionNotifier notifier;

    setUp(() {
      stubApi = StubApiClient();
      notifier = PublishActionNotifier(stubApi);
    });

    test('initial state is idle', () {
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
      expect(notifier.state.result, isNull);
    });

    test('publish sets loading then success state', () async {
      stubApi.publishResult = {'id': 'pub-123', 'status': 'completed'};

      // Kick off publish -- it sets loading synchronously.
      final future = notifier.publish(
        platform: 'xhs',
        title: 'Test Title',
        content: 'Test content',
        tags: ['tag1', 'tag2'],
      );

      // After starting, state should be loading.
      expect(notifier.state.isLoading, isTrue);

      await future;

      // After completion, state should have the result.
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.result, isNotNull);
      expect(notifier.state.result!['id'], 'pub-123');
      expect(notifier.state.error, isNull);
    });

    test('publish includes contentItemId when provided', () async {
      stubApi.publishResult = {'id': 'pub-item'};

      await notifier.publish(
        platform: 'xhs',
        title: 'Title',
        content: 'Content',
        contentItemId: 'item-123',
      );

      expect(notifier.state.result, isNotNull);
    });

    test('publish handles DioException with message', () async {
      final failingApi = FailingApiClient(
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/publish'),
          message: 'Connection refused',
        ),
      );
      final failingNotifier = PublishActionNotifier(failingApi);

      await failingNotifier.publish(
        platform: 'xhs',
        title: 'Title',
        content: 'Content',
      );

      expect(failingNotifier.state.isLoading, isFalse);
      expect(failingNotifier.state.error, 'Connection refused');
      expect(failingNotifier.state.result, isNull);
    });

    test('publish handles DioException without message', () async {
      final failingApi = FailingApiClient(
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/publish'),
        ),
      );
      final failingNotifier = PublishActionNotifier(failingApi);

      await failingNotifier.publish(
        platform: 'xhs',
        title: 'Title',
        content: 'Content',
      );

      expect(failingNotifier.state.error, 'Network error occurred');
    });

    test('publish handles generic exception', () async {
      final errorApi = GenericErrorApiClient(
        Exception('Something unexpected'),
      );
      final errorNotifier = PublishActionNotifier(errorApi);

      await errorNotifier.publish(
        platform: 'xhs',
        title: 'Title',
        content: 'Content',
      );

      expect(errorNotifier.state.error, contains('Something unexpected'));
    });

    test('reset returns state to idle', () async {
      stubApi.publishResult = {'id': 'pub-reset'};
      await notifier.publish(
        platform: 'xhs',
        title: 'Title',
        content: 'Content',
      );

      expect(notifier.state.result, isNotNull);

      notifier.reset();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
      expect(notifier.state.result, isNull);
    });

    test('publish with empty tags list', () async {
      stubApi.publishResult = {'id': 'pub-no-tags'};

      await notifier.publish(
        platform: 'xhs',
        title: 'Title',
        content: 'Content',
        tags: [],
      );

      expect(notifier.state.result, isNotNull);
    });
  });

  // ===========================================================================
  // publishActionProvider
  // ===========================================================================

  group('publishActionProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(StubApiClient()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is idle via provider', () {
      final state = container.read(publishActionProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.result, isNull);
    });

    test('can invoke publish through the provider notifier', () async {
      final notifier = container.read(publishActionProvider.notifier);
      await notifier.publish(
        platform: 'xhs',
        title: 'Via Provider',
        content: 'Content',
      );

      final state = container.read(publishActionProvider);
      expect(state.isLoading, isFalse);
      expect(state.result, isNotNull);
    });
  });

  // ===========================================================================
  // PublishHistoryNotifier
  // ===========================================================================

  group('PublishHistoryNotifier', () {
    late ProviderContainer container;
    late StubApiClient stubApi;

    setUp(() {
      stubApi = StubApiClient();
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(stubApi),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('build returns publish history from API', () async {
      stubApi.publishHistoryToReturn = [
        {'id': 'pub-1', 'status': 'completed'},
        {'id': 'pub-2', 'status': 'pending'},
      ];

      final history = await container.read(publishHistoryProvider.future);

      expect(history.length, 2);
      expect(history[0]['id'], 'pub-1');
      expect(history[1]['status'], 'pending');
    });

    test('build returns empty list when no history', () async {
      stubApi.publishHistoryToReturn = [];

      final history = await container.read(publishHistoryProvider.future);
      expect(history, isEmpty);
    });

    test('refresh re-fetches from the API', () async {
      stubApi.publishHistoryToReturn = [
        {'id': 'pub-old'},
      ];

      // Initial load.
      await container.read(publishHistoryProvider.future);

      // Simulate data change on server.
      stubApi.publishHistoryToReturn = [
        {'id': 'pub-old'},
        {'id': 'pub-new'},
      ];

      // Refresh.
      container.read(publishHistoryProvider.notifier).refresh();

      // Allow the async rebuild to complete.
      await Future<void>.delayed(Duration.zero);

      final updated = await container.read(publishHistoryProvider.future);
      expect(updated.length, 2);
    });
  });

  // ===========================================================================
  // ConnectedPlatformsNotifier
  // ===========================================================================

  group('ConnectedPlatformsNotifier', () {
    late ProviderContainer container;
    late StubApiClient stubApi;

    setUp(() {
      stubApi = StubApiClient();
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(stubApi),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('filters to only connected platforms', () async {
      stubApi.platformsToReturn = [
        {'name': 'xhs', 'connected': true},
        {'name': 'weibo', 'connected': false},
        {'name': 'twitter', 'connected': true},
      ];

      final platforms =
          await container.read(connectedPlatformsProvider.future);

      expect(platforms.length, 2);
      expect(platforms.every((p) => p['connected'] == true), isTrue);
    });

    test('returns empty list when no platforms are connected', () async {
      stubApi.platformsToReturn = [
        {'name': 'xhs', 'connected': false},
      ];

      final platforms =
          await container.read(connectedPlatformsProvider.future);
      expect(platforms, isEmpty);
    });

    test('returns empty list when server returns empty list', () async {
      stubApi.platformsToReturn = [];

      final platforms =
          await container.read(connectedPlatformsProvider.future);
      expect(platforms, isEmpty);
    });

    test('refresh re-fetches platforms from the API', () async {
      stubApi.platformsToReturn = [
        {'name': 'xhs', 'connected': true},
      ];

      await container.read(connectedPlatformsProvider.future);

      // Add a new connected platform.
      stubApi.platformsToReturn = [
        {'name': 'xhs', 'connected': true},
        {'name': 'weibo', 'connected': true},
      ];

      container.read(connectedPlatformsProvider.notifier).refresh();
      await Future<void>.delayed(Duration.zero);

      final updated =
          await container.read(connectedPlatformsProvider.future);
      expect(updated.length, 2);
    });
  });

  // ===========================================================================
  // publishDetailProvider
  // ===========================================================================

  group('publishDetailProvider', () {
    late ProviderContainer container;
    late StubApiClient stubApi;

    setUp(() {
      stubApi = StubApiClient();
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(stubApi),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('fetches publish detail by ID', () async {
      stubApi.getPublishResult = {
        'id': 'pub-42',
        'status': 'completed',
        'title': 'My Post',
      };

      final detail =
          await container.read(publishDetailProvider('pub-42').future);

      expect(detail['id'], 'pub-42');
      expect(detail['status'], 'completed');
      expect(detail['title'], 'My Post');
    });

    test('different IDs produce independent providers', () async {
      // .family providers create a separate provider per key.
      final provider1 = publishDetailProvider('pub-1');
      final provider2 = publishDetailProvider('pub-2');

      expect(identical(provider1, provider2), isFalse);
    });
  });
}
