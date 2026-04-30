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

  /// Maximum conversation history messages sent to the LLM (excluding system).
  /// Older messages are dropped to stay within context window limits.
  static const int _maxHistoryMessages = 40;

  /// Approximate character limit for the entire message payload.
  /// Prevents hitting API token limits with very long conversations.
  static const int _maxPayloadChars = 100000;

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
    final apiMessages = _buildApiMessages(session, userMessage);
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
    final apiMessages = _buildApiMessages(session, userMessage);
    await for (final chunk in _aiRepo.chatStream(
      apiMessages,
      cancelToken: cancelToken,
    )) {
      yield chunk;
    }
  }

  /// Builds the complete message list with system prompt, truncated history,
  /// and the new user message. Applies both message count and character limits.
  List<compose.ChatMessage> _buildApiMessages(
    ChatSession session,
    String userMessage,
  ) {
    final systemPrompt = _buildSystemPrompt(session);
    final history = session.messages
        .whereType<ChatMessage>()
        .map(_toComposeMessage)
        .toList();

    // Keep only the most recent messages within the limit.
    final truncated = history.length > _maxHistoryMessages
        ? history.sublist(history.length - _maxHistoryMessages)
        : history;

    final messages = <compose.ChatMessage>[
      compose.ChatMessage(role: 'system', content: systemPrompt),
      ...truncated,
      compose.ChatMessage(role: 'user', content: userMessage),
    ];

    // If total payload exceeds character budget, trim oldest messages further.
    return _trimToCharLimit(messages, _maxPayloadChars);
  }

  /// Trims messages from the front (after system prompt) until the total
  /// character count is within [maxChars]. The system prompt and user message
  /// are always preserved.
  static List<compose.ChatMessage> _trimToCharLimit(
    List<compose.ChatMessage> messages,
    int maxChars,
  ) {
    int totalChars() => messages.fold<int>(
          0,
          (sum, m) => sum + m.content.length,
        );

    if (totalChars() <= maxChars) return messages;

    // Keep system (index 0) and user message (last), trim middle.
    final system = messages.first;
    final user = messages.last;
    final middle = messages.sublist(1, messages.length - 1);

    var budget = maxChars - system.content.length - user.content.length;
    final kept = <compose.ChatMessage>[];
    for (var i = middle.length - 1; i >= 0 && budget > 0; i--) {
      kept.insert(0, middle[i]);
      budget -= middle[i].content.length;
    }

    return [system, ...kept, user];
  }
}

final aiChatRepositoryProvider = Provider<AIChatRepository>((ref) {
  return AIChatRepository(ref.read(compose.aiRepositoryProvider));
});

/// Creates a new chat session ID.
final newChatSessionIdProvider = Provider<String Function()>((ref) {
  return () => const Uuid().v4();
});
