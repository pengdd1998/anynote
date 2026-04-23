import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/error/error_mapper.dart';
import '../../../main.dart';
import '../data/ai_chat_repository.dart';
import '../domain/chat_message.dart';
import '../domain/chat_session.dart';

// ── Chat Session Notifier ─────────────────────────

/// Manages the active AI chat session state.
class ChatSessionNotifier extends StateNotifier<ChatSession> {
  final Ref _ref;
  CancelToken? _activeToken;
  bool _isProcessing = false;

  ChatSessionNotifier(this._ref, String sessionId)
      : super(ChatSession(id: sessionId));

  AIChatRepository get _chatRepo => _ref.read(aiChatRepositoryProvider);

  /// Cancel any in-flight AI operation.
  void cancel() {
    _activeToken?.cancel('Chat cancelled');
    _activeToken = null;
  }

  CancelToken _freshToken() {
    _activeToken?.cancel('Replaced by new request');
    _activeToken = CancelToken();
    return _activeToken!;
  }

  /// Set context notes for the chat session.
  void setContextNotes(Map<String, String> noteContents) {
    state = state.copyWith(
      contextNoteIds: noteContents.keys.toList(),
      contextNoteContents: noteContents,
    );
  }

  /// Send a user message and stream the AI response.
  Future<void> sendMessage(String userMessage) async {
    if (userMessage.trim().isEmpty) return;
    if (_isProcessing) return;

    _isProcessing = true;

    final userMsg = ChatMessage(
      role: 'user',
      content: userMessage,
      timestamp: DateTime.now(),
    );

    // Derive title from first user message.
    final title = state.title.isEmpty
        ? (userMessage.length > 50
            ? '${userMessage.substring(0, 50)}...'
            : userMessage)
        : state.title;

    // Add user message and a placeholder for the assistant response.
    final assistantMsg = ChatMessage(
      role: 'assistant',
      content: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    );

    state = state.copyWith(
      title: title,
      messages: [...state.messages, userMsg, assistantMsg],
      isLoading: true,
      error: null,
    );

    final token = _freshToken();

    try {
      final buffer = StringBuffer();
      await for (final chunk in _chatRepo.sendMessageStream(
        state,
        userMessage,
        cancelToken: token,
      )) {
        buffer.write(chunk);
        // Update the last message (assistant) with accumulated content.
        final updatedMessages = List<dynamic>.from(state.messages);
        if (updatedMessages.isNotEmpty) {
          final lastMsg = updatedMessages.last as ChatMessage;
          updatedMessages[updatedMessages.length - 1] = lastMsg.copyWith(
            content: buffer.toString(),
          );
        }
        state = state.copyWith(messages: updatedMessages);
      }

      // Finalize: mark streaming as complete.
      final finalizedMessages = List<dynamic>.from(state.messages);
      if (finalizedMessages.isNotEmpty) {
        final lastMsg = finalizedMessages.last as ChatMessage;
        finalizedMessages[finalizedMessages.length - 1] = lastMsg.copyWith(
          isStreaming: false,
        );
      }

      state = state.copyWith(
        messages: finalizedMessages,
        isLoading: false,
      );
    } catch (e) {
      final appError = ErrorMapper.map(e);
      // Remove the empty assistant message on error.
      final messages = List<dynamic>.from(state.messages);
      if (messages.isNotEmpty && (messages.last as ChatMessage).isStreaming) {
        messages.removeLast();
      }
      state = state.copyWith(
        messages: messages,
        isLoading: false,
        error: appError.message,
      );
    } finally {
      _isProcessing = false;
    }
  }

  /// Clear the error message.
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ── Providers ─────────────────────────────────────

/// Holds the active chat session ID. Null when no session is active.
final chatSessionIdProvider = StateProvider<String?>((ref) => null);

/// Provides the ChatSessionNotifier for the current session.
final chatSessionProvider =
    StateNotifierProvider<ChatSessionNotifier, ChatSession>((ref) {
  var sessionId = ref.watch(chatSessionIdProvider);
  sessionId ??= const Uuid().v4();
  return ChatSessionNotifier(ref, sessionId);
});

/// Starts a new chat session, returning the session ID.
final startChatSessionProvider = Provider<String Function()>((ref) {
  return () {
    final sessionId = const Uuid().v4();
    ref.read(chatSessionIdProvider.notifier).state = sessionId;
    return sessionId;
  };
});

/// Provides the list of notes for context selection in AI chat.
final notesForChatContextProvider = StreamProvider<List<dynamic>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.notesDao.watchAllNotes();
});
