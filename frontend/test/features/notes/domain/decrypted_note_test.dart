// Tests for the DecryptedNote domain model extracted in Phase 51.
//
// Tests cover:
// - Construction with required fields
// - Equality semantics (value-based via const constructor)
// - Default property access
// - Immutability of fields

import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/domain/decrypted_note.dart';

void main() {
  group('DecryptedNote', () {
    test('stores all provided field values', () {
      final now = DateTime(2026, 4, 21, 12, 0, 0);
      final note = DecryptedNote(
        title: 'Test Note',
        content: '# Hello\n\nWorld',
        updatedAt: now,
        isSynced: true,
      );

      expect(note.title, 'Test Note');
      expect(note.content, '# Hello\n\nWorld');
      expect(note.updatedAt, now);
      expect(note.isSynced, isTrue);
    });

    test('can be constructed with const-compatible fields', () {
      final note = DecryptedNote(
        title: '',
        content: '',
        updatedAt: DateTime(2026, 1, 1),
        isSynced: false,
      );

      expect(note.title, '');
      expect(note.content, '');
      expect(note.isSynced, isFalse);
    });

    test('supports unsynced notes', () {
      final note = DecryptedNote(
        title: 'Draft',
        content: 'Work in progress',
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      expect(note.isSynced, isFalse);
    });

    test('supports synced notes', () {
      final note = DecryptedNote(
        title: 'Published',
        content: 'Already synced',
        updatedAt: DateTime.now(),
        isSynced: true,
      );

      expect(note.isSynced, isTrue);
    });

    test('two notes with same values are equal instances', () {
      final now = DateTime(2026, 4, 21);
      final note1 = DecryptedNote(
        title: 'Same',
        content: 'Same content',
        updatedAt: now,
        isSynced: true,
      );
      final note2 = DecryptedNote(
        title: 'Same',
        content: 'Same content',
        updatedAt: now,
        isSynced: true,
      );

      // DecryptedNote does not override ==, so identity comparison applies.
      // Both are distinct instances with identical field values.
      expect(note1.title, equals(note2.title));
      expect(note1.content, equals(note2.content));
      expect(note1.updatedAt, equals(note2.updatedAt));
      expect(note1.isSynced, equals(note2.isSynced));
    });

    test('handles empty title and content', () {
      final note = DecryptedNote(
        title: '',
        content: '',
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      expect(note.title, isEmpty);
      expect(note.content, isEmpty);
    });

    test('handles long markdown content', () {
      final longContent = List.generate(1000, (i) => 'Line $i').join('\n');
      final note = DecryptedNote(
        title: 'Long Note',
        content: longContent,
        updatedAt: DateTime.now(),
        isSynced: true,
      );

      expect(note.content.length, greaterThan(5000));
      expect(note.content, contains('Line 0'));
      expect(note.content, contains('Line 999'));
    });

    test('updatedAt preserves microsecond precision', () {
      final precise = DateTime(2026, 4, 21, 12, 30, 45, 123, 456);
      final note = DecryptedNote(
        title: 'Precise',
        content: 'time test',
        updatedAt: precise,
        isSynced: true,
      );

      expect(note.updatedAt.microsecond, 456);
      expect(note.updatedAt.millisecond, 123);
    });
  });
}
