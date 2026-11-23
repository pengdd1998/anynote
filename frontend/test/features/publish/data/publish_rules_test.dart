import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/features/publish/data/publish_providers.dart';
import 'package:anynote/features/publish/domain/publish_rules.dart';
import 'package:anynote/main.dart' show apiClientProvider;

/// Records what the publish endpoints were asked and answers however the
/// test wants, so each server behaviour can be reproduced.
class _RulesApiClient extends ApiClient {
  _RulesApiClient() : super(baseUrl: 'http://localhost:8080');

  List<Map<String, dynamic>>? platformsToReturn;
  Object? platformsError;

  /// A test that needs the platform rules to arrive late parks the call here.
  Completer<void>? platformsGate;
  Map<String, dynamic> validationToReturn = const {'valid': true};
  Object? validationError;
  Map<String, dynamic>? publishToReturn;
  Object? publishError;

  final publishRequests = <Map<String, dynamic>>[];
  final validationRequests = <Map<String, dynamic>>[];
  final validationGate = <Completer<void>>[];

  @override
  Future<List<Map<String, dynamic>>> publishPlatforms() async {
    await platformsGate?.future;
    if (platformsError != null) throw platformsError!;
    return platformsToReturn ?? const [];
  }

  @override
  Future<Map<String, dynamic>> validatePublish(Map<String, dynamic> req) async {
    validationRequests.add(req);
    // Tests that need a slow answer park the call here.
    if (validationGate.isNotEmpty) await validationGate.removeAt(0).future;
    if (validationError != null) throw validationError!;
    return validationToReturn;
  }

  @override
  Future<Map<String, dynamic>> publish(Map<String, dynamic> req) async {
    publishRequests.add(req);
    if (publishError != null) throw publishError!;
    return publishToReturn ?? const {'id': 'pub-1', 'status': 'pending'};
  }
}

DioException _dioError(int status, dynamic body) => DioException(
      requestOptions: RequestOptions(path: '/api/v1/publish'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/api/v1/publish'),
        statusCode: status,
        data: body,
      ),
    );

ProviderContainer _container(_RulesApiClient api) => ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api)],
    );

final _xhsGuide = <String, dynamic>{
  'id': 'xiaohongshu',
  'name': '小红书',
  'title_max': 20,
  'content_max': 1000,
  'max_tags': 10,
  'links_allowed': false,
  'guidance': ['像跟朋友讲这周干了什么。', '标题 20 字以内。'],
};

void main() {
  // ===========================================================================
  // Reading the server's findings
  // ===========================================================================

  group('PublishProblems', () {
    test('a 400 body yields its blocking problems and the summary', () {
      final body = {
        'error': {
          'code': 'validation_error',
          'message': '小红书：标题 超过上限 20 字（当前 21 字）',
          'problems': [
            {
              'field': 'title',
              'severity': 'error',
              'message': '小红书：标题 超过上限 20 字（当前 21 字）'
            },
            {'field': 'content', 'severity': 'error', 'message': '小红书：正文包含链接'},
          ],
        },
      };

      final found = PublishProblems.fromErrorBody(body);

      expect(found.blocking, hasLength(2));
      expect(found.blocking.first.field, 'title');
      expect(found.blocking.first.blocking, isTrue);
      expect(found.advisory, isEmpty);
      expect(
          PublishProblems.rejectionMessage(body), '小红书：标题 超过上限 20 字（当前 21 字）');
    });

    test('an accepted response only ever carries advice', () {
      final found = PublishProblems.fromResponse({
        'id': 'pub-1',
        'warnings': [
          {'field': 'tags', 'severity': 'warning', 'message': '标签过长'},
        ],
      });
      expect(found.blocking, isEmpty);
      expect(found.advisory.single.blocking, isFalse);
    });

    test('a validation response sorts blocking from advisory', () {
      final found = PublishProblems.fromValidation({
        'valid': false,
        'problems': [
          {'field': 'tags', 'severity': 'warning', 'message': 'w'},
          {'field': 'content', 'severity': 'error', 'message': 'e'},
        ],
      });
      expect(found.blocking.single.message, 'e');
      expect(found.advisory.single.message, 'w');
    });

    test('bodies without problems are handled instead of crashing', () {
      expect(PublishProblems.fromErrorBody(null).blocking, isEmpty);
      expect(PublishProblems.fromErrorBody('Bad Request').blocking, isEmpty);
      expect(
          PublishProblems.fromErrorBody({'error': 'nope'}).blocking, isEmpty);
      expect(
          PublishProblems.fromErrorBody({
            'error': {'problems': 'garbage'}
          }).blocking,
          isEmpty);
      expect(
          PublishProblems.rejectionMessage({
            'error': {'message': ''}
          }),
          isNull);
      expect(PublishProblems.fromResponse(null).advisory, isEmpty);
    });
  });

  // ===========================================================================
  // Platform rules
  // ===========================================================================

  group('PlatformGuide', () {
    test('parses the server shape', () {
      final guide = PlatformGuide.fromJson(_xhsGuide);
      expect(guide.id, 'xiaohongshu');
      expect(guide.name, '小红书');
      expect(guide.titleMax, 20);
      expect(guide.contentMax, 1000);
      expect(guide.maxTags, 10);
      expect(guide.linksAllowed, isFalse);
      expect(guide.guidance, hasLength(2));
    });

    test('lengths count characters the way the user sees them', () {
      // The server counts runes; counting bytes would make a 20-character
      // Chinese title look like 60 and turn the limit red far too early.
      expect(PlatformGuide.lengthOf('标'), 1);
      expect(PlatformGuide.lengthOf('标' * 20), 20);
      expect(PlatformGuide.lengthOf('a,b c'), 5);
    });

    test('guideFor finds a platform and returns null otherwise', () {
      final guides = fallbackPlatformGuides;
      expect(guideFor(guides, 'zhihu')?.id, 'zhihu');
      expect(guideFor(guides, 'myspace'), isNull);
    });
  });

  group('platformGuidesProvider', () {
    test('uses the server rules when they arrive', () async {
      final api = _RulesApiClient()..platformsToReturn = [_xhsGuide];
      final container = _container(api);
      addTearDown(container.dispose);

      final guides = await container.read(platformGuidesProvider.future);

      expect(guides.single.id, 'xiaohongshu');
      expect(guides.single.guidance, isNotEmpty,
          reason: 'the writing brief must reach the composition step');
    });

    test('falls back to the built-in limits when the server cannot be reached',
        () async {
      final api = _RulesApiClient()..platformsError = _dioError(503, null);
      final container = _container(api);
      addTearDown(container.dispose);

      final guides = await container.read(platformGuidesProvider.future);

      expect(guides.map((g) => g.id), fallbackPlatformGuides.map((g) => g.id));
    });

    test('an empty answer is not treated as "no platform has rules"', () async {
      final api = _RulesApiClient();
      final container = _container(api);
      addTearDown(container.dispose);

      final guides = await container.read(platformGuidesProvider.future);

      expect(guides, fallbackPlatformGuides);
    });
  });

  group('currentPlatformGuidesProvider', () {
    test('is the built-in table until the server has answered', () async {
      final answer = Completer<void>();
      final api = _RulesApiClient()
        ..platformsGate = answer
        ..platformsToReturn = [_xhsGuide];
      final container = _container(api);
      addTearDown(container.dispose);

      // Read while the request is still in flight, as an editor that opens
      // right after start-up would.
      expect(
        container.read(currentPlatformGuidesProvider),
        fallbackPlatformGuides,
      );

      answer.complete();
      await container.read(platformGuidesProvider.future);

      expect(container.read(currentPlatformGuidesProvider).single.id,
          'xiaohongshu');
    });

    test('stays on the built-in table when the server fails', () async {
      final api = _RulesApiClient()..platformsError = _dioError(503, null);
      final container = _container(api);
      addTearDown(container.dispose);

      await container.read(platformGuidesProvider.future);

      expect(
        container.read(currentPlatformGuidesProvider),
        fallbackPlatformGuides,
      );
    });
  });

  // ===========================================================================
  // Publishing
  // ===========================================================================

  group('PublishActionNotifier.publish', () {
    test('sends the draft without a content_item_id when there is none',
        () async {
      final api = _RulesApiClient();
      final container = _container(api);
      addTearDown(container.dispose);

      await container
          .read(publishActionProvider.notifier)
          .publish(platform: 'zhihu', title: '标题', content: '正文', tags: ['t']);

      // The server used to require this field, which rejected every publish
      // made from the app.
      expect(api.publishRequests.single, {
        'platform': 'zhihu',
        'title': '标题',
        'content': '正文',
        'tags': ['t'],
      });
      expect(container.read(publishActionProvider).result, isNotNull);
    });

    test('a rejection that names fields keeps each problem', () async {
      final api = _RulesApiClient()
        ..publishError = _dioError(400, {
          'error': {
            'code': 'validation_error',
            'message': '小红书：标题 超过上限 20 字（当前 21 字）',
            'problems': [
              {
                'field': 'title',
                'severity': 'error',
                'message': '小红书：标题 超过上限 20 字（当前 21 字）'
              },
            ],
          },
        });
      final container = _container(api);
      addTearDown(container.dispose);

      await container
          .read(publishActionProvider.notifier)
          .publish(platform: 'xiaohongshu', title: 'x' * 21, content: 'c');

      final state = container.read(publishActionProvider);
      expect(state.result, isNull);
      expect(state.problems.single.field, 'title');
      expect(state.error, '小红书：标题 超过上限 20 字（当前 21 字）');
    });

    test('a rejection without field detail gives a readable message', () async {
      final api = _RulesApiClient()
        ..publishError = _dioError(400, {
          'error': {
            'code': 'validation_error',
            'message': 'Unsupported platform'
          },
        });
      final container = _container(api);
      addTearDown(container.dispose);

      await container
          .read(publishActionProvider.notifier)
          .publish(platform: 'myspace', title: 't', content: 'c');

      final state = container.read(publishActionProvider);
      expect(state.problems, isEmpty);
      // The server's reason, not Dio's wording for an HTTP 400.
      expect(state.error, 'Unsupported platform');
    });

    test('advice on an accepted publish is kept for display', () async {
      final api = _RulesApiClient()
        ..publishToReturn = {
          'id': 'pub-1',
          'status': 'pending',
          'warnings': [
            {'field': 'tags', 'severity': 'warning', 'message': '标签过长'},
          ],
        };
      final container = _container(api);
      addTearDown(container.dispose);

      await container
          .read(publishActionProvider.notifier)
          .publish(platform: 'zhihu', title: 't', content: 'c');

      final state = container.read(publishActionProvider);
      expect(state.result, isNotNull);
      expect(state.warnings.single.blocking, isFalse);
    });
  });

  // ===========================================================================
  // Pre-publish check
  // ===========================================================================

  group('PublishValidationNotifier', () {
    test('waits for a pause in typing, then reports what the server said', () {
      fakeAsync((async) {
        final api = _RulesApiClient()
          ..validationToReturn = {
            'valid': false,
            'problems': [
              {'field': 'content', 'severity': 'error', 'message': '正文包含链接'},
              {'field': 'tags', 'severity': 'warning', 'message': '标签过长'},
            ],
          };
        final notifier = PublishValidationNotifier(api);
        notifier.check(
          platformId: 'xiaohongshu',
          title: '标题',
          content: '看 https://example.com',
          tags: const ['t'],
        );

        expect(notifier.state.isChecking, isTrue);
        expect(api.validationRequests, isEmpty,
            reason: 'must not call on every keystroke');

        async.elapse(PublishValidationNotifier.debounceDelay);
        async.flushMicrotasks();

        expect(api.validationRequests.single['platform'], 'xiaohongshu');
        expect(notifier.state.isChecking, isFalse);
        expect(notifier.state.blocking.single.field, 'content');
        expect(notifier.state.advisory.single.field, 'tags');

        // A clean draft clears earlier findings.
        api.validationToReturn = const {'valid': true, 'problems': []};
        notifier.check(platformId: 'xiaohongshu', title: '标题', content: '正文');
        async.elapse(PublishValidationNotifier.debounceDelay);
        async.flushMicrotasks();
        expect(notifier.state.blocking, isEmpty);
        expect(notifier.state.advisory, isEmpty);
        notifier.dispose();
      });
    });

    test('keeps the previous findings while the next answer is pending', () {
      fakeAsync((async) {
        final api = _RulesApiClient()
          ..validationToReturn = {
            'valid': false,
            'problems': [
              {'field': 'content', 'severity': 'error', 'message': '正文包含链接'},
            ],
          };
        final notifier = PublishValidationNotifier(api);
        notifier.check(platformId: 'xiaohongshu', title: 't', content: 'a');
        async.elapse(PublishValidationNotifier.debounceDelay);
        async.flushMicrotasks();

        notifier.check(platformId: 'xiaohongshu', title: 't', content: 'ab');

        expect(notifier.state.isChecking, isTrue);
        expect(notifier.state.blocking, hasLength(1),
            reason: 'the list must not blink away on every keystroke');
        notifier.dispose();
      });
    });

    test('only the latest draft is checked when typing continues', () {
      fakeAsync((async) {
        final api = _RulesApiClient();
        final notifier = PublishValidationNotifier(api);
        for (final content in ['a', 'ab', 'abc']) {
          notifier.check(platformId: 'zhihu', title: 't', content: content);
          async.elapse(const Duration(milliseconds: 200));
        }

        expect(api.validationRequests, isEmpty);
        async.elapse(PublishValidationNotifier.debounceDelay);
        async.flushMicrotasks();

        expect(api.validationRequests, hasLength(1));
        expect(api.validationRequests.single['content'], 'abc');
        notifier.dispose();
      });
    });

    test('a slow answer for an older draft never overwrites the current one',
        () {
      fakeAsync((async) {
        final api = _RulesApiClient();
        final first = Completer<void>();
        api.validationGate.add(first);
        final notifier = PublishValidationNotifier(api);

        notifier.check(platformId: 'zhihu', title: 't', content: 'old');
        async.elapse(PublishValidationNotifier.debounceDelay);
        async.flushMicrotasks();
        // "old" is now waiting on the gate; "new" answers right away.
        api.validationToReturn = const {
          'valid': false,
          'problems': [
            {
              'field': 'content',
              'severity': 'error',
              'message': 'new draft problem'
            },
          ],
        };
        notifier.check(platformId: 'zhihu', title: 't', content: 'new');
        async.elapse(PublishValidationNotifier.debounceDelay);
        async.flushMicrotasks();
        expect(notifier.state.blocking.single.message, 'new draft problem');

        api.validationToReturn = const {
          'valid': false,
          'problems': [
            {
              'field': 'content',
              'severity': 'error',
              'message': 'stale problem'
            },
          ],
        };
        first.complete();
        async.flushMicrotasks();

        expect(notifier.state.blocking.single.message, 'new draft problem');
        notifier.dispose();
      });
    });

    test('a failed check is reported as unavailable, not as "all good"', () {
      fakeAsync((async) {
        final api = _RulesApiClient()..validationError = _dioError(503, null);
        final notifier = PublishValidationNotifier(api);
        notifier.check(platformId: 'zhihu', title: 't', content: 'c');
        async.elapse(PublishValidationNotifier.debounceDelay);
        async.flushMicrotasks();

        expect(notifier.state.unavailable, isTrue);
        expect(notifier.state.blocking, isEmpty,
            reason: 'nothing is known to be wrong');
        notifier.dispose();
      });
    });

    test('reset cancels a pending check', () {
      fakeAsync((async) {
        final api = _RulesApiClient();
        final notifier = PublishValidationNotifier(api);
        notifier.check(platformId: 'zhihu', title: 't', content: 'c');
        notifier.reset();
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        expect(api.validationRequests, isEmpty);
        expect(notifier.state.isChecking, isFalse);
        notifier.dispose();
      });
    });
  });
}
