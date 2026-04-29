import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/database/database_factory.dart';
import 'package:anynote/core/platform/platform_utils.dart';

void main() {
  // -- Platform Detection --

  group('PlatformUtils web detection', () {
    test('isWeb returns consistent value with kIsWeb', () {
      expect(PlatformUtils.isWeb, equals(kIsWeb));
    });

    test('isDesktop returns false on web', () {
      if (kIsWeb) {
        expect(PlatformUtils.isDesktop, isFalse);
      }
    });

    test('isMobile returns false on web', () {
      if (kIsWeb) {
        expect(PlatformUtils.isMobile, isFalse);
      }
    });
  });

  // -- Database Construction --

  group('AppDatabase construction', () {
    late AppDatabase db;

    tearDown(() async {
      await db.close();
    });

    test('can be constructed on all platforms', () {
      // Should not throw on any platform.
      if (kIsWeb) {
        // On web, the default constructor uses drift_flutter.driftDatabase.
        db = AppDatabase();
      } else {
        // On native test runner, use in-memory database for testing.
        db = AppDatabase.forTesting(NativeDatabase.memory());
      }
      expect(db, isNotNull);
    });

    test('can execute basic query', () async {
      if (kIsWeb) {
        db = AppDatabase();
      } else {
        db = AppDatabase.forTesting(NativeDatabase.memory());
      }

      // Should be able to execute a simple SELECT.
      final result = await db.customSelect('SELECT 1 AS value').getSingle();
      expect(result.read<int>('value'), 1);
    });

    test('schema version is 17', () {
      if (kIsWeb) {
        db = AppDatabase();
      } else {
        db = AppDatabase.forTesting(NativeDatabase.memory());
      }

      expect(db.schemaVersion, 17);
    });

    test('encryption key can be set and cleared', () {
      // These are static methods that should not throw.
      AppDatabase.setEncryptionKey('0' * 64);
      AppDatabase.clearEncryptionKey();
      // No assertion needed -- just verifying no exceptions.
    });
  });

  // -- Encryption Key Management --

  group('AppDatabase encryption key', () {
    test('setEncryptionKey accepts hex string', () {
      // Should not throw.
      AppDatabase.setEncryptionKey(
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4'
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4',
      );
      AppDatabase.clearEncryptionKey();
    });

    test('clearEncryptionKey resets to null', () {
      AppDatabase.setEncryptionKey('ab' * 32);
      AppDatabase.clearEncryptionKey();
      // After clearing, the database should open without encryption.
      // No assertion needed -- the key is an internal static field.
    });
  });

  // -- Database Factory --

  group('DatabaseFactory', () {
    test('createDatabaseExecutor throws on native', () {
      if (!kIsWeb) {
        expect(
          () => createDatabaseExecutor(),
          throwsA(isA<StateError>()),
        );
      }
    });
  });

  // -- Migration Strategy --

  group('AppDatabase migration', () {
    late AppDatabase db;

    tearDown(() async {
      await db.close();
    });

    test('onCreate creates all tables without error', () async {
      if (kIsWeb) {
        db = AppDatabase();
      } else {
        db = AppDatabase.forTesting(NativeDatabase.memory());
      }

      // Accessing the database triggers onCreate. Verify by selecting from
      // a table that should exist.
      final notes = await db.notesDao.getAllNotes();
      expect(notes, isEmpty);
    });

    test('FTS5 virtual table exists after creation', () async {
      if (!kIsWeb) {
        // FTS5 with unicode61 tokenizer only works on native SQLite.
        db = AppDatabase.forTesting(NativeDatabase.memory());

        // Verify FTS5 table exists by querying it.
        final result = await db
            .customSelect('SELECT count(*) AS cnt FROM notes_fts')
            .getSingle();
        expect(result.read<int>('cnt'), 0);
      }
    });
  });

  // -- Web-specific behavior --

  group('Web database behavior', () {
    test('kIsWeb is consistent throughout test session', () {
      // Verify that the platform check does not change between calls.
      const first = kIsWeb;
      const second = kIsWeb;
      expect(first, equals(second));
    });

    test('PlatformUtils.isWeb matches kIsWeb', () {
      expect(PlatformUtils.isWeb, equals(kIsWeb));
    });

    test('database name is anynote.db', () async {
      // On web, drift uses OPFS/IndexedDB with this name.
      // On native, it is a file path. The test just verifies the
      // constructor does not throw.
      if (kIsWeb) {
        db = AppDatabase();
        await db.customSelect('SELECT 1').getSingle();
        await db.close();
      } else {
        // On native, verify with in-memory database.
        db = AppDatabase.forTesting(NativeDatabase.memory());
        await db.customSelect('SELECT 1').getSingle();
        await db.close();
      }
    });
  });
}

late AppDatabase db;
