import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../main.dart';
import '../../settings/data/api_models.dart';
import '../../settings/data/llm_direct_client.dart';
import '../../settings/data/local_llm_store.dart';

/// Repository for AI chat calls.
///
/// Dual-mode routing:
/// - When the user has a locally stored default LLM config (with a non-empty
///   base URL), chat calls go DIRECTLY from the client to the provider. The
///   API key never reaches AnyNote servers.
/// - Otherwise the server proxy (`/api/v1/ai/proxy`) is used — the shared-mode
///   fallback with the shared LLM and its rate limits.
class AIRepository {
  /// Sentinel returned by [parseSseLine] for the SSE terminating event.
  static const String _doneMarker = '[DONE]';

  final ApiClient _apiClient;

  /// Resolves the user's default locally stored LLM config. When it returns a
  /// config with a non-empty base URL, requests go client-direct; when null,
  /// the server proxy is used. Wired to [LocalLlmStore.getDefault] in prod.
  final Future<LlmConfig?> Function()? resolveDefaultConfig;

  final LlmDirectClient _directClient;

  AIRepository(
    this._apiClient, {
    this.resolveDefaultConfig,
    LlmDirectClient? directClient,
  }) : _directClient = directClient ?? LlmDirectClient();

  /// Send a non-streaming chat request.
  Future<String> chat(
    List<ChatMessage> messages, {
    String? model,
    CancelToken? cancelToken,
  }) async {
    final cfg = await _resolveLocalConfig();
    if (cfg != null) {
      // Direct mode: client -> provider (OpenAI-compatible endpoint).
      return _directClient.chat(
        baseUrl: cfg.baseUrl!,
        apiKey: cfg.apiKey ?? '',
        model: model ?? cfg.model,
        messages: _encodeMessages(messages),
        cancelToken: cancelToken,
      );
    }

    // Shared mode: route through the server proxy.
    final response = await _apiClient
        .aiProxy(
          {
            'messages': _encodeMessages(messages),
            if (model != null) 'model': model,
            'stream': false,
          },
          cancelToken: cancelToken,
        )
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw TimeoutException('AI request timed out'),
        );
    final content = response['content'];
    if (content == null) {
      throw FormatException(
        'AI proxy returned unexpected response: ${response.keys.join(', ')}',
      );
    }
    return content as String;
  }

  /// Send a streaming chat request.
  /// Returns Stream<String> of content chunks.
  Stream<String> chatStream(
    List<ChatMessage> messages, {
    String? model,
    CancelToken? cancelToken,
  }) async* {
    final cfg = await _resolveLocalConfig();
    Stream<List<int>> rawStream;
    if (cfg != null) {
      // Direct mode: client -> provider (OpenAI-compatible endpoint).
      rawStream = await _directClient.chatStream(
        baseUrl: cfg.baseUrl!,
        apiKey: cfg.apiKey ?? '',
        model: model ?? cfg.model,
        messages: _encodeMessages(messages),
        cancelToken: cancelToken,
      );
    } else {
      // Shared mode: route through the server proxy.
      final response = await _apiClient.aiProxyStream(
        {
          'messages': _encodeMessages(messages),
          if (model != null) 'model': model,
          'stream': true,
        },
        cancelToken: cancelToken,
      );
      final proxyStream = response.data?.stream;
      if (proxyStream == null) {
        throw FormatException('AI proxy stream returned no data');
      }
      rawStream = proxyStream;
    }

    // Per-chunk timeout: if no data arrives within 60 seconds, close the
    // stream to prevent indefinite hangs when the provider/server stops
    // responding.
    final stream = rawStream.timeout(
      const Duration(seconds: 60),
      onTimeout: (EventSink<List<int>> sink) {
        debugPrint('[AIRepository] Stream timeout - no data for 60s, closing');
        sink.close();
      },
    );

    yield* parseSseContentStream(stream);
  }

  /// Resolve the default local config for direct calls, or null when the
  /// server proxy (shared mode) should be used.
  Future<LlmConfig?> _resolveLocalConfig() async {
    final resolver = resolveDefaultConfig;
    if (resolver == null) return null;
    final cfg = await resolver();
    if (cfg == null) return null;
    final base = cfg.baseUrl;
    if (base == null || base.isEmpty) return null;
    return cfg;
  }

  List<Map<String, String>> _encodeMessages(List<ChatMessage> messages) =>
      messages.map((m) => {'role': m.role, 'content': m.content}).toList();

  /// Extract content chunks from an SSE byte stream.
  ///
  /// Buffers bytes across network chunks: an SSE line may be split by TCP at
  /// any boundary (including mid-JSON or mid-UTF-8 multibyte character), so
  /// each chunk must be appended to the pending buffer and only complete
  /// newline-terminated lines decoded.
  static Stream<String> parseSseContentStream(Stream<List<int>> stream) async* {
    var pending = <int>[];

    await for (final chunk in stream) {
      pending.addAll(chunk);
      while (true) {
        final nl = pending.indexOf(10); // '\n'
        if (nl < 0) break;
        // Strip a preceding '\r' for CRLF servers.
        var end = nl;
        if (end > 0 && pending[end - 1] == 13) end--;
        final lineBytes = pending.sublist(0, end);
        pending = pending.sublist(nl + 1);

        final content = parseSseLine(utf8.decode(lineBytes, allowMalformed: true));
        if (content == _doneMarker) return;
        if (content != null) yield content;
      }
    }
  }

  /// Parse one SSE line; returns the extracted content, [_doneMarker] for the
  /// terminating event, or null for lines carrying no content.
  ///
  /// Supports two formats:
  /// - Server proxy: `data: {"content": "..."}`
  /// - OpenAI-compatible (direct mode): `data: {"choices":[{"delta":{
  ///   "content":"..."}}]}`; `data: [DONE]` terminates in both formats.
  static String? parseSseLine(String line) {
    if (!line.startsWith('data: ')) return null;
    final jsonStr = line.substring(6).trim();
    if (jsonStr.isEmpty) return null;
    if (jsonStr == '[DONE]') return _doneMarker;
    try {
      final json = jsonDecode(jsonStr);
      if (json is! Map) return null;
      final content = json['content'];
      if (content is String) return content;
      // OpenAI-compatible delta format (streaming).
      final choices = json['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map) {
          final delta = first['delta'];
          if (delta is Map) {
            final deltaContent = delta['content'];
            if (deltaContent is String) return deltaContent;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('[AIRepository] SSE parse error: $e');
      return null;
    }
  }

  /// Get current AI quota.
  Future<Map<String, dynamic>> getQuota() async {
    return _apiClient.getAiQuota();
  }
}

class ChatMessage {
  final String role;
  final String content;

  const ChatMessage({required this.role, required this.content});
}

final aiRepositoryProvider = Provider<AIRepository>((ref) {
  return AIRepository(
    ref.read(apiClientProvider),
    // Direct mode resolution: the default device-local LLM config. Null when
    // the user has no local config -> server proxy (shared mode).
    resolveDefaultConfig: () => ref.read(localLlmStoreProvider).getDefault(),
  );
});
