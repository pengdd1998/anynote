import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/compose/domain/outline_model.dart';

void main() {
  // ---------------------------------------------------------------------------
  // OutlineSection
  // ---------------------------------------------------------------------------

  group('OutlineSection', () {
    test('constructor with sourceCluster', () {
      const section = OutlineSection(
        heading: 'Introduction',
        points: ['Hook the reader', 'State the thesis'],
        sourceCluster: 0,
      );

      expect(section.heading, 'Introduction');
      expect(section.points, ['Hook the reader', 'State the thesis']);
      expect(section.sourceCluster, 0);
    });

    test('constructor without sourceCluster', () {
      const section = OutlineSection(
        heading: 'Conclusion',
        points: ['Summarize key points'],
      );

      expect(section.heading, 'Conclusion');
      expect(section.points, ['Summarize key points']);
      expect(section.sourceCluster, isNull);
    });

    test('fromJson deserializes correctly with sourceCluster', () {
      final json = {
        'heading': 'Methods',
        'points': ['Describe approach', 'List tools'],
        'source_cluster': 2,
      };

      final section = OutlineSection.fromJson(json);

      expect(section.heading, 'Methods');
      expect(section.points, ['Describe approach', 'List tools']);
      expect(section.sourceCluster, 2);
    });

    test('fromJson deserializes correctly without sourceCluster', () {
      final json = {
        'heading': 'References',
        'points': ['Cite source A'],
      };

      final section = OutlineSection.fromJson(json);

      expect(section.heading, 'References');
      expect(section.points, ['Cite source A']);
      expect(section.sourceCluster, isNull);
    });

    test('toJson includes sourceCluster when present', () {
      const section = OutlineSection(
        heading: 'Analysis',
        points: ['Analyze data'],
        sourceCluster: 1,
      );

      final json = section.toJson();

      expect(json['heading'], 'Analysis');
      expect(json['points'], ['Analyze data']);
      expect(json['source_cluster'], 1);
    });

    test('toJson omits sourceCluster when null', () {
      const section = OutlineSection(
        heading: 'Summary',
        points: ['Final thoughts'],
      );

      final json = section.toJson();

      expect(json['heading'], 'Summary');
      expect(json['points'], ['Final thoughts']);
      expect(json.containsKey('source_cluster'), isFalse);
    });

    test('round-trip fromJson(toJson()) preserves data with sourceCluster', () {
      const original = OutlineSection(
        heading: 'Results',
        points: ['Finding 1', 'Finding 2'],
        sourceCluster: 3,
      );

      final json = original.toJson();
      final restored = OutlineSection.fromJson(json);

      expect(restored.heading, original.heading);
      expect(restored.points, original.points);
      expect(restored.sourceCluster, original.sourceCluster);
    });

    test('round-trip fromJson(toJson()) preserves data without sourceCluster', () {
      const original = OutlineSection(
        heading: 'Discussion',
        points: ['Interpret results'],
      );

      final json = original.toJson();
      final restored = OutlineSection.fromJson(json);

      expect(restored.heading, original.heading);
      expect(restored.points, original.points);
      expect(restored.sourceCluster, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // OutlineModel
  // ---------------------------------------------------------------------------

  group('OutlineModel', () {
    test('constructor and field access', () {
      const model = OutlineModel(
        title: 'My Blog Post',
        sections: [
          OutlineSection(heading: 'Intro', points: ['Point A']),
        ],
      );

      expect(model.title, 'My Blog Post');
      expect(model.sections.length, 1);
      expect(model.sections[0].heading, 'Intro');
    });

    test('fromJson with nested sections', () {
      final json = {
        'title': 'Research Paper',
        'sections': [
          {
            'heading': 'Abstract',
            'points': ['Summarize the paper'],
            'source_cluster': 0,
          },
          {
            'heading': 'Introduction',
            'points': ['Background', 'Motivation'],
            'source_cluster': 1,
          },
        ],
      };

      final model = OutlineModel.fromJson(json);

      expect(model.title, 'Research Paper');
      expect(model.sections.length, 2);
      expect(model.sections[0].heading, 'Abstract');
      expect(model.sections[0].sourceCluster, 0);
      expect(model.sections[1].points, ['Background', 'Motivation']);
      expect(model.sections[1].sourceCluster, 1);
    });

    test('toJson produces correct structure', () {
      const model = OutlineModel(
        title: 'Newsletter',
        sections: [
          OutlineSection(
            heading: 'Header',
            points: ['Welcome'],
            sourceCluster: 0,
          ),
          OutlineSection(
            heading: 'Footer',
            points: ['Goodbye'],
          ),
        ],
      );

      final json = model.toJson();

      expect(json['title'], 'Newsletter');
      expect(json['sections'], isA<List>());
      final sections = json['sections'] as List;
      expect(sections.length, 2);
      expect(sections[0]['heading'], 'Header');
      expect(sections[0]['source_cluster'], 0);
      expect(sections[1]['heading'], 'Footer');
      expect(sections[1].containsKey('source_cluster'), isFalse);
    });

    test('round-trip fromJson(toJson()) preserves all data', () {
      final originalJson = {
        'title': 'Complete Post',
        'sections': [
          {
            'heading': 'Section One',
            'points': ['Alpha', 'Beta'],
            'source_cluster': 0,
          },
          {
            'heading': 'Section Two',
            'points': ['Gamma'],
          },
          {
            'heading': 'Section Three',
            'points': ['Delta', 'Epsilon', 'Zeta'],
            'source_cluster': 2,
          },
        ],
      };

      final original = OutlineModel.fromJson(originalJson);
      final json = original.toJson();
      final restored = OutlineModel.fromJson(json);

      expect(restored.title, original.title);
      expect(restored.sections.length, original.sections.length);
      for (var i = 0; i < restored.sections.length; i++) {
        expect(restored.sections[i].heading, original.sections[i].heading);
        expect(restored.sections[i].points, original.sections[i].points);
        expect(restored.sections[i].sourceCluster, original.sections[i].sourceCluster);
      }
    });

    test('empty sections list', () {
      const model = OutlineModel(
        title: 'Empty Outline',
        sections: [],
      );

      expect(model.sections, isEmpty);

      final json = model.toJson();
      expect(json['sections'], isEmpty);

      final restored = OutlineModel.fromJson(json);
      expect(restored.sections, isEmpty);
    });

    test('multiple sections with mixed sourceCluster presence', () {
      const model = OutlineModel(
        title: 'Mixed Outline',
        sections: [
          OutlineSection(heading: 'A', points: ['a1'], sourceCluster: 0),
          OutlineSection(heading: 'B', points: ['b1', 'b2']),
          OutlineSection(heading: 'C', points: ['c1'], sourceCluster: 2),
          OutlineSection(heading: 'D', points: []),
        ],
      );

      expect(model.sections.length, 4);
      expect(model.sections[0].sourceCluster, 0);
      expect(model.sections[1].sourceCluster, isNull);
      expect(model.sections[2].sourceCluster, 2);
      expect(model.sections[3].sourceCluster, isNull);
      expect(model.sections[3].points, isEmpty);

      // Verify toJson handles the mix correctly
      final json = model.toJson();
      final sections = json['sections'] as List;
      expect(sections[0].containsKey('source_cluster'), isTrue);
      expect(sections[1].containsKey('source_cluster'), isFalse);
      expect(sections[2].containsKey('source_cluster'), isTrue);
      expect(sections[3].containsKey('source_cluster'), isFalse);
    });
  });
}
