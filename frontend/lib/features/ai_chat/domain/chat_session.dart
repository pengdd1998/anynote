import 'package:collection/collection.dart';

/// Model for an AI chat session.
///
/// Tracks the in-memory conversation history and optional context notes
/// that the user selected before starting the chat.
class ChatSession {
  /// Unique session identifier.
  final String id;

  /// Display title for the session (derived from first user message).
  final String title;

  /// IDs of notes selected as context for this session.
  final List<String> contextNoteIds;

  /// Plaintext content of context notes, keyed by note ID.
  final Map<String, String> contextNoteContents;

  /// Conversation messages in chronological order.
  final List<dynamic> messages;

  /// Whether an AI response is currently being generated.
  final bool isLoading;

  /// Error message to display, if any.
  final String? error;

  const ChatSession({
    required this.id,
    this.title = '',
    this.contextNoteIds = const [],
    this.contextNoteContents = const {},
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatSession &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          const DeepCollectionEquality()
              .equals(contextNoteIds, other.contextNoteIds) &&
          const DeepCollectionEquality()
              .equals(contextNoteContents, other.contextNoteContents) &&
          const DeepCollectionEquality().equals(messages, other.messages) &&
          isLoading == other.isLoading &&
          error == other.error;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        Object.hashAll(contextNoteIds),
        Object.hashAllUnordered(contextNoteContents.entries),
        Object.hashAll(messages),
        isLoading,
        error,
      );

  ChatSession copyWith({
    String? title,
    List<String>? contextNoteIds,
    Map<String, String>? contextNoteContents,
    List<dynamic>? messages,
    bool? isLoading,
    String? error,
  }) {
    return ChatSession(
      id: id,
      title: title ?? this.title,
      contextNoteIds: contextNoteIds ?? this.contextNoteIds,
      contextNoteContents: contextNoteContents ?? this.contextNoteContents,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
