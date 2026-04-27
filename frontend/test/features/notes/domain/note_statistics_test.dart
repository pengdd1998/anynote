// Tests for the note statistics domain models.
//
// Tests cover:
// - NoteStatistics construction and field access
// - TagStat equality and hashCode
// - CollectionStat equality and hashCode
// - WritingStreak equality and hashCode (including Set comparison)
// - ConnectedNoteStat equality and hashCode
// - WritingStreak with empty activeDaysLast30

import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/domain/note_statistics.dart';

void main() {
  group('NoteStatistics', () {
    test('stores all provided field values', () {
      final stats = NoteStatistics(
        totalNotes: 42,
        totalWords: 12000,
        totalCharacters: 65000,
        notesWithProperties: 10,
        notesWithLinks: 15,
        orphanedNotes: 5,
        totalLinks: 30,
        notesByMonth: {'2026-03': 10, '2026-04': 12},
        wordsByMonth: {'2026-03': 3000, '2026-04': 4000},
        topTags: [const TagStat(tagName: 'work', noteCount: 8)],
        topCollections: [
          const CollectionStat(collectionTitle: 'Projects', noteCount: 12),
        ],
        writingStreak: const WritingStreak(
          currentStreak: 3,
          longestStreak: 10,
          activeDaysLast30: {'2026-04-25', '2026-04-26'},
        ),
        statusDistribution: {'Todo': 5, 'Done': 37},
        priorityDistribution: {'High': 3, 'Low': 20},
        oldestNote: DateTime(2025, 6, 1),
        newestNote: DateTime(2026, 4, 26),
        averageWordsPerNote: 285.7,
        mostConnectedNote: const ConnectedNoteStat(
          noteId: 'n1',
          noteTitle: 'Hub Note',
          linkCount: 8,
        ),
      );

      expect(stats.totalNotes, equals(42));
      expect(stats.totalWords, equals(12000));
      expect(stats.totalCharacters, equals(65000));
      expect(stats.notesWithProperties, equals(10));
      expect(stats.notesWithLinks, equals(15));
      expect(stats.orphanedNotes, equals(5));
      expect(stats.totalLinks, equals(30));
      expect(stats.notesByMonth['2026-04'], equals(12));
      expect(stats.topTags.length, equals(1));
      expect(stats.topCollections.length, equals(1));
      expect(stats.writingStreak.currentStreak, equals(3));
      expect(stats.statusDistribution['Todo'], equals(5));
      expect(stats.priorityDistribution['High'], equals(3));
      expect(stats.oldestNote, isNotNull);
      expect(stats.newestNote, isNotNull);
      expect(stats.averageWordsPerNote, closeTo(285.7, 0.01));
      expect(stats.mostConnectedNote, isNotNull);
      expect(stats.mostConnectedNote!.linkCount, equals(8));
    });

    test('nullable fields default to null', () {
      const stats = NoteStatistics(
        totalNotes: 0,
        totalWords: 0,
        totalCharacters: 0,
        notesWithProperties: 0,
        notesWithLinks: 0,
        orphanedNotes: 0,
        totalLinks: 0,
        notesByMonth: {},
        wordsByMonth: {},
        topTags: [],
        topCollections: [],
        writingStreak: WritingStreak(
          currentStreak: 0,
          longestStreak: 0,
          activeDaysLast30: {},
        ),
        statusDistribution: {},
        priorityDistribution: {},
        averageWordsPerNote: 0.0,
      );

      expect(stats.oldestNote, isNull);
      expect(stats.newestNote, isNull);
      expect(stats.mostConnectedNote, isNull);
    });
  });

  group('TagStat', () {
    test('stores field values', () {
      const stat = TagStat(tagName: 'flutter', noteCount: 15);
      expect(stat.tagName, equals('flutter'));
      expect(stat.noteCount, equals(15));
    });

    test('equality: same tagName and noteCount are equal', () {
      const a = TagStat(tagName: 'dart', noteCount: 5);
      const b = TagStat(tagName: 'dart', noteCount: 5);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality: different noteCount are not equal', () {
      const a = TagStat(tagName: 'dart', noteCount: 5);
      const b = TagStat(tagName: 'dart', noteCount: 6);
      expect(a, isNot(equals(b)));
    });

    test('equality: different tagName are not equal', () {
      const a = TagStat(tagName: 'dart', noteCount: 5);
      const b = TagStat(tagName: 'flutter', noteCount: 5);
      expect(a, isNot(equals(b)));
    });
  });

  group('CollectionStat', () {
    test('stores field values', () {
      const stat = CollectionStat(collectionTitle: 'Work', noteCount: 20);
      expect(stat.collectionTitle, equals('Work'));
      expect(stat.noteCount, equals(20));
    });

    test('equality: same fields are equal', () {
      const a = CollectionStat(collectionTitle: 'Personal', noteCount: 10);
      const b = CollectionStat(collectionTitle: 'Personal', noteCount: 10);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality: different collectionTitle are not equal', () {
      const a = CollectionStat(collectionTitle: 'Alpha', noteCount: 10);
      const b = CollectionStat(collectionTitle: 'Beta', noteCount: 10);
      expect(a, isNot(equals(b)));
    });

    test('equality: different noteCount are not equal', () {
      const a = CollectionStat(collectionTitle: 'Work', noteCount: 1);
      const b = CollectionStat(collectionTitle: 'Work', noteCount: 2);
      expect(a, isNot(equals(b)));
    });
  });

  group('WritingStreak', () {
    test('stores field values', () {
      const streak = WritingStreak(
        currentStreak: 5,
        longestStreak: 15,
        streakStart: null,
        longestStreakStart: null,
        activeDaysLast30: {'2026-04-25'},
      );
      expect(streak.currentStreak, equals(5));
      expect(streak.longestStreak, equals(15));
      expect(streak.streakStart, isNull);
      expect(streak.activeDaysLast30.length, equals(1));
    });

    test('equality: same fields including set contents are equal', () {
      const a = WritingStreak(
        currentStreak: 3,
        longestStreak: 10,
        activeDaysLast30: {'2026-04-25', '2026-04-26'},
      );
      const b = WritingStreak(
        currentStreak: 3,
        longestStreak: 10,
        activeDaysLast30: {'2026-04-25', '2026-04-26'},
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality: different activeDaysLast30 sets are not equal', () {
      const a = WritingStreak(
        currentStreak: 3,
        longestStreak: 10,
        activeDaysLast30: {'2026-04-25'},
      );
      const b = WritingStreak(
        currentStreak: 3,
        longestStreak: 10,
        activeDaysLast30: {'2026-04-26'},
      );
      expect(a, isNot(equals(b)));
    });

    test('equality: different currentStreak are not equal', () {
      const a = WritingStreak(
        currentStreak: 1,
        longestStreak: 10,
        activeDaysLast30: {},
      );
      const b = WritingStreak(
        currentStreak: 2,
        longestStreak: 10,
        activeDaysLast30: {},
      );
      expect(a, isNot(equals(b)));
    });

    test('with empty activeDaysLast30 works correctly', () {
      const streak = WritingStreak(
        currentStreak: 0,
        longestStreak: 0,
        activeDaysLast30: {},
      );
      expect(streak.activeDaysLast30, isEmpty);
      expect(streak.currentStreak, equals(0));
    });

    test('equality with streakStart', () {
      final dt = DateTime(2026, 4, 20);
      final a = WritingStreak(
        currentStreak: 3,
        longestStreak: 3,
        streakStart: dt,
        activeDaysLast30: {},
      );
      final b = WritingStreak(
        currentStreak: 3,
        longestStreak: 3,
        streakStart: dt,
        activeDaysLast30: {},
      );
      expect(a, equals(b));
    });

    test('hashCode is consistent across multiple accesses', () {
      const streak = WritingStreak(
        currentStreak: 3,
        longestStreak: 10,
        activeDaysLast30: {'2026-04-26'},
      );
      expect(streak.hashCode, equals(streak.hashCode));
    });
  });

  group('ConnectedNoteStat', () {
    test('stores field values', () {
      const stat = ConnectedNoteStat(
        noteId: 'n123',
        noteTitle: 'Central',
        linkCount: 7,
      );
      expect(stat.noteId, equals('n123'));
      expect(stat.noteTitle, equals('Central'));
      expect(stat.linkCount, equals(7));
    });

    test('equality: same fields are equal', () {
      const a = ConnectedNoteStat(noteId: 'n1', noteTitle: 'A', linkCount: 3);
      const b = ConnectedNoteStat(noteId: 'n1', noteTitle: 'A', linkCount: 3);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality: different linkCount are not equal', () {
      const a = ConnectedNoteStat(noteId: 'n1', noteTitle: 'A', linkCount: 3);
      const b = ConnectedNoteStat(noteId: 'n1', noteTitle: 'A', linkCount: 4);
      expect(a, isNot(equals(b)));
    });

    test('equality: different noteId are not equal', () {
      const a = ConnectedNoteStat(noteId: 'n1', noteTitle: 'A', linkCount: 3);
      const b = ConnectedNoteStat(noteId: 'n2', noteTitle: 'A', linkCount: 3);
      expect(a, isNot(equals(b)));
    });

    test('equality: different noteTitle are not equal', () {
      const a = ConnectedNoteStat(noteId: 'n1', noteTitle: 'A', linkCount: 3);
      const b = ConnectedNoteStat(noteId: 'n1', noteTitle: 'B', linkCount: 3);
      expect(a, isNot(equals(b)));
    });
  });
}
