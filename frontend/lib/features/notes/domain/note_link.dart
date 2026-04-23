/// NoteLink model representing a bidirectional link between two notes.
class NoteLink {
  final String id;
  final String sourceId;
  final String targetId;
  final String linkType;
  final DateTime createdAt;

  const NoteLink({
    required this.id,
    required this.sourceId,
    required this.targetId,
    required this.linkType,
    required this.createdAt,
  });

  factory NoteLink.fromJson(Map<String, dynamic> json) => NoteLink(
        id: json['id'] as String,
        sourceId: json['source_id'] as String,
        targetId: json['target_id'] as String,
        linkType: json['link_type'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'source_id': sourceId,
        'target_id': targetId,
        'link_type': linkType,
      };
}
