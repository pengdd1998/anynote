import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/compose/domain/cluster_model.dart';

void main() {
  group('ClusterModel', () {
    test('constructor creates instance with all fields', () {
      const model = ClusterModel(
        name: 'Test Cluster',
        theme: 'machine learning',
        noteIndices: [0, 2, 4],
        summary: 'A summary of the cluster',
      );

      expect(model.name, 'Test Cluster');
      expect(model.theme, 'machine learning');
      expect(model.noteIndices, [0, 2, 4]);
      expect(model.summary, 'A summary of the cluster');
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'name': 'NLP Research',
        'theme': 'natural language processing',
        'note_indices': [1, 3, 5],
        'summary': 'Notes about NLP techniques',
      };

      final model = ClusterModel.fromJson(json);

      expect(model.name, 'NLP Research');
      expect(model.theme, 'natural language processing');
      expect(model.noteIndices, [1, 3, 5]);
      expect(model.summary, 'Notes about NLP techniques');
    });

    test('toJson serializes correctly', () {
      const model = ClusterModel(
        name: 'Design Patterns',
        theme: 'software engineering',
        noteIndices: [0, 1],
        summary: 'Common design patterns',
      );

      final json = model.toJson();

      expect(json['name'], 'Design Patterns');
      expect(json['theme'], 'software engineering');
      expect(json['note_indices'], [0, 1]);
      expect(json['summary'], 'Common design patterns');
    });

    test('round-trip fromJson(toJson()) equals original', () {
      const original = ClusterModel(
        name: 'Cluster A',
        theme: 'data science',
        noteIndices: [0, 1, 2, 3],
        summary: 'Data science related notes',
      );

      final json = original.toJson();
      final restored = ClusterModel.fromJson(json);

      expect(restored.name, original.name);
      expect(restored.theme, original.theme);
      expect(restored.noteIndices, original.noteIndices);
      expect(restored.summary, original.summary);
    });

    test('multiple instances with different data are independent', () {
      const modelA = ClusterModel(
        name: 'Cluster A',
        theme: 'theme A',
        noteIndices: [0],
        summary: 'summary A',
      );
      const modelB = ClusterModel(
        name: 'Cluster B',
        theme: 'theme B',
        noteIndices: [1, 2],
        summary: 'summary B',
      );

      expect(modelA.name, isNot(equals(modelB.name)));
      expect(modelA.theme, isNot(equals(modelB.theme)));
      expect(modelA.noteIndices.length, isNot(equals(modelB.noteIndices.length)));
      expect(modelA.summary, isNot(equals(modelB.summary)));
    });

    test('noteIndices can be empty list', () {
      const model = ClusterModel(
        name: 'Empty Cluster',
        theme: 'unused theme',
        noteIndices: [],
        summary: 'No notes in this cluster',
      );

      expect(model.noteIndices, isEmpty);

      // Round-trip should preserve empty list
      final json = model.toJson();
      final restored = ClusterModel.fromJson(json);
      expect(restored.noteIndices, isEmpty);
    });
  });
}
