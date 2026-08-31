import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/compose/data/ai_repository.dart';
import 'package:anynote/features/settings/data/llm_direct_client.dart';

/// Dio adapter that records requests and returns canned responses, so the
/// direct client is tested without any real network access.
class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

LlmDirectClient _clientWith(_MockAdapter adapter) {
  final dio = Dio();
  dio.httpClientAdapter = adapter;
  return LlmDirectClient(dio: dio);
}

void main() {
  group('LlmDirectClient', () {
    test('chat posts an OpenAI-compatible completion and returns content',
        () async {
      final adapter = _MockAdapter(
        (options) => ResponseBody.fromString(
          jsonEncode({
            'id': 'cmpl-1',
            'choices': [
              {
                'index': 0,
                'message': {'role': 'assistant', 'content': 'OK'},
              }
            ],
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      final client = _clientWith(adapter);

      final content = await client.chat(
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'sk-secret',
        model: 'gpt-4o',
        messages: const [
          {'role': 'user', 'content': 'Reply with OK'},
        ],
      );

      expect(content, 'OK');
      expect(adapter.requests, hasLength(1));
      final req = adapter.requests.single;
      expect(req.uri.toString(),
          'https://api.example.com/v1/chat/completions');
      expect(req.headers['Authorization'], 'Bearer sk-secret');
      final body = req.data as Map;
      expect(body['model'], 'gpt-4o');
      expect(body['stream'], false);
      expect(
        (body['messages'] as List).single,
        {
          'role': 'user',
          'content': 'Reply with OK',
        },
      );
    });

    test('chat normalizes a trailing slash in the base URL', () async {
      final adapter = _MockAdapter(
        (options) => ResponseBody.fromString(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'hi'},
              }
            ],
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      final client = _clientWith(adapter);

      await client.chat(
        baseUrl: 'https://api.example.com/v1/',
        apiKey: 'k',
        model: 'm',
        messages: const [
          {'role': 'user', 'content': 'hi'},
        ],
      );

      expect(
        adapter.requests.single.uri.toString(),
        'https://api.example.com/v1/chat/completions',
      );
    });

    test('chat throws FormatException on an unexpected response shape',
        () async {
      final adapter = _MockAdapter(
        (options) => ResponseBody.fromString(
          jsonEncode({'unexpected': 'shape'}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      final client = _clientWith(adapter);

      await expectLater(
        client.chat(
          baseUrl: 'https://api.example.com/v1',
          apiKey: 'k',
          model: 'm',
          messages: const [
            {'role': 'user', 'content': 'hi'},
          ],
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('testConnection succeeds when the provider answers 200 with choices',
        () async {
      final adapter = _MockAdapter(
        (options) => ResponseBody.fromString(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'OK'},
              }
            ],
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      final client = _clientWith(adapter);

      await expectLater(
        client.testConnection(
          baseUrl: 'https://api.example.com/v1',
          apiKey: 'k',
          model: 'm',
        ),
        completes,
      );
      // The test sends the tiny probe message.
      expect(
        ((adapter.requests.single.data as Map)['messages'] as List).single['content'],
        'Reply with OK',
      );
    });

    test('testConnection throws when the provider rejects the key', () async {
      final adapter = _MockAdapter(
        (options) => ResponseBody.fromString(
          jsonEncode({'error': {'message': 'bad key'}}),
          401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      final client = _clientWith(adapter);

      await expectLater(
        client.testConnection(
          baseUrl: 'https://api.example.com/v1',
          apiKey: 'k',
          model: 'm',
        ),
        throwsA(isA<DioException>()),
      );
    });

    test('chatStream returns the raw SSE byte stream', () async {
      final adapter = _MockAdapter(
        (options) => ResponseBody(
          Stream.value(
            Uint8List.fromList(utf8.encode(
              'data: {"choices":[{"delta":{"content":"hi"}}]}\n'
              'data: [DONE]\n',
            )),
          ),
          200,
          headers: {
            Headers.contentTypeHeader: ['text/event-stream'],
          },
        ),
      );
      final client = _clientWith(adapter);

      final byteStream = await client.chatStream(
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'k',
        model: 'm',
        messages: const [
          {'role': 'user', 'content': 'hi'},
        ],
      );

      // The stream body must request SSE streaming.
      expect((adapter.requests.single.data as Map)['stream'], true);
      final content =
          await AIRepository.parseSseContentStream(byteStream).join();
      expect(content, 'hi');
    });
  });
}
