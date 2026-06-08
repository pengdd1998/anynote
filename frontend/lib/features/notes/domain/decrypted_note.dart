/// Simple data class for a decrypted note's display properties.
///
/// Used across multiple screens (notes list detail pane, note detail screen)
/// to represent a note after decryption.
class DecryptedNote {
  /// The decrypted or plain-text title of the note.
  final String title;

  /// The decrypted or plain-text content of the note (markdown).
  final String content;

  /// When the note was last updated.
  final DateTime updatedAt;

  /// Whether the note has been synced to the server.
  final bool isSynced;

  /// Tags associated with this note (optional, loaded on demand).
  final List<dynamic> tags;

  const DecryptedNote({
    required this.title,
    required this.content,
    required this.updatedAt,
    required this.isSynced,
    this.tags = const [],
  });

  DecryptedNote copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
    bool? isSynced,
    List<dynamic>? tags,
  }) {
    return DecryptedNote(
      title: title ?? this.title,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      tags: tags ?? this.tags,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DecryptedNote &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          content == other.content &&
          updatedAt == other.updatedAt &&
          isSynced == other.isSynced;

  @override
  int get hashCode => Object.hash(title, content, updatedAt, isSynced);
}
