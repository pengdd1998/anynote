import 'package:dio/dio.dart';

/// Client for direct client-to-provider chat calls against OpenAI-compatible
/// APIs.
///
/// Used when the user has a locally stored LLM config: API keys never touch
/// AnyNote servers, so requests go straight from the device to
/// `{baseUrl}/chat/completions`. The AnyNote server proxy is only used as the
/// shared-mode fallback when no local config exists.
///
/// Provider note: 'anthropic' configs are treated as OpenAI-compatible too —
/// Anthropic exposes an OpenAI-compatible chat endpoint under the same
/// `/v1` base URL.
///
/// Privacy: this client never logs request or response bodies; they can
/// contain decrypted note content and API keys.
class LlmDirectClient {
  LlmDirectClient({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 120),
              ),
            );

  final Dio _dio;

  /// Non-streaming chat completion; returns the assistant message content.
  ///
  /// Throws on transport errors and [FormatException] when the provider
  /// answers with an unexpected response shape.
  Future<String> chat({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<Map<String, String>> messages,
    CancelToken? cancelToken,
  }) async {
    final res = await _dio.post<dynamic>(
      '${_normalizedBaseUrl(baseUrl)}/chat/completions',
      data: {'model': model, 'messages': messages, 'stream': false},
      options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) {
      final choices = data['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map) {
          final message = first['message'];
          if (message is Map) {
            final content = message['content'];
            if (content is String) return content;
          }
        }
      }
    }
    throw const FormatException(
      'Chat completion response had an unexpected shape',
    );
  }

  /// Streaming chat completion; returns the raw SSE byte stream for the
  /// caller's SSE parser (OpenAI delta chunks terminate with `data: [DONE]`).
  Future<Stream<List<int>>> chatStream({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<Map<String, String>> messages,
    CancelToken? cancelToken,
  }) async {
    final res = await _dio.post<ResponseBody>(
      '${_normalizedBaseUrl(baseUrl)}/chat/completions',
      data: {'model': model, 'messages': messages, 'stream': true},
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Accept': 'text/event-stream',
        },
      ),
      cancelToken: cancelToken,
    );
    final body = res.data;
    if (body == null) {
      throw const FormatException('Chat completion stream returned no data');
    }
    return body.stream;
  }

  /// Client-direct connectivity test: a tiny chat completion against the
  /// config's own base URL. Returns normally when the provider answered
  /// 200 with a usable completion; throws otherwise.
  Future<void> testConnection({
    required String baseUrl,
    required String apiKey,
    required String model,
  }) async {
    await chat(
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      messages: const [
        {'role': 'user', 'content': 'Reply with OK'},
      ],
    );
  }

  String _normalizedBaseUrl(String baseUrl) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return base;
  }
}
