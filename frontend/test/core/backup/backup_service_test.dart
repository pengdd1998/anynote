import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium_libs/sodium_libs_sumo.dart';

import 'package:anynote/core/backup/backup_service.dart';
import 'package:anynote/core/crypto/crypto_service.dart';
import 'package:anynote/core/crypto/master_key.dart';
import 'package:anynote/core/database/app_database.dart';
import '../crypto/sodium_test_init.dart';

void main() {
  late AppDatabase db;
  late CryptoService crypto;
  late BackupService backupService;
  late Uint8List testEncryptKey;

  setUpAll(() async {
    registerTestSodiumPlatform();
    await SodiumSumoInit.init();

    final salt = Uint8List.fromList(List.generate(32, (i) => i));
    final masterKey =
        await MasterKeyManager.deriveMasterKey('backup-test-password', salt);
    testEncryptKey = await MasterKeyManager.deriveEncryptKey(masterKey);
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    crypto = CryptoService();
    crypto.injectEncryptKey(testEncryptKey);
    backupService = BackupService(db, crypto);

    // Force migrations
    await db.notesDao.getAllNotes();
  });

  tearDown(() async {
    await db.close();
  });

  group('exportBackup', () {
    test('throws StateError when crypto is locked', () async {
      final lockedCrypto = CryptoService();
      final service = BackupService(db, lockedCrypto);

      expect(
        () => service.exportBackup(),
        throwsA(isA<StateError>()),
      );
    });

    test('exports empty backup with valid structure', () async {
      final data = await backupService.exportBackup();

      final jsonStr = utf8.decode(data);
      final envelope = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(envelope['format'], 'anynote-backup-v1');
      expect(envelope['backup_key_id'], isNotNull);
      expect(envelope['encrypted_data'], isNotNull);

      // Decrypt and verify structure
      final backupKeyId = envelope['backup_key_id'] as String;
      final encryptedData = envelope['encrypted_data'] as String;
      final decrypted = await crypto.decryptForItem(backupKeyId, encryptedData);
      expect(decrypted, isNotNull);

      final backupData = jsonDecode(decrypted!) as Map<String, dynamic>;
      expect(backupData['version'], 1);
      expect(backupData['exported_at'], isNotNull);
      expect((backupData['notes'] as List).length, 0);
      expect((backupData['tags'] as List).length, 0);
      expect((backupData['collections'] as List).length, 0);
    });

    test('exports notes in backup', () async {
      await db.notesDao.createNote(
        id: 'note-backup-1',
        encryptedContent: 'enc-content-1',
        plainContent: 'plain content 1',
        plainTitle: 'Note One',
      );
      await db.notesDao.createNote(
        id: 'note-backup-2',
        encryptedContent: 'enc-content-2',
        plainContent: 'plain content 2',
        plainTitle: 'Note Two',
      );

      final data = await backupService.exportBackup();
      final jsonStr = utf8.decode(data);
      final envelope = jsonDecode(jsonStr) as Map<String, dynamic>;
      final decrypted = await crypto.decryptForItem(
        envelope['backup_key_id'] as String,
        envelope['encrypted_data'] as String,
      );
      final backupData = jsonDecode(decrypted!) as Map<String, dynamic>;

      final notes = backupData['notes'] as List;
      expect(notes.length, 2);

      final note1 = notes.firstWhere(
          (n) => (n as Map<String, dynamic>)['id'] == 'note-backup-1',)
          as Map<String, dynamic>;
      expect(note1['plain_content'], 'plain content 1');
      expect(note1['plain_title'], 'Note One');
      expect(note1['encrypted_content'], 'enc-content-1');
    });

    test('exports tags in backup', () async {
      await db.tagsDao.createTag(
        id: 'tag-backup-1',
        encryptedName: 'enc-tag-1',
        plainName: 'Work',
      );

      final data = await backupService.exportBackup();
      final jsonStr = utf8.decode(data);
      final envelope = jsonDecode(jsonStr) as Map<String, dynamic>;
      final decrypted = await crypto.decryptForItem(
        envelope['backup_key_id'] as String,
        envelope['encrypted_data'] as String,
      );
      final backupData = jsonDecode(decrypted!) as Map<String, dynamic>;

      final tags = backupData['tags'] as List;
      expect(tags.length, 1);
      final tag = tags[0] as Map<String, dynamic>;
      expect(tag['id'], 'tag-backup-1');
      expect(tag['plain_name'], 'Work');
    });

    test('exports collections in backup', () async {
      await db.collectionsDao.createCollection(
        id: 'col-backup-1',
        encryptedTitle: 'enc-col-1',
        plainTitle: 'Projects',
      );

      final data = await backupService.exportBackup();
      final jsonStr = utf8.decode(data);
      final envelope = jsonDecode(jsonStr) as Map<String, dynamic>;
      final decrypted = await crypto.decryptForItem(
        envelope['backup_key_id'] as String,
        envelope['encrypted_data'] as String,
      );
      final backupData = jsonDecode(decrypted!) as Map<String, dynamic>;

      final collections = backupData['collections'] as List;
      expect(collections.length, 1);
      final col = collections[0] as Map<String, dynamic>;
      expect(col['id'], 'col-backup-1');
      expect(col['plain_title'], 'Projects');
    });
  });

  group('importBackup', () {
    test('throws StateError when crypto is locked', () async {
      final lockedCrypto = CryptoService();
      final service = BackupService(db, lockedCrypto);

      expect(
        () => service.importBackup(Uint8List(0)),
        throwsA(isA<StateError>()),
      );
    });

    test('throws FormatException for unsupported format', () async {
      final badData = utf8.encode(
        jsonEncode({
          'format': 'unknown-format-v99',
          'backup_key_id': 'test',
          'encrypted_data': 'test',
        }),
      );

      expect(
        () => backupService.importBackup(Uint8List.fromList(badData)),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on invalid JSON', () async {
      expect(
        () => backupService.importBackup(Uint8List.fromList(utf8.encode('not json'))),
        throwsA(isA<FormatException>()),
      );
    });

    test('round-trip: export then import restores notes', () async {
      // Create some data
      await db.notesDao.createNote(
        id: 'note-rt-1',
        encryptedContent: 'enc-1',
        plainContent: 'Content 1',
        plainTitle: 'Title 1',
      );
      await db.notesDao.createNote(
        id: 'note-rt-2',
        encryptedContent: 'enc-2',
        plainContent: 'Content 2',
        plainTitle: 'Title 2',
      );

      // Export
      final backupData = await backupService.exportBackup();

      // Create a new database to import into
      final db2 = AppDatabase.forTesting(NativeDatabase.memory());
      await db2.notesDao.getAllNotes(); // Force migrations
      final crypto2 = CryptoService();
      crypto2.injectEncryptKey(testEncryptKey);
      final restoreService = BackupService(db2, crypto2);

      // Import
      final count = await restoreService.importBackup(backupData);
      expect(count, 2);

      // Verify
      final note1 = await db2.notesDao.getNoteById('note-rt-1');
      expect(note1, isNotNull);
      expect(note1!.plainContent, 'Content 1');
      expect(note1.plainTitle, 'Title 1');

      final note2 = await db2.notesDao.getNoteById('note-rt-2');
      expect(note2, isNotNull);
      expect(note2!.plainContent, 'Content 2');
      expect(note2.plainTitle, 'Title 2');

      await db2.close();
    });

    test('round-trip: export then import restores tags', () async {
      await db.tagsDao.createTag(
        id: 'tag-rt-1',
        encryptedName: 'enc-tag',
        plainName: 'Work',
      );

      final backupData = await backupService.exportBackup();

      final db2 = AppDatabase.forTesting(NativeDatabase.memory());
      await db2.notesDao.getAllNotes();
      final crypto2 = CryptoService();
      crypto2.injectEncryptKey(testEncryptKey);
      final restoreService = BackupService(db2, crypto2);

      final count = await restoreService.importBackup(backupData);
      expect(count, 1);

      final tags = await db2.tagsDao.getAllTags();
      expect(tags.length, 1);
      expect(tags[0].plainName, 'Work');

      await db2.close();
    });

    test('round-trip: export then import restores collections', () async {
      await db.collectionsDao.createCollection(
        id: 'col-rt-1',
        encryptedTitle: 'enc-col',
        plainTitle: 'My Collection',
      );

      final backupData = await backupService.exportBackup();

      final db2 = AppDatabase.forTesting(NativeDatabase.memory());
      await db2.notesDao.getAllNotes();
      final crypto2 = CryptoService();
      crypto2.injectEncryptKey(testEncryptKey);
      final restoreService = BackupService(db2, crypto2);

      final count = await restoreService.importBackup(backupData);
      expect(count, 1);

      final cols = await db2.collectionsDao.getAllCollections();
      expect(cols.length, 1);
      expect(cols[0].plainTitle, 'My Collection');

      await db2.close();
    });

    test('import skips already existing items', () async {
      await db.notesDao.createNote(
        id: 'note-skip',
        encryptedContent: 'enc-original',
        plainContent: 'Original Content',
      );

      final backupData = await backupService.exportBackup();

      // Import into the same database (note already exists)
      final count = await backupService.importBackup(backupData);
      expect(count, 0);

      // Original content should be unchanged
      final note = await db.notesDao.getNoteById('note-skip');
      expect(note!.plainContent, 'Original Content');
    });

    test('import with wrong key throws StateError', () async {
      await db.notesDao.createNote(
        id: 'note-wrong-key',
        encryptedContent: 'enc',
        plainContent: 'content',
      );

      final backupData = await backupService.exportBackup();

      // Use a different encrypt key for import
      final wrongCrypto = CryptoService();
      final wrongKey = Uint8List.fromList(List.generate(32, (i) => (i * 13 + 7) % 256));
      wrongCrypto.injectEncryptKey(wrongKey);
      final wrongService = BackupService(db, wrongCrypto);

      expect(
        () => wrongService.importBackup(backupData),
        throwsA(isA<StateError>()),
      );
    });
  });
}
