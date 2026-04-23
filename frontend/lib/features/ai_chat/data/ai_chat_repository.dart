import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../compose/data/ai_repository.dart' as compose
    show AIRepository, ChatMessage, aiRepositoryProvider;
import '../domain/chat_message.dart';
import '../domain/chat_session.dart';

/// Repository for AI chat operations.
/// Manages conversation state and communicates with the LLM proxy.
class AIChatRepository {
  final compose.AIRepository _aiRepo;

  AIChatRepository(this._aiRepo);

  /// Build the system prompt for a chat session, including note context
  /// if context notes were selected.
  String _buildSystemPrompt(ChatSession session) {
    final buffer = StringBuffer();
    buffer.writeln(
      'You are a helpful AI assistant integrated into a note-taking app. '
      'Answer questions based on the context provided. '
      'Be concise, accurate, and helpful. '
      'If context notes are provided, reference them when relevant.',
    );

    if (session.contextNoteContents.isNotEmpty) {
      buffer.writeln('\n--- User\'s Notes (Context) ---');
      for (final entry in session.contextNoteContents.entries) {
        buffer.writeln('\n[Note]:');
        buffer.writeln(entry.value);
      }
      buffer.writeln('\n--- End of Notes ---');
    }

    return buffer.toString();
  }

  /// Convert a domain [ChatMessage] to the compose layer format.
  compose.ChatMessage _toComposeMessage(ChatMessage msg) {
    return compose.ChatMessage(role: msg.role, content: msg.content);
  }

  /// Send a user message and get the full response (non-streaming).
  Future<String> sendMessage(
    ChatSession session,
    String userMessage, {
    CancelToken? cancelToken,
  }) async {
    final systemPrompt = _buildSystemPrompt(session);
    final apiMessages = <compose.ChatMessage>[
      compose.ChatMessage(role: 'system', content: systemPrompt),
      ...session.messages.whereType<ChatMessage>().map(_toComposeMessage),
      compose.ChatMessage(role: 'user', content: userMessage),
    ];

    return _aiRepo.chat(
      apiMessages,
      cancelToken: cancelToken,
    );
  }

  /// Send a user message and receive streaming response chunks.
  Stream<String> sendMessageStream(
    ChatSession session,
    String userMessage, {
    CancelToken? cancelToken,
  }) async* {
    final systemPrompt = _buildSystemPrompt(session);

    final allMessages = <compose.ChatMessage>[
      compose.ChatMessage(role: 'system', content: systemPrompt),
      ...session.messages.whereType<ChatMessage>().map(_toComposeMessage),
      compose.ChatMessage(role: 'user', content: userMessage),
    ];

    await for (final chunk in _aiRepo.chatStream(
      allMessages,
      cancelToken: cancelToken,
    )) {
      yield chunk;
    }
  }
}

final aiChatRepositoryProvider = Provider<AIChatRepository>((ref) {
  return AIChatRepository(ref.read(compose.aiRepositoryProvider));
});

/// Creates a new chat session ID.
final newChatSessionIdProvider = Provider<String Function()>((ref) {
  return () => const Uuid().v4();
});
