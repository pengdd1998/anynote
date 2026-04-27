import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/ai_chat/domain/chat_message.dart' as chat;
import 'package:anynote/features/ai_chat/domain/chat_session.dart';
import 'package:anynote/features/ai_chat/providers/ai_chat_providers.dart';
import 'package:anynote/features/compose/data/ai_repository.dart';
import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/main.dart';

// ---------------------------------------------------------------------------
// Fake / stub dependencies
// ---------------------------------------------------------------------------

/// Minimal ApiClient stub to satisfy AIRepository constructor.
class _StubApiClient extends ApiClient {
  _StubApiClient() : super(baseUrl: 'http://localhost:8080');
}

/// Fake AIRepository that returns configurable responses.
class FakeAIRepository extends AIRepository {
  String? chatResponse;
  Stream<String>? chatStreamResponse;

  final List<List<ChatMessage>> chatCalls = [];
  final List<List<ChatMessage>> chatStreamCalls = [];

  FakeAIRepository() : super(_StubApiClient());

  @override
  Future<String> chat(
    List<ChatMessage> messages, {
    String? model,
    CancelToken? cancelToken,
  }) async {
    chatCalls.add(messages);
    if (cancelToken?.isCancelled ?? false) {
      throw DioException.connectionError(
        requestOptions: RequestOptions(path: '/test'),
        reason: 'Cancelled',
      );
    }
    return chatResponse ?? 'default response';
  }

  @override
  Stream<String> chatStream(
    List<ChatMessage> messages, {
    String? model,
    CancelToken? cancelToken,
  }) {
    chatStreamCalls.add(messages);
    if (chatStreamResponse != null) return chatStreamResponse!;
    return Stream.fromIterable(['Hello ', 'world']);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ChatSessionNotifier', () {
    late ProviderContainer container;
    late FakeAIRepository fakeAiRepo;

    setUp(() {
      fakeAiRepo = FakeAIRepository();

      container = ProviderContainer(
        overrides: [
          aiRepositoryProvider.overrideWithValue(fakeAiRepo),
          apiClientProvider.overrideWithValue(_StubApiClient()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    // Helper: obtain the notifier from the provider system.
    ChatSessionNotifier getNotifier() {
      return container.read(chatSessionProvider.notifier);
    }

    // -- Initial state ---------------------------------------------------------

    test('initial state has non-empty session id', () {
      final notifier = getNotifier();
      expect(notifier.state.id, isNotEmpty);
    });

    test('initial state has empty title', () {
      final notifier = getNotifier();
      expect(notifier.state.title, isEmpty);
    });

    test('initial state has empty messages', () {
      final notifier = getNotifier();
      expect(notifier.state.messages, isEmpty);
    });

    test('initial state isLoading is false', () {
      final notifier = getNotifier();
      expect(notifier.state.isLoading, isFalse);
    });

    test('initial state error is null', () {
      final notifier = getNotifier();
      expect(notifier.state.error, isNull);
    });

    // -- setContextNotes -------------------------------------------------------

    test('setContextNotes updates contextNoteIds and contextNoteContents', () {
      final notifier = getNotifier();

      notifier.setContextNotes({
        'n1': 'note one content',
        'n2': 'note two content',
      });

      final state = notifier.state;
      expect(state.contextNoteIds, containsAll(['n1', 'n2']));
      expect(state.contextNoteContents['n1'], 'note one content');
      expect(state.contextNoteContents['n2'], 'note two content');
    });

    test('setContextNotes replaces previous context notes', () {
      final notifier = getNotifier();

      notifier.setContextNotes({'a': 'content a'});
      notifier.setContextNotes({'b': 'content b'});

      expect(notifier.state.contextNoteIds, ['b']);
      expect(notifier.state.contextNoteContents, {'b': 'content b'});
    });

    test('setContextNotes can clear notes by passing empty map', () {
      final notifier = getNotifier();

      notifier.setContextNotes({'a': 'content a'});
      notifier.setContextNotes({});

      expect(notifier.state.contextNoteIds, isEmpty);
      expect(notifier.state.contextNoteContents, isEmpty);
    });

    // -- sendMessage -- title derivation --------------------------------------

    test('sendMessage derives title from first user message (short)', () async {
      final notifier = getNotifier();

      fakeAiRepo.chatStreamResponse = Stream.fromIterable(['reply']);

      await notifier.sendMessage('Hello AI');

      expect(notifier.state.title, 'Hello AI');
    });

    test('sendMessage truncates long title to 50 chars with ellipsis',
        () async {
      final notifier = getNotifier();

      fakeAiRepo.chatStreamResponse = Stream.fromIterable(['reply']);

      final longMessage = 'A' * 60;
      await notifier.sendMessage(longMessage);

      expect(notifier.state.title.length, 53); // 50 chars + '...'
      expect(notifier.state.title, endsWith('...'));
      expect(
        notifier.state.title.substring(0, 50),
        longMessage.substring(0, 50),
      );
    });

    test('sendMessage does not overwrite existing title', () async {
      final notifier = getNotifier();

      fakeAiRepo.chatStreamResponse = Stream.fromIterable(['reply']);

      await notifier.sendMessage('First message');
      expect(notifier.state.title, 'First message');

      await notifier.sendMessage('Second message');
      expect(notifier.state.title, 'First message');
    });

    // -- sendMessage -- user and assistant messages ---------------------------

    test('sendMessage adds user message to state', () async {
      final notifier = getNotifier();

      fakeAiRepo.chatStreamResponse = Stream.fromIterable(['response']);

      await notifier.sendMessage('Hello');

      final messages =
          notifier.state.messages.whereType<chat.ChatMessage>().toList();
      expect(messages.length, 2); // user + assistant

      final userMsg = messages[0];
      expect(userMsg.role, 'user');
      expect(userMsg.content, 'Hello');
      expect(userMsg.isStreaming, isFalse);
    });

    test('sendMessage adds assistant message with streamed content', () async {
      final notifier = getNotifier();

      fakeAiRepo.chatStreamResponse =
          Stream.fromIterable(['Hello ', 'from ', 'AI']);

      await notifier.sendMessage('test');

      final messages =
          notifier.state.messages.whereType<chat.ChatMessage>().toList();
      final assistantMsg = messages[1];

      expect(assistantMsg.role, 'assistant');
      expect(assistantMsg.content, 'Hello from AI');
      expect(assistantMsg.isStreaming, isFalse);
    });

    test('sendMessage sets isLoading true during processing', () async {
      final notifier = getNotifier();

      // Create a slow stream so we can observe the loading state.
      final controller = StreamController<String>();
      fakeAiRepo.chatStreamResponse = controller.stream;

      final future = notifier.sendMessage('test');

      // While the stream is not complete, isLoading should be true.
      expect(notifier.state.isLoading, isTrue);

      // Complete the stream.
      controller.add('done');
      await controller.close();

      await future;

      expect(notifier.state.isLoading, isFalse);
    });

    test('sendMessage clears previous error', () async {
      final notifier = getNotifier();

      // First, cause an error.
      fakeAiRepo.chatStreamResponse = Stream.error(Exception('fail'));
      await notifier.sendMessage('cause error');

      expect(notifier.state.error, isNotNull);

      // Now send again with a working stream.
      fakeAiRepo.chatStreamResponse = Stream.fromIterable(['ok']);
      await notifier.sendMessage('retry');

      expect(notifier.state.error, isNull);
    });

    test('sendMessage ignores empty message', () async {
      final notifier = getNotifier();

      await notifier.sendMessage('');

      expect(notifier.state.messages, isEmpty);
      expect(fakeAiRepo.chatStreamCalls, isEmpty);
    });

    test('sendMessage ignores whitespace-only message', () async {
      final notifier = getNotifier();

      await notifier.sendMessage('   ');

      expect(notifier.state.messages, isEmpty);
      expect(fakeAiRepo.chatStreamCalls, isEmpty);
    });

    // -- sendMessage -- error handling ----------------------------------------

    test('sendMessage sets error on stream failure', () async {
      final notifier = getNotifier();

      fakeAiRepo.chatStreamResponse = Stream.error(Exception('Network down'));

      await notifier.sendMessage('test');

      expect(notifier.state.error, isNotNull);
      expect(notifier.state.error, contains('Network down'));
      expect(notifier.state.isLoading, isFalse);
    });

    test('sendMessage removes streaming assistant message on error', () async {
      final notifier = getNotifier();

      fakeAiRepo.chatStreamResponse = Stream.error(Exception('fail'));

      await notifier.sendMessage('test');

      final messages =
          notifier.state.messages.whereType<chat.ChatMessage>().toList();
      // Only the user message should remain; the empty streaming assistant
      // message should have been removed.
      expect(messages.length, 1);
      expect(messages[0].role, 'user');
    });

    test('sendMessage sets error on DioException cancel', () async {
      final notifier = getNotifier();

      fakeAiRepo.chatStreamResponse = Stream.error(
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/test'),
          reason: 'Cancelled',
        ),
      );

      await notifier.sendMessage('test');

      expect(notifier.state.error, isNotNull);
    });

    // -- cancel ---------------------------------------------------------------

    test('cancel does not throw when no active token', () {
      final notifier = getNotifier();

      // Should not throw.
      notifier.cancel();
    });

    // -- clearError -----------------------------------------------------------

    test('clearError removes error from state', () async {
      final notifier = getNotifier();

      // Cause an error.
      fakeAiRepo.chatStreamResponse = Stream.error(Exception('fail'));
      await notifier.sendMessage('test');

      expect(notifier.state.error, isNotNull);

      notifier.clearError();

      expect(notifier.state.error, isNull);
    });

    // -- Multiple messages (conversation history) -----------------------------

    test('consecutive sendMessages build conversation history', () async {
      final notifier = getNotifier();

      fakeAiRepo.chatStreamResponse = Stream.fromIterable(['First reply']);
      await notifier.sendMessage('Q1');

      fakeAiRepo.chatStreamResponse = Stream.fromIterable(['Second reply']);
      await notifier.sendMessage('Q2');

      final messages =
          notifier.state.messages.whereType<chat.ChatMessage>().toList();
      expect(messages.length, 4); // user1, assistant1, user2, assistant2
      expect(messages[0].role, 'user');
      expect(messages[0].content, 'Q1');
      expect(messages[1].role, 'assistant');
      expect(messages[1].content, 'First reply');
      expect(messages[2].role, 'user');
      expect(messages[2].content, 'Q2');
      expect(messages[3].role, 'assistant');
      expect(messages[3].content, 'Second reply');
    });

    test('consecutive sendMessages preserves title from first message',
        () async {
      final notifier = getNotifier();

      fakeAiRepo.chatStreamResponse = Stream.fromIterable(['R1']);
      await notifier.sendMessage('First Question');

      fakeAiRepo.chatStreamResponse = Stream.fromIterable(['R2']);
      await notifier.sendMessage('Second Question');

      expect(notifier.state.title, 'First Question');
    });

    // -- sendMessage does not send when already processing --------------------

    test('sendMessage is ignored when already processing', () async {
      final notifier = getNotifier();

      final controller = StreamController<String>();
      fakeAiRepo.chatStreamResponse = controller.stream;

      // Start first message (still processing).
      final future1 = notifier.sendMessage('first');

      // Try to send second message while first is in progress.
      await notifier.sendMessage('second');

      // Only one stream call should have been made.
      expect(fakeAiRepo.chatStreamCalls.length, 1);

      // Complete the first stream.
      controller.add('reply');
      await controller.close();
      await future1;
    });
  });

  // ===========================================================================
  // ChatSession model tests (via notifier integration)
  // ===========================================================================

  group('ChatSession copyWith in notifier context', () {
    test('copyWith error behavior matches ErrorMapper output', () {
      const session = ChatSession(
        id: 'test',
        error: 'Network error',
        isLoading: true,
      );

      // Simulate what the notifier does: clear error and loading.
      final updated = session.copyWith(error: null, isLoading: false);

      expect(updated.error, isNull);
      expect(updated.isLoading, isFalse);
      expect(updated.id, 'test');
    });
  });

  // ===========================================================================
  // Provider tests
  // ===========================================================================

  group('chatSessionProvider', () {
    test('creates a ChatSessionNotifier', () {
      final container = ProviderContainer(
        overrides: [
          aiRepositoryProvider.overrideWithValue(FakeAIRepository()),
          apiClientProvider.overrideWithValue(_StubApiClient()),
        ],
      );
      addTearDown(() => container.dispose());

      final notifier = container.read(chatSessionProvider.notifier);
      expect(notifier, isA<ChatSessionNotifier>());
    });

    test('initial state has a non-empty session id', () {
      final container = ProviderContainer(
        overrides: [
          aiRepositoryProvider.overrideWithValue(FakeAIRepository()),
          apiClientProvider.overrideWithValue(_StubApiClient()),
        ],
      );
      addTearDown(() => container.dispose());

      final state = container.read(chatSessionProvider);
      expect(state.id, isNotEmpty);
    });

    test('initial state has empty messages', () {
      final container = ProviderContainer(
        overrides: [
          aiRepositoryProvider.overrideWithValue(FakeAIRepository()),
          apiClientProvider.overrideWithValue(_StubApiClient()),
        ],
      );
      addTearDown(() => container.dispose());

      final state = container.read(chatSessionProvider);
      expect(state.messages, isEmpty);
    });
  });

  group('chatSessionIdProvider', () {
    test('initial state is null', () {
      final container = ProviderContainer(
        overrides: [
          aiRepositoryProvider.overrideWithValue(FakeAIRepository()),
          apiClientProvider.overrideWithValue(_StubApiClient()),
        ],
      );
      addTearDown(() => container.dispose());

      expect(container.read(chatSessionIdProvider), isNull);
    });
  });

  group('startChatSessionProvider', () {
    test('returns a function that generates a session id', () {
      final container = ProviderContainer(
        overrides: [
          aiRepositoryProvider.overrideWithValue(FakeAIRepository()),
          apiClientProvider.overrideWithValue(_StubApiClient()),
        ],
      );
      addTearDown(() => container.dispose());

      final startSession = container.read(startChatSessionProvider);
      final sessionId = startSession();

      expect(sessionId, isNotEmpty);
      // UUID v4 format.
      expect(
        sessionId,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('sets chatSessionIdProvider state', () {
      final container = ProviderContainer(
        overrides: [
          aiRepositoryProvider.overrideWithValue(FakeAIRepository()),
          apiClientProvider.overrideWithValue(_StubApiClient()),
        ],
      );
      addTearDown(() => container.dispose());

      final startSession = container.read(startChatSessionProvider);
      final sessionId = startSession();

      expect(container.read(chatSessionIdProvider), sessionId);
    });

    test('creates a different id each call', () {
      final container = ProviderContainer(
        overrides: [
          aiRepositoryProvider.overrideWithValue(FakeAIRepository()),
          apiClientProvider.overrideWithValue(_StubApiClient()),
        ],
      );
      addTearDown(() => container.dispose());

      final startSession = container.read(startChatSessionProvider);
      final id1 = startSession();
      final id2 = startSession();

      expect(id1, isNot(equals(id2)));
    });
  });
}
