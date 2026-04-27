// Tests for the NoteLink domain model.
//
// Tests cover:
// - Construction with all fields
// - fromJson with valid snake_case map
// - toJson produces snake_case keys, excludes id and createdAt
// - Equality semantics
// - hashCode consistency

import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/domain/note_link.dart';

void main() {
  group('NoteLink', () {
    test('stores all provided field values', () {
      final createdAt = DateTime(2026, 4, 26, 10, 30, 0);
      final link = NoteLink(
        id: 'link-1',
        sourceId: 'note-a',
        targetId: 'note-b',
        linkType: 'wiki',
        createdAt: createdAt,
      );

      expect(link.id, equals('link-1'));
      expect(link.sourceId, equals('note-a'));
      expect(link.targetId, equals('note-b'));
      expect(link.linkType, equals('wiki'));
      expect(link.createdAt, equals(createdAt));
    });

    test('fromJson parses snake_case keys', () {
      final json = {
        'id': 'link-2',
        'source_id': 'note-x',
        'target_id': 'note-y',
        'link_type': 'reference',
        'created_at': '2026-01-15T08:00:00.000',
      };

      final link = NoteLink.fromJson(json);

      expect(link.id, equals('link-2'));
      expect(link.sourceId, equals('note-x'));
      expect(link.targetId, equals('note-y'));
      expect(link.linkType, equals('reference'));
      expect(link.createdAt.year, equals(2026));
      expect(link.createdAt.month, equals(1));
      expect(link.createdAt.day, equals(15));
    });

    test('toJson produces snake_case keys without id and createdAt', () {
      final link = NoteLink(
        id: 'link-3',
        sourceId: 's1',
        targetId: 't1',
        linkType: 'wiki',
        createdAt: DateTime(2026, 4, 26),
      );

      final json = link.toJson();

      expect(json, isA<Map<String, dynamic>>());
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('created_at'), isFalse);
      expect(json['source_id'], equals('s1'));
      expect(json['target_id'], equals('t1'));
      expect(json['link_type'], equals('wiki'));
      expect(json.length, equals(3));
    });

    test('equality: two links with identical fields are equal', () {
      final dt = DateTime(2026, 4, 26, 12, 0);
      final a = NoteLink(
        id: 'id',
        sourceId: 'src',
        targetId: 'tgt',
        linkType: 'wiki',
        createdAt: dt,
      );
      final b = NoteLink(
        id: 'id',
        sourceId: 'src',
        targetId: 'tgt',
        linkType: 'wiki',
        createdAt: dt,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality: links with different id are not equal', () {
      final dt = DateTime(2026, 4, 26);
      final a = NoteLink(
        id: 'id-1',
        sourceId: 'src',
        targetId: 'tgt',
        linkType: 'wiki',
        createdAt: dt,
      );
      final b = NoteLink(
        id: 'id-2',
        sourceId: 'src',
        targetId: 'tgt',
        linkType: 'wiki',
        createdAt: dt,
      );

      expect(a, isNot(equals(b)));
    });

    test('equality: links with different targetId are not equal', () {
      final dt = DateTime(2026, 4, 26);
      final a = NoteLink(
        id: 'id',
        sourceId: 'src',
        targetId: 'tgt-a',
        linkType: 'wiki',
        createdAt: dt,
      );
      final b = NoteLink(
        id: 'id',
        sourceId: 'src',
        targetId: 'tgt-b',
        linkType: 'wiki',
        createdAt: dt,
      );

      expect(a, isNot(equals(b)));
    });

    test('hashCode is consistent across multiple accesses', () {
      final link = NoteLink(
        id: 'id',
        sourceId: 'src',
        targetId: 'tgt',
        linkType: 'wiki',
        createdAt: DateTime(2026, 4, 26),
      );

      final hash1 = link.hashCode;
      final hash2 = link.hashCode;
      expect(hash1, equals(hash2));
    });
  });
}
