import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/features/compose/data/ai_repository.dart';
import 'package:anynote/features/settings/data/api_models.dart';
import 'package:anynote/features/settings/data/llm_direct_client.dart';

/// Stub ApiClient that records proxy calls (server shared mode).
class _StubApiClient extends ApiClient {
  _StubApiClient() : super(baseUrl: 'http://localhost:8080');

  final List<Map<String, dynamic>> proxyCalls = [];
  final List<Map<String, dynamic>> proxyStreamCalls = [];

  @override
  Future<Map<String, dynamic>> aiProxy(
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
  }) async {
    proxyCalls.add(body);
    return {'content': 'proxy reply'};
  }

  @override
  Future<Response<ResponseBody>> aiProxyStream(
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
  }) async {
    proxyStreamCalls.add(body);
    return Response<ResponseBody>(
      requestOptions: RequestOptions(path: '/api/v1/ai/proxy'),
      data: ResponseBody(
        Stream.value(
          Uint8List.fromList(
            utf8.encode('data: {"content":"proxy chunk"}\ndata: [DONE]\n'),
          ),
        ),
        200,
      ),
    );
  }
}

/// Direct client that records calls instead of performing HTTP requests.
class _RecordingDirectClient extends LlmDirectClient {
  _RecordingDirectClient() : super(dio: Dio());

  final List<Map<String, String>> chats = [];
  final List<Map<String, String>> streams = [];

  @override
  Future<String> chat({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<Map<String, String>> messages,
    CancelToken? cancelToken,
  }) async {
    chats.add({'baseUrl': baseUrl, 'apiKey': apiKey, 'model': model});
    return 'direct reply';
  }

  @override
  Future<Stream<List<int>>> chatStream({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<Map<String, String>> messages,
    CancelToken? cancelToken,
  }) async {
    streams.add({'baseUrl': baseUrl, 'apiKey': apiKey, 'model': model});
    return Stream.fromIterable([
      Uint8List.fromList(
        utf8.encode('data: {"choices":[{"delta":{"content":"hi"}}]}\n'),
      ),
      Uint8List.fromList(utf8.encode('data: [DONE]\n')),
    ]);
  }
}

LlmConfig _localConfig({String? baseUrl = 'https://api.example.com/v1'}) =>
    LlmConfig(
      id: 'cfg-1',
      name: 'My GPT',
      provider: 'openai',
      baseUrl: baseUrl,
      apiKey: 'sk-local',
      model: 'gpt-4o',
      isDefault: true,
      maxTokens: 4096,
      temperature: 0.7,
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );

void main() {
  group('AIRepository direct mode routing', () {
    late _StubApiClient api;
    late _RecordingDirectClient direct;

    AIRepository repo(Future<LlmConfig?> Function() resolver) =>
        AIRepository(api, resolveDefaultConfig: resolver, directClient: direct);

    setUp(() {
      api = _StubApiClient();
      direct = _RecordingDirectClient();
    });

    test('chat goes DIRECT to the provider when a local default config exists',
        () async {
      final reply = await repo(() async => _localConfig()).chat(
        const [ChatMessage(role: 'user', content: 'hello')],
      );

      expect(reply, 'direct reply');
      expect(direct.chats, hasLength(1));
      expect(direct.chats.single['baseUrl'], 'https://api.example.com/v1');
      // The locally stored API key is used for the direct call.
      expect(direct.chats.single['apiKey'], 'sk-local');
      expect(direct.chats.single['model'], 'gpt-4o');
      // The server proxy must not be touched in direct mode.
      expect(api.proxyCalls, isEmpty);
    });

    test('an explicit model override wins over the stored config model',
        () async {
      await repo(() async => _localConfig()).chat(
        const [ChatMessage(role: 'user', content: 'hello')],
        model: 'gpt-4o-mini',
      );

      expect(direct.chats.single['model'], 'gpt-4o-mini');
    });

    test('chat falls back to the server proxy when no local config exists',
        () async {
      final reply = await repo(() async => null).chat(
        const [ChatMessage(role: 'user', content: 'hello')],
      );

      expect(reply, 'proxy reply');
      expect(api.proxyCalls, hasLength(1));
      expect(direct.chats, isEmpty);
    });

    test(
        'chat falls back to the server proxy when the config has no base URL',
        () async {
      final reply = await repo(() async => _localConfig(baseUrl: null)).chat(
        const [ChatMessage(role: 'user', content: 'hello')],
      );

      expect(reply, 'proxy reply');
      expect(api.proxyCalls, hasLength(1));
      expect(direct.chats, isEmpty);
    });

    test('chatStream streams OpenAI delta chunks in direct mode', () async {
      final out = await repo(() async => _localConfig())
          .chatStream(const [ChatMessage(role: 'user', content: 'hello')])
          .join();

      expect(out, 'hi');
      expect(direct.streams, hasLength(1));
      expect(api.proxyStreamCalls, isEmpty);
    });

    test('chatStream falls back to the server proxy without a local config',
        () async {
      final out = await repo(() async => null)
          .chatStream(const [ChatMessage(role: 'user', content: 'hello')])
          .join();

      expect(out, 'proxy chunk');
      expect(api.proxyStreamCalls, hasLength(1));
      expect(direct.streams, isEmpty);
    });
  });
}
