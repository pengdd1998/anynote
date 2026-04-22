import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium_libs/sodium_libs_sumo.dart';

import 'package:anynote/core/backup/backup_verifier.dart';
import 'package:anynote/core/crypto/crypto_service.dart';
import 'package:anynote/core/crypto/decryption_exception.dart';
import 'package:anynote/core/crypto/master_key.dart';
import 'package:anynote/core/database/app_database.dart';
import '../crypto/sodium_test_init.dart';

void main() {
  late AppDatabase db;
  late CryptoService crypto;
  late Uint8List testEncryptKey;
  late Directory tempDir;

  setUpAll(() async {
    registerTestSodiumPlatform();
    await SodiumSumoInit.init();

    final salt = Uint8List.fromList(List.generate(32, (i) => i));
    final masterKey =
        await MasterKeyManager.deriveMasterKey('verifier-test-password', salt);
    testEncryptKey = await MasterKeyManager.deriveEncryptKey(masterKey);

    tempDir = Directory.systemTemp.createTempSync('backup_verifier_test_');
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

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // -- Helper to build a backup JSON envelope --
  String _writeBackupFile(Map<String, dynamic> envelope) {
    final path =
        '${tempDir.path}/backup_${DateTime.now().microsecondsSinceEpoch}.json';
    File(path).writeAsStringSync(jsonEncode(envelope));
    return path;
  }

  // Use the real crypto service to encrypt so verify() can decrypt.
  Future<String> _realEncryptBackup(Map<String, dynamic> innerData) async {
    final backupKeyId = 'real-backup-key';
    final plaintext = jsonEncode(innerData);
    final encrypted = await crypto.encryptForItem(backupKeyId, plaintext);
    return _writeBackupFile({
      'format': 'anynote-backup-v1',
      'backup_key_id': backupKeyId,
      'encrypted_data': encrypted,
    });
  }

  group('BackupInfo', () {
    test('isValid returns true when errors is empty', () {
      const info = BackupInfo(
        format: 'anynote-backup-v1',
        backupKeyId: 'key-123',
        totalItems: 5,
        noteCount: 3,
        tagCount: 2,
      );
      expect(info.isValid, isTrue);
      expect(info.hasItems, isTrue);
    });

    test('isValid returns false when errors is non-empty', () {
      const info = BackupInfo(
        format: '',
        backupKeyId: '',
        errors: ['Something wrong'],
      );
      expect(info.isValid, isFalse);
    });

    test('hasItems returns false when totalItems is zero', () {
      const info = BackupInfo(format: 'anynote-backup-v1', backupKeyId: 'k');
      expect(info.hasItems, isFalse);
    });

    test('default values are correct', () {
      const info = BackupInfo(format: 'anynote-backup-v1', backupKeyId: 'k');
      expect(info.totalItems, 0);
      expect(info.noteCount, 0);
      expect(info.tagCount, 0);
      expect(info.collectionCount, 0);
      expect(info.contentCount, 0);
      expect(info.exportedAt, isNull);
      expect(info.version, 0);
      expect(info.canDecrypt, isFalse);
      expect(info.errors, isEmpty);
    });
  });

  group('RestorePreview', () {
    test('totalConflicts sums all existing counts', () {
      const preview = RestorePreview(
        existingNoteCount: 3,
        existingTagCount: 2,
        existingCollectionCount: 1,
        existingContentCount: 4,
      );
      expect(preview.totalConflicts, 10);
      expect(preview.hasConflicts, isTrue);
    });

    test('hasConflicts is false when all counts are zero', () {
      const preview = RestorePreview();
      expect(preview.hasConflicts, isFalse);
      expect(preview.totalConflicts, 0);
    });

    test('stores note titles and date ranges', () {
      final early = DateTime(2025, 1, 1);
      final late = DateTime(2026, 12, 31);
      final preview = RestorePreview(
        noteTitles: ['Note A', 'Note B'],
        earliestDate: early,
        latestDate: late,
        noteCount: 2,
      );
      expect(preview.noteTitles, ['Note A', 'Note B']);
      expect(preview.earliestDate, early);
      expect(preview.latestDate, late);
      expect(preview.noteCount, 2);
    });
  });

  group('verify', () {
    test('returns error for non-existent file', () async {
      final verifier = BackupVerifier(crypto);
      final result = await verifier.verify('/nonexistent/path/backup.json');

      expect(result.isValid, isFalse);
      expect(result.errors, contains('Backup file not found'));
    });

    test('returns error for empty file', () async {
      final path = '${tempDir.path}/empty_backup.json';
      File(path).writeAsStringSync('');
      addTearDown(() => File(path).deleteSync());

      final verifier = BackupVerifier(crypto);
      final result = await verifier.verify(path);

      expect(result.isValid, isFalse);
      expect(result.errors, contains('Backup file is empty'));
    });

    test('returns error for invalid JSON', () async {
      final path = _writeBackupFile({'not': 'valid envelope'});

      final verifier = BackupVerifier(crypto);
      final result = await verifier.verify(path);

      expect(result.isValid, isFalse);
      // Will fail because format is not 'anynote-backup-v1'
      expect(result.errors, isNotEmpty);
    });

    test('returns error for unsupported format', () async {
      final path = _writeBackupFile({
        'format': 'unknown-format-v99',
        'backup_key_id': 'key-1',
        'encrypted_data': 'data',
      });

      final verifier = BackupVerifier(crypto);
      final result = await verifier.verify(path);

      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('Unsupported backup format'));
    });

    test('returns error for missing backup_key_id', () async {
      final path = _writeBackupFile({
        'format': 'anynote-backup-v1',
        'encrypted_data': 'some-data',
      });

      final verifier = BackupVerifier(crypto);
      final result = await verifier.verify(path);

      expect(result.isValid, isFalse);
      expect(
          result.errors, contains('Missing backup_key_id in backup envelope'));
    });

    test('returns error for missing encrypted_data', () async {
      final path = _writeBackupFile({
        'format': 'anynote-backup-v1',
        'backup_key_id': 'key-1',
      });

      final verifier = BackupVerifier(crypto);
      final result = await verifier.verify(path);

      expect(result.isValid, isFalse);
      expect(
          result.errors, contains('Missing encrypted_data in backup envelope'));
    });

    test(
        'returns both errors when backup_key_id and encrypted_data are missing',
        () async {
      final path = _writeBackupFile({
        'format': 'anynote-backup-v1',
      });

      final verifier = BackupVerifier(crypto);
      final result = await verifier.verify(path);

      expect(result.isValid, isFalse);
      expect(result.errors.length, 2);
    });

    test('reports encryption keys not unlocked when crypto is locked',
        () async {
      final lockedCrypto = CryptoService();
      final verifier = BackupVerifier(lockedCrypto);

      final path = _writeBackupFile({
        'format': 'anynote-backup-v1',
        'backup_key_id': 'key-1',
        'encrypted_data': 'data',
      });

      final result = await verifier.verify(path);

      expect(result.isValid, isFalse);
      expect(
          result.errors,
          contains(
            'Encryption keys not unlocked. Cannot verify backup contents.',
          ));
    });

    test('reports decryption failure when key does not match', () async {
      final wrongCrypto = CryptoService();
      final wrongKey =
          Uint8List.fromList(List.generate(32, (i) => (i * 17 + 3) % 256));
      wrongCrypto.injectEncryptKey(wrongKey);

      // Create a backup encrypted with the real crypto
      final backupPath = await _realEncryptBackup({
        'version': 1,
        'exported_at': '2026-01-01T00:00:00Z',
        'notes': [
          {'id': 'n1'}
        ],
      });

      final verifier = BackupVerifier(wrongCrypto);
      final result = await verifier.verify(backupPath);

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('Decryption failed')), isTrue);
    });

    test('successfully decrypts and counts items', () async {
      final backupPath = await _realEncryptBackup({
        'version': 1,
        'exported_at': '2026-04-15T10:30:00Z',
        'notes': [
          {'id': 'n1'},
          {'id': 'n2'},
        ],
        'tags': [
          {'id': 't1'},
        ],
        'collections': [
          {'id': 'c1'},
          {'id': 'c2'},
          {'id': 'c3'},
        ],
        'contents': [
          {'id': 'g1'},
        ],
      });

      final verifier = BackupVerifier(crypto);
      final result = await verifier.verify(backupPath);

      expect(result.isValid, isTrue);
      expect(result.format, 'anynote-backup-v1');
      expect(result.backupKeyId, 'real-backup-key');
      expect(result.canDecrypt, isTrue);
      expect(result.version, 1);
      expect(result.exportedAt, '2026-04-15T10:30:00Z');
      expect(result.noteCount, 2);
      expect(result.tagCount, 1);
      expect(result.collectionCount, 3);
      expect(result.contentCount, 1);
      expect(result.totalItems, 7);
    });

    test('handles backup with missing optional fields gracefully', () async {
      final backupPath = await _realEncryptBackup({
        // No version, exported_at, or content arrays
        'notes': [],
      });

      final verifier = BackupVerifier(crypto);
      final result = await verifier.verify(backupPath);

      expect(result.isValid, isTrue);
      expect(result.version, 0);
      expect(result.exportedAt, isNull);
      expect(result.noteCount, 0);
      expect(result.tagCount, 0);
      expect(result.collectionCount, 0);
      expect(result.contentCount, 0);
      expect(result.totalItems, 0);
    });
  });

  group('preview', () {
    test('throws StateError when crypto is locked', () async {
      final lockedCrypto = CryptoService();
      final verifier = BackupVerifier(lockedCrypto);

      expect(
        () => verifier.preview('/dummy', {}, {}, {}, {}),
        throwsA(isA<StateError>()),
      );
    });

    test('throws DecryptionException when decryption fails', () async {
      // Use a crypto with a wrong key -- the encrypted_data was created with
      // the real key, so wrong key will fail decryption.
      final wrongCrypto = CryptoService();
      final wrongKey =
          Uint8List.fromList(List.generate(32, (i) => (i * 7 + 11) % 256));
      wrongCrypto.injectEncryptKey(wrongKey);

      final backupPath = await _realEncryptBackup({
        'version': 1,
        'notes': [],
      });

      final verifier = BackupVerifier(wrongCrypto);
      expect(
        () => verifier.preview(backupPath, {}, {}, {}, {}),
        throwsA(isA<DecryptionException>()),
      );
    });

    test('returns correct counts for empty backup', () async {
      final backupPath = await _realEncryptBackup({
        'version': 1,
        'notes': [],
        'tags': [],
        'collections': [],
        'contents': [],
      });

      final verifier = BackupVerifier(crypto);
      final preview = await verifier.preview(backupPath, {}, {}, {}, {});

      expect(preview.noteCount, 0);
      expect(preview.tagCount, 0);
      expect(preview.collectionCount, 0);
      expect(preview.contentCount, 0);
      expect(preview.noteTitles, isEmpty);
      expect(preview.hasConflicts, isFalse);
    });

    test('extracts note titles and date ranges', () async {
      final backupPath = await _realEncryptBackup({
        'version': 1,
        'notes': [
          {
            'id': 'n1',
            'plain_title': 'First Note',
            'created_at': '2025-06-01T08:00:00Z',
          },
          {
            'id': 'n2',
            'plain_title': 'Second Note',
            'created_at': '2026-03-15T14:30:00Z',
          },
        ],
        'tags': [],
        'collections': [],
        'contents': [],
      });

      final verifier = BackupVerifier(crypto);
      final preview = await verifier.preview(backupPath, {}, {}, {}, {});

      expect(preview.noteTitles, ['First Note', 'Second Note']);
      expect(preview.noteCount, 2);
      expect(preview.earliestDate, DateTime.utc(2025, 6, 1, 8, 0, 0));
      expect(preview.latestDate, DateTime.utc(2026, 3, 15, 14, 30, 0));
    });

    test('uses (encrypted) placeholder when plain_title is missing', () async {
      final backupPath = await _realEncryptBackup({
        'version': 1,
        'notes': [
          {'id': 'n-no-title'},
        ],
        'tags': [],
        'collections': [],
        'contents': [],
      });

      final verifier = BackupVerifier(crypto);
      final preview = await verifier.preview(backupPath, {}, {}, {}, {});

      expect(preview.noteTitles, ['(encrypted)']);
    });

    test('detects conflicts with existing items', () async {
      final backupPath = await _realEncryptBackup({
        'version': 1,
        'notes': [
          {'id': 'n1', 'plain_title': 'Existing'},
          {'id': 'n2', 'plain_title': 'New'},
        ],
        'tags': [
          {'id': 't1'},
          {'id': 't2'},
        ],
        'collections': [
          {'id': 'c1'},
        ],
        'contents': [
          {'id': 'g1'},
          {'id': 'g2'},
        ],
      });

      final existingNoteIds = {'n1'};
      final existingTagIds = {'t1'};
      final existingCollectionIds = <String>{};
      final existingContentIds = {'g1', 'g2'};

      final verifier = BackupVerifier(crypto);
      final preview = await verifier.preview(
        backupPath,
        existingNoteIds,
        existingTagIds,
        existingCollectionIds,
        existingContentIds,
      );

      expect(preview.existingNoteCount, 1);
      expect(preview.existingTagCount, 1);
      expect(preview.existingCollectionCount, 0);
      expect(preview.existingContentCount, 2);
      expect(preview.totalConflicts, 4);
      expect(preview.hasConflicts, isTrue);
    });

    test('skips unparseable dates gracefully', () async {
      final backupPath = await _realEncryptBackup({
        'version': 1,
        'notes': [
          {'id': 'n1', 'plain_title': 'Bad Date', 'created_at': 'not-a-date'},
        ],
        'tags': [],
        'collections': [],
        'contents': [],
      });

      final verifier = BackupVerifier(crypto);
      final preview = await verifier.preview(backupPath, {}, {}, {}, {});

      expect(preview.noteTitles, ['Bad Date']);
      expect(preview.earliestDate, isNull);
      expect(preview.latestDate, isNull);
    });
  });
}
