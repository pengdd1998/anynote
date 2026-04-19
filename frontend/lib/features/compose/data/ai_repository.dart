import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../main.dart';

/// Repository for AI proxy calls.
/// Communicates with server's /api/v1/ai/proxy endpoint.
class AIRepository {
  final ApiClient _apiClient;

  AIRepository(this._apiClient);

  /// Send a non-streaming chat request.
  Future<String> chat(List<ChatMessage> messages, {String? model}) async {
    final response = await _apiClient.aiProxy({
      'messages': messages.map((m) => {'role': m.role, 'content': m.content}).toList(),
      if (model != null) 'model': model,
      'stream': false,
    });
    return response['content'] as String;
  }

  /// Send a streaming chat request.
  /// Returns Stream<String> of content chunks.
  Stream<String> chatStream(List<ChatMessage> messages, {String? model}) async* {
    final response = await _apiClient.aiProxyStream({
      'messages': messages.map((m) => {'role': m.role, 'content': m.content}).toList(),
      if (model != null) 'model': model,
      'stream': true,
    });

    final stream = response.data?.stream;
    if (stream == null) return;

    await for (final chunk in stream) {
      final data = utf8.decode(chunk);
      // Parse SSE format
      for (final line in data.split('\n')) {
        if (line.startsWith('data: ')) {
          final jsonStr = line.substring(6);
          if (jsonStr == '[DONE]') return;
          try {
            final json = jsonDecode(jsonStr);
            if (json['content'] != null) {
              yield json['content'] as String;
            }
          } catch (_) {}
        }
      }
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
