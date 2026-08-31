import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../main.dart';

/// Repository for AI proxy calls.
/// Communicates with server's /api/v1/ai/proxy endpoint.
class AIRepository {
  /// Sentinel returned by [parseSseLine] for the SSE terminating event.
  static const String _doneMarker = '[DONE]';

  final ApiClient _apiClient;

  AIRepository(this._apiClient);

  /// Send a non-streaming chat request.
  Future<String> chat(
    List<ChatMessage> messages, {
    String? model,
    CancelToken? cancelToken,
  }) async {
    final response = await _apiClient
        .aiProxy(
          {
            'messages': messages
                .map((m) => {'role': m.role, 'content': m.content})
                .toList(),
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
    final response = await _apiClient.aiProxyStream(
      {
        'messages': messages
            .map((m) => {'role': m.role, 'content': m.content})
            .toList(),
        if (model != null) 'model': model,
        'stream': true,
      },
      cancelToken: cancelToken,
    );

    final rawStream = response.data?.stream;
    if (rawStream == null) {
      throw FormatException('AI proxy stream returned no data');
    }

    // Per-chunk timeout: if no data arrives within 60 seconds, close the
    // stream to prevent indefinite hangs when the server stops responding.
    final stream = rawStream.timeout(
      const Duration(seconds: 60),
      onTimeout: (EventSink<List<int>> sink) {
        debugPrint('[AIRepository] Stream timeout - no data for 60s, closing');
        sink.close();
      },
    );

    yield* parseSseContentStream(stream);
  }

  /// Extract content chunks from the proxy's SSE byte stream.
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
  static String? parseSseLine(String line) {
    if (!line.startsWith('data: ')) return null;
    final jsonStr = line.substring(6).trim();
    if (jsonStr.isEmpty) return null;
    if (jsonStr == '[DONE]') return _doneMarker;
    try {
      final json = jsonDecode(jsonStr);
      final content = json['content'];
      if (content is String) return content;
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
  return AIRepository(ref.read(apiClientProvider));
});
