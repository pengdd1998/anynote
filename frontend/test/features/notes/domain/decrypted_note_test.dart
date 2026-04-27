// Tests for the DecryptedNote domain model.
//
// Tests cover:
// - Construction with required fields
// - copyWith partial update (only title)
// - copyWith full update (all fields)
// - Equality semantics (value-based operator==)
// - hashCode consistency with equality

import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/domain/decrypted_note.dart';

void main() {
  group('DecryptedNote', () {
    test('stores all provided field values', () {
      final now = DateTime(2026, 4, 26, 12, 0, 0);
      final note = DecryptedNote(
        title: 'Test Note',
        content: '# Hello\n\nWorld',
        updatedAt: now,
        isSynced: true,
      );

      expect(note.title, equals('Test Note'));
      expect(note.content, equals('# Hello\n\nWorld'));
      expect(note.updatedAt, equals(now));
      expect(note.isSynced, isTrue);
    });

    test('copyWith partial update changes only title', () {
      final original = DecryptedNote(
        title: 'Original',
        content: 'Content stays',
        updatedAt: DateTime(2026, 1, 1),
        isSynced: false,
      );

      final updated = original.copyWith(title: 'New Title');

      expect(updated.title, equals('New Title'));
      expect(updated.content, equals('Content stays'));
      expect(updated.updatedAt, equals(original.updatedAt));
      expect(updated.isSynced, equals(original.isSynced));
    });

    test('copyWith full update changes all fields', () {
      final original = DecryptedNote(
        title: 'Old Title',
        content: 'Old content',
        updatedAt: DateTime(2026, 1, 1),
        isSynced: false,
      );

      final newTime = DateTime(2026, 4, 26, 15, 30);
      final updated = original.copyWith(
        title: 'New Title',
        content: 'New content',
        updatedAt: newTime,
        isSynced: true,
      );

      expect(updated.title, equals('New Title'));
      expect(updated.content, equals('New content'));
      expect(updated.updatedAt, equals(newTime));
      expect(updated.isSynced, isTrue);
    });

    test('copyWith with no arguments returns equivalent instance', () {
      final original = DecryptedNote(
        title: 'Title',
        content: 'Content',
        updatedAt: DateTime(2026, 4, 26),
        isSynced: true,
      );

      final copy = original.copyWith();

      expect(copy, equals(original));
    });

    test('equality: two notes with same fields are equal', () {
      final dt = DateTime(2026, 4, 26, 12, 0);
      final a = DecryptedNote(
        title: 'Same',
        content: 'Same content',
        updatedAt: dt,
        isSynced: true,
      );
      final b = DecryptedNote(
        title: 'Same',
        content: 'Same content',
        updatedAt: dt,
        isSynced: true,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality: different title produces unequal notes', () {
      final dt = DateTime(2026, 4, 26);
      final a = DecryptedNote(
        title: 'Alpha',
        content: 'Content',
        updatedAt: dt,
        isSynced: true,
      );
      final b = DecryptedNote(
        title: 'Beta',
        content: 'Content',
        updatedAt: dt,
        isSynced: true,
      );

      expect(a, isNot(equals(b)));
    });

    test('equality: different isSynced produces unequal notes', () {
      final dt = DateTime(2026, 4, 26);
      final a = DecryptedNote(
        title: 'Title',
        content: 'Content',
        updatedAt: dt,
        isSynced: true,
      );
      final b = DecryptedNote(
        title: 'Title',
        content: 'Content',
        updatedAt: dt,
        isSynced: false,
      );

      expect(a, isNot(equals(b)));
    });

    test('hashCode is consistent across multiple accesses', () {
      final note = DecryptedNote(
        title: 'Consistent',
        content: 'Hash test',
        updatedAt: DateTime(2026, 4, 26),
        isSynced: true,
      );

      final hash1 = note.hashCode;
      final hash2 = note.hashCode;
      expect(hash1, equals(hash2));
    });

    test('handles empty title and content', () {
      final note = DecryptedNote(
        title: '',
        content: '',
        updatedAt: DateTime(2026, 4, 26),
        isSynced: false,
      );

      expect(note.title, isEmpty);
      expect(note.content, isEmpty);
    });
  });
}
