import 'package:collection/collection.dart';

class OutlineSection {
  final String heading;
  final List<String> points;
  final int? sourceCluster;

  const OutlineSection({
    required this.heading,
    required this.points,
    this.sourceCluster,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutlineSection &&
          runtimeType == other.runtimeType &&
          heading == other.heading &&
          const DeepCollectionEquality().equals(points, other.points) &&
          sourceCluster == other.sourceCluster;

  @override
  int get hashCode =>
      Object.hash(heading, Object.hashAll(points), sourceCluster);

  factory OutlineSection.fromJson(Map<String, dynamic> json) => OutlineSection(
        heading: json['heading'] as String,
        points: (json['points'] as List).cast<String>(),
        sourceCluster: json['source_cluster'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'heading': heading,
        'points': points,
        if (sourceCluster != null) 'source_cluster': sourceCluster,
      };
}

class OutlineModel {
  final String title;
  final List<OutlineSection> sections;

  const OutlineModel({required this.title, required this.sections});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutlineModel &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          const DeepCollectionEquality().equals(sections, other.sections);

  @override
  int get hashCode => Object.hash(title, Object.hashAll(sections));

  factory OutlineModel.fromJson(Map<String, dynamic> json) => OutlineModel(
        title: json['title'] as String,
        sections: (json['sections'] as List)
            .map((s) => OutlineSection.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'sections': sections.map((s) => s.toJson()).toList(),
      };
}
