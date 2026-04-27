/// Model for a single message in an AI chat conversation.
class ChatMessage {
  /// Role: 'system', 'user', or 'assistant'.
  final String role;

  /// Text content of the message.
  final String content;

  /// When this message was created.
  final DateTime timestamp;

  /// Whether this message is currently being streamed (partial).
  final bool isStreaming;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.isStreaming = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          role == other.role &&
          content == other.content &&
          timestamp == other.timestamp &&
          isStreaming == other.isStreaming;

  @override
  int get hashCode => Object.hash(role, content, timestamp, isStreaming);

  ChatMessage copyWith({
    String? role,
    String? content,
    DateTime? timestamp,
    bool? isStreaming,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  /// Convert to the map format expected by the AI proxy API.
  Map<String, String> toApiMap() {
    return {'role': role, 'content': content};
  }
}
