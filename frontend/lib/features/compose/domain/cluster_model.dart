import 'package:collection/collection.dart';

class ClusterModel {
  final String name;
  final String theme;
  final List<int> noteIndices;
  final String summary;

  const ClusterModel({
    required this.name,
    required this.theme,
    required this.noteIndices,
    required this.summary,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClusterModel &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          theme == other.theme &&
          const DeepCollectionEquality()
              .equals(noteIndices, other.noteIndices) &&
          summary == other.summary;

  @override
  int get hashCode =>
      Object.hash(name, theme, Object.hashAll(noteIndices), summary);

  factory ClusterModel.fromJson(Map<String, dynamic> json) => ClusterModel(
        name: json['name'] as String,
        theme: json['theme'] as String,
        noteIndices: (json['note_indices'] as List).cast<int>(),
        summary: json['summary'] as String,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'theme': theme,
        'note_indices': noteIndices,
        'summary': summary,
      };
}
