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

  const DecryptedNote({
    required this.title,
    required this.content,
    required this.updatedAt,
    required this.isSynced,
  });
}
