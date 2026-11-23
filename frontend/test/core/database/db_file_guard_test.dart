import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/database/db_file_guard.dart';
import 'package:anynote/core/database/db_file_flags.dart';

import '../../flutter_test_config.dart' show sqlCipherLoader;

/// The local database is SQLCipher-encrypted, so these tests only mean
/// something on a real SQLCipher build; they are skipped without one
/// (`test/flutter_test_config.dart` switches the whole suite over when the
/// library is installed).
void main() {
  final hasSqlCipher = sqlCipherLoader() != null;
  const key = '0123456789abcdef0123456789abcdef';

  late Directory dir;
  late File dbFile;
  late DbFileGuard guard;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('anynote_db_guard_');
    dbFile = File('${dir.path}/anynote.db.sqlite');
    guard = DbFileGuard(logger: (_) {});
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  /// A database as an older (unencrypted) AnyNote build left it: full schema,
  /// schema version 23, a populated FTS index.
  Future<void> buildLegacyPlaintext({int notes = 2}) async {
    final legacy = AppDatabase.forTesting(NativeDatabase(dbFile));
    for (var i = 0; i < notes; i++) {
      await legacy.notesDao.createNote(
        id: 'legacy-$i',
        encryptedContent: 'ZW5jcnlwdGVk',
        plainContent: 'legacy ZEBRA note number $i',
      );
    }
    await legacy.close();
    expect(dbFile.readAsBytesSync().sublist(0, 15), 'SQLite format 3'.codeUnits,
        reason: 'the fixture must start out as a plaintext database');
  }

  Future<AppDatabase> openEncrypted() async => AppDatabase.forTesting(
        NativeDatabase(
          dbFile,
          setup: (db) => db.execute(databaseKeyPragma(key)),
        ),
      );

  Future<int> pragma(String name, {String? withKey}) async {
    final db = sqlite3.open(dbFile.path);
    try {
      if (withKey != null) db.execute(databaseKeyPragma(withKey));
      return db.select('PRAGMA $name').first.values[0] as int;
    } finally {
      db.dispose();
    }
  }

  group('DbFileGuard on SQLCipher', () {
    test('generateDatabaseKey is 64 hex characters and never repeats', () {
      final a = generateDatabaseKey();
      final b = generateDatabaseKey();
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(a), isTrue);
      expect(a, isNot(b));
    });

    test(
        'regression: sqlcipher_export alone drops user_version, and Drift '
        'then cannot open the copy', () async {
      // The exact migration the first SQLCipher build shipped: export, swap,
      // nothing else. Kept as the evidence for why the guard restores the
      // version below.
      await buildLegacyPlaintext();
      final tmp = File('${dbFile.path}.encrypting');
      final plain = sqlite3.open(dbFile.path);
      plain.execute('ATTACH DATABASE ? AS migrate KEY ?', [tmp.path, key]);
      plain.select("SELECT sqlcipher_export('migrate')");
      plain.execute('DETACH DATABASE migrate');
      plain.dispose();
      dbFile.deleteSync();
      tmp.renameSync(dbFile.path);

      expect(await pragma('user_version', withKey: key), 0);

      final db = await openEncrypted();
      addTearDown(db.close);
      await expectLater(db.notesDao.getAllNotes(), throwsA(anything));
    });

    test('encrypts a legacy plaintext database in place, data intact', () async {
      await buildLegacyPlaintext();
      final before = await pragma('user_version');

      final plan = guard.prepare(dbFile: dbFile, key: key);

      expect(plan.outcome, DbFileOutcome.migrated);
      expect(plan.key, key);
      // Encrypted now: neither the SQLite magic header nor a key-less read.
      expect(
        String.fromCharCodes(dbFile.readAsBytesSync().sublist(0, 15)),
        isNot('SQLite format 3'),
      );
      expect(await pragma('user_version', withKey: key), before);
      await expectLater(pragma('user_version'), throwsA(anything));

      final db = await openEncrypted();
      addTearDown(db.close);
      final notes = await db.notesDao.getAllNotes();
      expect(notes, hasLength(2));
      expect(notes.map((n) => n.plainContent), contains('legacy ZEBRA note number 1'));
      // Writing works on the migrated database too.
      await db.notesDao.createNote(
        id: 'after-upgrade',
        encryptedContent: 'ZW5j',
        plainContent: 'written after the upgrade',
      );
      expect((await db.notesDao.getAllNotes()).map((n) => n.id), contains('after-upgrade'));
    });

    test('migration flags the FTS index for rebuild, and the rebuild clears it',
        () async {
      await buildLegacyPlaintext();
      guard.prepare(dbFile: dbFile, key: key);
      expect(await pragma('application_id', withKey: key), kIndexRebuildPending);

      final db = await openEncrypted();
      addTearDown(db.close);
      // Whether the export also carries the index contents over depends on
      // the SQLCipher version (4.10.0 does); the flag is what makes the
      // rebuild reliable on builds where it does not.
      await db.ensureSearchHealthy();

      expect(await db.notesDao.ftsSearchNoteIds('ZEBRA'), hasLength(2));
      expect(await pragma('application_id', withKey: key), 0);
      // A second pass has nothing left to rebuild and changes nothing.
      await db.ensureSearchHealthy();
      expect(await db.notesDao.ftsSearchNoteIds('ZEBRA'), hasLength(2));
      expect(await pragma('application_id', withKey: key), 0);
    });

    test('keeps the untouched plaintext database as a backup', () async {
      await buildLegacyPlaintext();
      final original = dbFile.readAsBytesSync();
      guard.prepare(dbFile: dbFile, key: key);
      final backup = File('${dbFile.path}.plaintext-backup');
      expect(backup.readAsBytesSync(), original);
    });

    test('is a no-op on an already-encrypted database', () async {
      await buildLegacyPlaintext();
      guard.prepare(dbFile: dbFile, key: key);
      final fingerprint = dbFile.readAsBytesSync();

      final plan = guard.prepare(dbFile: dbFile, key: key);

      expect(plan.outcome, DbFileOutcome.ready);
      expect(dbFile.readAsBytesSync(), fingerprint);
    });

    test('reports a fresh install when there is no database', () {
      final plan = guard.prepare(dbFile: dbFile, key: key);
      expect(plan.outcome, DbFileOutcome.fresh);
      expect(plan.key, key);
      expect(dbFile.existsSync(), isFalse, reason: 'creating it is the caller’s job');
    });

    test('a zero-length file counts as encrypted and ready', () async {
      // SQLite treats an empty file as an empty database; nothing to migrate.
      dbFile.writeAsBytesSync(const []);
      final plan = guard.prepare(dbFile: dbFile, key: key);
      expect(plan.outcome, DbFileOutcome.ready);
    });

    test('finishes an encryption interrupted between the two renames', () async {
      await buildLegacyPlaintext();
      guard.prepare(dbFile: dbFile, key: key);
      // Undo the second rename: what a process kill in that window leaves.
      dbFile.renameSync('${dbFile.path}.encrypting');

      final plan = guard.prepare(dbFile: dbFile, key: key);

      expect(plan.outcome, DbFileOutcome.ready);
      final db = await openEncrypted();
      addTearDown(db.close);
      expect(await db.notesDao.getAllNotes(), hasLength(2));
    });

    test('restores from the backup when the database went missing', () async {
      await buildLegacyPlaintext();
      guard.prepare(dbFile: dbFile, key: key);
      final backup = File('${dbFile.path}.plaintext-backup');
      dbFile.deleteSync();
      backup.renameSync(dbFile.path);

      final plan = guard.prepare(dbFile: dbFile, key: key);

      expect(plan.outcome, DbFileOutcome.migrated);
      final db = await openEncrypted();
      addTearDown(db.close);
      expect(await db.notesDao.getAllNotes(), hasLength(2));
    });

    test('a lost key is recovered from the plaintext backup', () async {
      await buildLegacyPlaintext();
      guard.prepare(dbFile: dbFile, key: key);
      final previousEncrypted = dbFile.readAsBytesSync();

      // What a reset of secure storage looks like: the file is intact but
      // the app no longer holds the key it was encrypted with.
      final plan = guard.prepare(dbFile: dbFile, key: generateDatabaseKey());

      expect(plan.outcome, DbFileOutcome.migrated);
      final db = await AppDatabase.forTesting(
        NativeDatabase(dbFile, setup: (d) => d.execute(databaseKeyPragma(plan.key!))),
      );
      addTearDown(db.close);
      expect((await db.notesDao.getAllNotes()).map((n) => n.id),
          unorderedEquals(['legacy-0', 'legacy-1']));
      // The copy that could not be opened is kept, not deleted.
      final orphans = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('.orphan-'));
      expect(orphans.single.readAsBytesSync(), previousEncrypted);
    });

    test('with no backup left, a lost key moves the database aside and starts fresh',
        () async {
      await buildLegacyPlaintext();
      final plan = guard.prepare(dbFile: dbFile, key: key);
      File('${dbFile.path}.plaintext-backup').deleteSync();
      final encrypted = dbFile.readAsBytesSync();

      final afterLoss = guard.prepare(dbFile: dbFile, key: plan.key! + 'x');

      expect(afterLoss.outcome, DbFileOutcome.keyMismatch);
      expect(dbFile.existsSync(), isFalse, reason: 'so a fresh one can be created');
      final orphans = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('.orphan-'));
      expect(orphans.single.readAsBytesSync(), encrypted);

      // The next launch starts clean and can save.
      final fresh = guard.prepare(dbFile: dbFile, key: afterLoss.key!);
      expect(fresh.outcome, DbFileOutcome.fresh);
      final db = await AppDatabase.forTesting(
        NativeDatabase(dbFile, setup: (d) => d.execute(databaseKeyPragma(afterLoss.key!))),
      );
      addTearDown(db.close);
      await db.notesDao.createNote(
        id: 'new-start',
        encryptedContent: 'ZW5j',
        plainContent: 'after a lost key',
      );
      expect((await db.notesDao.getAllNotes()).map((n) => n.id), ['new-start']);
    });

    test('drops the plaintext backup once it has aged out', () async {
      await buildLegacyPlaintext();
      guard.prepare(dbFile: dbFile, key: key);
      final backup = File('${dbFile.path}.plaintext-backup');
      final migratedAt = DateTime(2026, 11, 20, 12);
      backup.setLastModifiedSync(migratedAt);

      guard.prepare(
        dbFile: dbFile,
        key: key,
        now: migratedAt.add(defaultBackupRetention - const Duration(days: 1)),
      );
      expect(backup.existsSync(), isTrue, reason: 'still inside the retention window');

      guard.prepare(
        dbFile: dbFile,
        key: key,
        now: migratedAt.add(defaultBackupRetention),
      );
      expect(backup.existsSync(), isFalse);
      // The live database is untouched by the cleanup.
      expect(await pragma('user_version', withKey: key), 23);
    });

    test('leaves the database usable, unencrypted, when encryption fails',
        () async {
      await buildLegacyPlaintext();
      final original = dbFile.readAsBytesSync();
      // A directory squatting on the encrypted copy's path: nothing can be
      // written there, so the export cannot complete.
      Directory('${dbFile.path}.encrypting').createSync();

      final plan = guard.prepare(dbFile: dbFile, key: key);

      expect(plan.outcome, DbFileOutcome.plaintext);
      expect(plan.key, isNull, reason: 'opening a plaintext file with a key always fails');
      expect(dbFile.readAsBytesSync(), original,
          reason: 'the original database must not be touched');
      final reopened = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(reopened.close);
      expect(await reopened.notesDao.getAllNotes(), hasLength(2));
    });
  }, skip: hasSqlCipher ? false : 'requires a SQLCipher library (e.g. apt install libsqlcipher1)');
}
