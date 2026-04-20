import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium_libs/sodium_libs_sumo.dart';

import 'package:anynote/core/backup/restore_service.dart';
import 'package:anynote/core/backup/restore_strategy.dart';
import 'package:anynote/core/crypto/crypto_service.dart';
import 'package:anynote/core/crypto/master_key.dart';
import 'package:anynote/core/database/app_database.dart';
import '../crypto/sodium_test_init.dart';

void main() {
  late AppDatabase db;
  late CryptoService crypto;
  late Uint8List testEncryptKey;

  setUpAll(() async {
    registerTestSodiumPlatform();
    await SodiumSumoInit.init();

    final salt = Uint8List.fromList(List.generate(32, (i) => i));
    final masterKey =
        await MasterKeyManager.deriveMasterKey('restore-test-password', salt);
    testEncryptKey = await MasterKeyManager.deriveEncryptKey(masterKey);
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    crypto = CryptoService();
    crypto.injectEncryptKey(testEncryptKey);
    await db.notesDao.getAllNotes();
  });

  tearDown(() async {
    await db.close();
  });

  // Helper: build encrypted backup bytes from inner data map.
  Future<Uint8List> _buildBackup(Map<String, dynamic> innerData) async {
    final backupKeyId = 'restore-test-key';
    final plaintext = jsonEncode(innerData);
    final encrypted = await crypto.encryptForItem(backupKeyId, plaintext);
    return Uint8List.fromList(utf8.encode(jsonEncode({
      'format': 'anynote-backup-v1',
      'backup_key_id': backupKeyId,
      'encrypted_data': encrypted,
    })));
  }

  group('restore', () {
    test('throws StateError when crypto is locked', () async {
      final lockedCrypto = CryptoService();
      final service = RestoreService(db, lockedCrypto);

      expect(
        () => service.restore(Uint8List(0), ConflictStrategy.skip),
        throwsA(isA<StateError>()),
      );
    });

    test('throws FormatException for unsupported format', () async {
      final service = RestoreService(db, crypto);
      final badData = Uint8List.fromList(utf8.encode(jsonEncode({
        'format': 'bad-format',
        'backup_key_id': 'k',
        'encrypted_data': 'd',
      })));

      expect(
        () => service.restore(badData, ConflictStrategy.skip),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on invalid JSON', () async {
      final service = RestoreService(db, crypto);

      expect(
        () => service.restore(
          Uint8List.fromList(utf8.encode('not json')),
          ConflictStrategy.skip,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws StateError when decryption fails', () async {
      final wrongCrypto = CryptoService();
      final wrongKey = Uint8List.fromList(List.generate(32, (i) => (i * 11 + 5) % 256));
      wrongCrypto.injectEncryptKey(wrongKey);

      final service = RestoreService(db, wrongCrypto);
      final backupData = await _buildBackup({
        'notes': [],
        'tags': [],
        'collections': [],
        'contents': [],
      });

      expect(
        () => service.restore(backupData, ConflictStrategy.skip),
        throwsA(isA<StateError>()),
      );
    });

    test('restores notes into empty database', () async {
      final service = RestoreService(db, crypto);
      final backupData = await _buildBackup({
        'notes': [
          {
            'id': 'note-r1',
            'encrypted_content': 'enc-c1',
            'encrypted_title': 'enc-t1',
            'plain_content': 'Hello World',
            'plain_title': 'Restored Note',
          },
        ],
        'tags': [],
        'collections': [],
        'contents': [],
      });

      final result = await service.restore(backupData, ConflictStrategy.skip);

      expect(result.restored, 1);
      expect(result.skipped, 0);
      expect(result.conflicts, 0);
      expect(result.hasErrors, isFalse);

      final note = await db.notesDao.getNoteById('note-r1');
      expect(note, isNotNull);
      expect(note!.plainContent, 'Hello World');
      expect(note.plainTitle, 'Restored Note');
    });

    test('restores tags into empty database', () async {
      final service = RestoreService(db, crypto);
      final backupData = await _buildBackup({
        'notes': [],
        'tags': [
          {
            'id': 'tag-r1',
            'encrypted_name': 'enc-tag1',
            'plain_name': 'Work',
          },
        ],
        'collections': [],
        'contents': [],
      });

      final result = await service.restore(backupData, ConflictStrategy.skip);

      expect(result.restored, 1);
      expect(result.hasErrors, isFalse);

      final tags = await db.tagsDao.getAllTags();
      expect(tags.length, 1);
      expect(tags[0].plainName, 'Work');
    });

    test('restores collections into empty database', () async {
      final service = RestoreService(db, crypto);
      final backupData = await _buildBackup({
        'notes': [],
        'tags': [],
        'collections': [
          {
            'id': 'col-r1',
            'encrypted_title': 'enc-col1',
            'plain_title': 'My Collection',
          },
        ],
        'contents': [],
      });

      final result = await service.restore(backupData, ConflictStrategy.skip);

      expect(result.restored, 1);

      final cols = await db.collectionsDao.getAllCollections();
      expect(cols.length, 1);
      expect(cols[0].plainTitle, 'My Collection');
    });

    test('restores AI-generated contents', () async {
      final service = RestoreService(db, crypto);
      final backupData = await _buildBackup({
        'notes': [],
        'tags': [],
        'collections': [],
        'contents': [
          {
            'id': 'content-r1',
            'encrypted_body': 'enc-body',
            'plain_body': 'AI generated text',
            'platform_style': 'xiaohongshu',
            'ai_model_used': 'gpt-4',
          },
        ],
      });

      final result = await service.restore(backupData, ConflictStrategy.skip);

      expect(result.restored, 1);

      final contents = await db.generatedContentsDao.getAll();
      expect(contents.length, 1);
      expect(contents[0].plainBody, 'AI generated text');
    });

    test('skip strategy skips conflicting notes', () async {
      await db.notesDao.createNote(
        id: 'note-conflict',
        encryptedContent: 'enc-original',
        plainContent: 'Original Content',
        plainTitle: 'Original Title',
      );

      final service = RestoreService(db, crypto);
      final backupData = await _buildBackup({
        'notes': [
          {
            'id': 'note-conflict',
            'encrypted_content': 'enc-new',
            'plain_content': 'New Content',
            'plain_title': 'New Title',
          },
        ],
        'tags': [],
        'collections': [],
        'contents': [],
      });

      final result = await service.restore(backupData, ConflictStrategy.skip);

      expect(result.restored, 0);
      expect(result.skipped, 1);
      expect(result.conflicts, 1);

      // Original note should remain unchanged
      final note = await db.notesDao.getNoteById('note-conflict');
      expect(note!.plainContent, 'Original Content');
    });

    test('overwrite strategy replaces conflicting notes', () async {
      await db.notesDao.createNote(
        id: 'note-overwrite',
        encryptedContent: 'enc-old',
        plainContent: 'Old Content',
        plainTitle: 'Old Title',
      );

      final service = RestoreService(db, crypto);
      final backupData = await _buildBackup({
        'notes': [
          {
            'id': 'note-overwrite',
            'encrypted_content': 'enc-new',
            'plain_content': 'New Content',
            'plain_title': 'New Title',
          },
        ],
        'tags': [],
        'collections': [],
        'contents': [],
      });

      final result = await service.restore(backupData, ConflictStrategy.overwrite);

      expect(result.restored, 1);
      expect(result.conflicts, 1);

      final note = await db.notesDao.getNoteById('note-overwrite');
      expect(note!.plainContent, 'New Content');
      expect(note.plainTitle, 'New Title');
    });

    test('keepBoth strategy creates note with (restored) suffix', () async {
      await db.notesDao.createNote(
        id: 'note-both',
        encryptedContent: 'enc-existing',
        plainContent: 'Existing Content',
        plainTitle: 'Existing Title',
      );

      final service = RestoreService(db, crypto);
      final backupData = await _buildBackup({
        'notes': [
          {
            'id': 'note-both',
            'encrypted_content': 'enc-new',
            'encrypted_title': 'enc-new-title',
            'plain_content': 'Restored Content',
            'plain_title': 'Restored Title',
          },
        ],
        'tags': [],
        'collections': [],
        'contents': [],
      });

      final result = await service.restore(backupData, ConflictStrategy.keepBoth);

      expect(result.restored, 1);
      expect(result.conflicts, 1);

      // Original should still exist
      final original = await db.notesDao.getNoteById('note-both');
      expect(original!.plainTitle, 'Existing Title');

      // A new note with (restored) suffix should also exist
      final allNotes = await db.notesDao.getAllNotes();
      final restoredNote = allNotes.firstWhere(
        (n) => n.id != 'note-both',
      );
      expect(restoredNote.plainTitle, 'Restored Title (restored)');
      expect(restoredNote.plainContent, 'Restored Content');
    });

    test('keepBoth strategy falls back when plain_content is null', () async {
      await db.notesDao.createNote(
        id: 'note-both-nopl',
        encryptedContent: 'enc-existing',
      );

      final service = RestoreService(db, crypto);
      final backupData = await _buildBackup({
        'notes': [
          {
            'id': 'note-both-nopl',
            'encrypted_content': 'enc-new-no-plain',
          },
        ],
        'tags': [],
        'collections': [],
        'contents': [],
      });

      final result = await service.restore(backupData, ConflictStrategy.keepBoth);

      expect(result.restored, 1);
      expect(result.hasErrors, isFalse);
    });

    test('skip strategy skips conflicting tags', () async {
      await db.tagsDao.createTag(
        id: 'tag-conflict',
        encryptedName: 'enc-old-tag',
        plainName: 'OldTag',
      );

      final service = RestoreService(db, crypto);
      final backupData = await _buildBackup({
        'notes': [],
        'tags': [
          {'id': 'tag-conflict', 'encrypted_name': 'enc-new-tag', 'plain_name': 'NewTag'},
        ],
        'collections': [],
        'contents': [],
      });

      final result = await service.restore(backupData, ConflictStrategy.skip);

      expect(result.skipped, 1);
      expect(result.conflicts, 1);

      final tags = await db.tagsDao.getAllTags();
      expect(tags[0].plainName, 'OldTag');
    });

    test('overwrite strategy replaces conflicting tags', () async {
      await db.tagsDao.createTag(
        id: 'tag-overwrite',
        encryptedName: 'enc-old',
        plainName: 'OldTag',
      );

      final service = RestoreService(db, crypto);
      final backupData = await _buildBackup({
        'notes': [],
        'tags': [
          {'id': 'tag-overwrite', 'encrypted_name': 'enc-new', 'plain_name': 'NewTag'},
        ],
        'collections': [],
        'contents': [],
      });

      final result = await service.restore(backupData, ConflictStrategy.overwrite);

      expect(result.restored, 1);

      final tags = await db.tagsDao.getAllTags();
      expect(tags[0].plainName, 'NewTag');
    });

    test('keepBoth strategy creates tag with (restored) suffix', () async {
      await db.tagsDao.createTag(
        id: 'tag-both',
        encryptedName: 'enc-old',
        plainName: 'OldTag',
      );

      final service = RestoreService(db, crypto);
      final backupData = await _buildBackup({
        'notes': [],
        'tags': [
          {'id': 'tag-both', 'encrypted_name': 'enc-new', 'plain_name': 'NewTag'},
        ],
        'collections': [],
        'contents': [],
      });

      final result = await service.restore(backupData, ConflictStrategy.keepBoth);

      expect(result.restored, 1);

      final tags = await db.tagsDao.getAllTags();
      expect(tags.length, 2);
      final restoredTag = tags.firstWhere((t) => t.id != 'tag-both');
      expect(restoredTag.plainName, 'NewTag (restored)');
    });

    test('overwrite strategy replaces conflicting collections', () async {
      await db.collectionsDao.createCollection(
        id: 'col-overwrite',
        encryptedTitle: 'enc-old',
        plainTitle: 'Old Collection',
      );

      final service = RestoreService(db, crypto);
      final backupData = await _buildBackup({
        'notes': [],
        'tags': [],
        'collections': [
          {'id': 'col-overwrite', 'encrypted_title': 'enc-new', 'plain_title': 'New Collection'},
        ],
        'contents': [],
      });

      final result = await service.restore(backupData, ConflictStrategy.overwrite);

      expect(result.restored, 1);

      final cols = await db.collectionsDao.getAllCollections();
      expect(cols[0].plainTitle, 'New Collection');
    });

    test('skip strategy skips conflicting contents', () async {
      await db.generatedContentsDao.create(
        id: 'content-conflict',
        encryptedBody: 'enc-old-body',
        plainBody: 'Old body',
        platformStyle: 'generic',
        aiModelUsed: 'test',
      );

      final service = RestoreService(db, crypto);
      final backupData = await _buildBackup({
        'notes': [],
        'tags': [],
        'collections': [],
        'contents': [
          {
            'id': 'content-conflict',
            'encrypted_body': 'enc-new-body',
            'plain_body': 'New body',
          },
        ],
      });

      final result = await service.restore(backupData, ConflictStrategy.skip);

      expect(result.skipped, 1);
      expect(result.conflicts, 1);

      final contents = await db.generatedContentsDao.getAll();
      expect(contents[0].plainBody, 'Old body');
    });

    test('restores mixed item types in one operation', () async {
      final service = RestoreService(db, crypto);
      final backupData = await _buildBackup({
        'notes': [
          {'id': 'n1', 'encrypted_content': 'enc-n1', 'plain_content': 'Note 1'},
        ],
        'tags': [
          {'id': 't1', 'encrypted_name': 'enc-t1', 'plain_name': 'Tag1'},
          {'id': 't2', 'encrypted_name': 'enc-t2', 'plain_name': 'Tag2'},
        ],
        'collections': [
          {'id': 'c1', 'encrypted_title': 'enc-c1', 'plain_title': 'Col1'},
        ],
        'contents': [],
      });

      final result = await service.restore(backupData, ConflictStrategy.skip);

      expect(result.restored, 4);
      expect(result.conflicts, 0);
      expect(result.hasErrors, isFalse);
    });

    test('reports per-item errors without aborting the entire restore', () async {
      // Create a backup with two notes: one valid and one that will cause an error
      // because the DAO will throw on an empty id (we simulate via the DB).
      final service = RestoreService(db, crypto);

      // Pre-create a note that will conflict with skip strategy (no error)
      // And include a note with no 'id' key to cause a type cast error
      final backupData = await _buildBackup({
        'notes': [
          {'id': 'n-good', 'encrypted_content': 'enc-good', 'plain_content': 'Good'},
          // This will cause a crash because 'id' is missing -> cast to String fails
          {'encrypted_content': 'enc-bad'},
        ],
        'tags': [],
        'collections': [],
        'contents': [],
      });

      final result = await service.restore(backupData, ConflictStrategy.skip);

      expect(result.restored, 1);
      expect(result.hasErrors, isTrue);
      expect(result.errors.length, 1);
    });

    test('calls progress callback for each item', () async {
      final service = RestoreService(db, crypto);
      final backupData = await _buildBackup({
        'notes': [
          {'id': 'n1', 'encrypted_content': 'enc1', 'plain_content': 'A'},
          {'id': 'n2', 'encrypted_content': 'enc2', 'plain_content': 'B'},
        ],
        'tags': [
          {'id': 't1', 'encrypted_name': 'enc-t1', 'plain_name': 'Tag1'},
        ],
        'collections': [],
        'contents': [],
      });

      final progressCalls = <RestoreProgress>[];
      final result = await service.restore(
        backupData,
        ConflictStrategy.skip,
        onProgress: progressCalls.add,
      );

      expect(result.restored, 3);
      // 3 items total, so we expect progress calls.
      // Each item generates at least one progress call (from onProgress at bottom of loop).
      // Plus one initial call before notes loop.
      expect(progressCalls.length, greaterThanOrEqualTo(3));

      // Verify progress steps
      expect(progressCalls.any((p) => p.step == 'notes'), isTrue);
      expect(progressCalls.any((p) => p.step == 'tags'), isTrue);
    });
  });
}
