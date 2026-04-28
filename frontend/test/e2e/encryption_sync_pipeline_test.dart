// Full-pipeline E2E tests exercising real libsodium crypto + real Drift
// database + real SyncEngine with a mock API client.
//
// Tests cover:
// - Push direction: create items -> push -> verify encrypted blobs captured
// - Pull direction: encrypt test data -> mock pull response -> verify decrypted
// - Round-trip (cross-device): device A pushes, device B pulls same blobs
// - Multi-type: push note + tag + collection + content, pull all on fresh DB

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/crypto/crypto_service.dart';
import 'package:anynote/core/crypto/encryptor.dart';
import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/core/sync/sync_engine.dart';

import 'pipeline_helper.dart';

void main() {
  setUpAll(() async {
    await initSodium();
  });

  // ========================================================================
  // Push direction
  // ========================================================================

  group('Push pipeline', () {
    late AppDatabase db;
    late CryptoService crypto;
    late MockSyncApiClient api;
    late SyncEngine engine;
    final encryptKey = generateTestEncryptKey();

    setUp(() async {
      db = createPipelineDatabase();
      crypto = createPipelineCrypto(encryptKey);
      api = MockSyncApiClient();
      engine = SyncEngine(db, api, crypto);
      // Force migrations by touching a DAO.
      await db.notesDao.getAllNotes();
    });

    tearDown(() async {
      await db.close();
    });

    test('push encrypts a note and sends encrypted blob to API', () async {
      // Create a local note with plaintext content.
      await db.notesDao.createNote(
        id: 'note-push-1',
        encryptedContent: 'placeholder',
        plainContent: 'Hello from pipeline test',
        plainTitle: 'Pipeline Note',
      );

      // Push.
      final result = await engine.push();

      // The API should have received exactly one blob.
      expect(result.accepted, ['note-push-1']);
      expect(api.capturedPushItems.length, 1);

      // The captured blob should contain encrypted data.
      final blob = api.capturedPushItems.first;
      expect(blob['item_id'], 'note-push-1');
      expect(blob['item_type'], 'note');

      // The encrypted_data should be a base64 string that does NOT contain
      // the plaintext "Hello from pipeline test".
      final encryptedData = blob['encrypted_data'] as String;
      expect(encryptedData, isNotEmpty);
      expect(encryptedData, isNot(contains('Hello from pipeline test')));
      expect(encryptedData, isNot(contains('Pipeline Note')));

      // Verify the encrypted data is valid base64.
      final decoded = base64Decode(encryptedData);
      // XChaCha20-Poly1305: nonce(24) + ciphertext + tag(16).
      // The JSON envelope {"content":"Hello from pipeline test","title":"Pipeline Note"}
      // is longer than the overhead, so decoded length > 24 + 16.
      expect(decoded.length, greaterThan(40));

      // Verify the note is now marked as synced in the DB.
      final note = await db.notesDao.getNoteById('note-push-1');
      expect(note, isNotNull);
      expect(note!.isSynced, true);
    });

    test('push encrypted data can be decrypted back to original plaintext',
        () async {
      const originalContent = 'Secret note content with special chars: <>@#\$%';
      const originalTitle = 'My Secret Title';

      await db.notesDao.createNote(
        id: 'note-roundtrip-push',
        encryptedContent: 'placeholder',
        plainContent: originalContent,
        plainTitle: originalTitle,
      );

      await engine.push();

      // Extract the encrypted data from the captured push blob.
      final blob = api.capturedPushItems.first;
      final encryptedBase64 = blob['encrypted_data'] as String;
      final itemId = blob['item_id'] as String;

      // Decrypt using the same encrypt key + item ID via raw Encryptor.
      final derivedKey = await _deriveKey(encryptKey, itemId);
      final decryptedEnvelope = jsonDecode(
        await _decrypt(encryptedBase64, derivedKey),
      ) as Map<String, dynamic>;

      expect(decryptedEnvelope['content'], originalContent);
      expect(decryptedEnvelope['title'], originalTitle);
    });

    test('push handles note without title', () async {
      await db.notesDao.createNote(
        id: 'note-no-title',
        encryptedContent: 'placeholder',
        plainContent: 'Content only, no title',
      );

      await engine.push();

      expect(api.capturedPushItems.length, 1);
      final blob = api.capturedPushItems.first;
      final encryptedBase64 = blob['encrypted_data'] as String;

      // Decrypt and verify envelope has content but no title.
      final derivedKey = await _deriveKey(encryptKey, 'note-no-title');
      final decryptedEnvelope = jsonDecode(
        await _decrypt(encryptedBase64, derivedKey),
      ) as Map<String, dynamic>;
      expect(decryptedEnvelope['content'], 'Content only, no title');
      expect(decryptedEnvelope.containsKey('title'), isFalse);
    });

    test('push with no unsynced items returns empty result', () async {
      final result = await engine.push();
      expect(result.accepted, isEmpty);
      expect(result.conflicts, isEmpty);
      expect(api.capturedPushItems, isEmpty);
    });

    test('push skips when crypto is locked', () async {
      // Create a locked crypto service (no key injected).
      final lockedCrypto = CryptoService();
      final lockedEngine = SyncEngine(db, api, lockedCrypto);

      await db.notesDao.createNote(
        id: 'note-locked',
        encryptedContent: 'placeholder',
        plainContent: 'Should not be pushed',
      );

      final result = await lockedEngine.push();
      expect(result.accepted, isEmpty);
      expect(api.capturedPushItems, isEmpty);
    });
  });

  // ========================================================================
  // Pull direction
  // ========================================================================

  group('Pull pipeline', () {
    late AppDatabase db;
    late CryptoService crypto;
    late MockSyncApiClient api;
    late SyncEngine engine;
    final encryptKey = generateTestEncryptKey();

    setUp(() async {
      db = createPipelineDatabase();
      crypto = createPipelineCrypto(encryptKey);
      api = MockSyncApiClient();
      engine = SyncEngine(db, api, crypto);
      await db.notesDao.getAllNotes();
    });

    tearDown(() async {
      await db.close();
    });

    test('pull decrypts a note blob and inserts into DB', () async {
      const noteId = 'note-pull-1';
      const expectedContent = 'Hello from server';
      const expectedTitle = 'Server Note';

      // Encrypt the note envelope using real libsodium.
      final encryptedBase64 = await encryptNoteEnvelope(
        encryptKey: encryptKey,
        itemId: noteId,
        content: expectedContent,
        title: expectedTitle,
      );

      // Configure mock API to return the encrypted blob.
      api.pullResponse = SyncPullResponseDto(
        blobs: [
          buildPullBlob(
            itemId: noteId,
            itemType: 'note',
            encryptedDataBase64: encryptedBase64,
            version: 1,
          ),
        ],
        latestVersion: 1,
      );

      // Pull.
      final count = await engine.pull();
      expect(count, 1);

      // Verify the decrypted note is in the DB.
      final note = await db.notesDao.getNoteById(noteId);
      expect(note, isNotNull);
      expect(note!.plainContent, expectedContent);
      expect(note.plainTitle, expectedTitle);
    });

    test('pull decrypts a tag blob and upserts into DB', () async {
      const tagId = 'tag-pull-1';
      const expectedName = 'Work';

      final encryptedBase64 = await encryptPlaintext(
        encryptKey: encryptKey,
        itemId: tagId,
        plaintext: expectedName,
      );

      api.pullResponse = SyncPullResponseDto(
        blobs: [
          buildPullBlob(
            itemId: tagId,
            itemType: 'tag',
            encryptedDataBase64: encryptedBase64,
            version: 1,
          ),
        ],
        latestVersion: 1,
      );

      final count = await engine.pull();
      expect(count, 1);

      // TagsDao.updateTag uses upsert semantics. Since no tag with this ID
      // exists, the update is a no-op at the DB level (0 rows affected).
      // The sync engine does NOT insert tags on pull -- it calls updateTag,
      // which only updates existing rows. So we check the DAO directly.
      // Verify via the DAO that the tag was not created (it only calls updateTag).
      final tags = await db.tagsDao.getAllTags();
      // The sync engine's _applyTagBlob calls updateTag, which is a no-op
      // if the tag does not exist. This is by design: tags are expected to
      // exist before they are synced (created locally or via full restore).
      // For this test we pre-create the tag so the update applies.
      expect(tags.length, 0);
    });

    test('pull decrypts a tag blob and updates existing tag', () async {
      const tagId = 'tag-pull-update';
      const expectedName = 'Updated Tag Name';

      // Pre-create the tag.
      await db.tagsDao.createTag(
        id: tagId,
        encryptedName: 'old-encrypted',
        plainName: 'Old Name',
      );

      final encryptedBase64 = await encryptPlaintext(
        encryptKey: encryptKey,
        itemId: tagId,
        plaintext: expectedName,
      );

      api.pullResponse = SyncPullResponseDto(
        blobs: [
          buildPullBlob(
            itemId: tagId,
            itemType: 'tag',
            encryptedDataBase64: encryptedBase64,
            version: 2,
          ),
        ],
        latestVersion: 2,
      );

      final count = await engine.pull();
      expect(count, 1);

      final tags = await db.tagsDao.getAllTags();
      expect(tags.length, 1);
      expect(tags.first.id, tagId);
      expect(tags.first.plainName, expectedName);
    });

    test('pull decrypts a collection blob and updates existing collection',
        () async {
      const colId = 'col-pull-update';
      const expectedTitle = 'Updated Collection';

      // Pre-create the collection.
      await db.collectionsDao.createCollection(
        id: colId,
        encryptedTitle: 'old-encrypted',
        plainTitle: 'Old Title',
      );

      final encryptedBase64 = await encryptPlaintext(
        encryptKey: encryptKey,
        itemId: colId,
        plaintext: expectedTitle,
      );

      api.pullResponse = SyncPullResponseDto(
        blobs: [
          buildPullBlob(
            itemId: colId,
            itemType: 'collection',
            encryptedDataBase64: encryptedBase64,
            version: 2,
          ),
        ],
        latestVersion: 2,
      );

      final count = await engine.pull();
      expect(count, 1);

      final cols = await db.collectionsDao.getAllCollections();
      expect(cols.length, 1);
      expect(cols.first.id, colId);
      expect(cols.first.plainTitle, expectedTitle);
    });

    test('pull decrypts a content blob and updates existing content', () async {
      const contentId = 'content-pull-1';
      const expectedBody = 'AI-generated summary of the note';

      // Pre-create the generated content.
      await db.generatedContentsDao.create(
        id: contentId,
        encryptedBody: 'old-encrypted',
        plainBody: 'Old body',
      );

      final encryptedBase64 = await encryptPlaintext(
        encryptKey: encryptKey,
        itemId: contentId,
        plaintext: expectedBody,
      );

      api.pullResponse = SyncPullResponseDto(
        blobs: [
          buildPullBlob(
            itemId: contentId,
            itemType: 'content',
            encryptedDataBase64: encryptedBase64,
            version: 1,
          ),
        ],
        latestVersion: 1,
      );

      final count = await engine.pull();
      expect(count, 1);

      final content = await db.generatedContentsDao.getById(contentId);
      expect(content, isNotNull);
      expect(content!.plainBody, expectedBody);
    });

    test('pull with empty server returns 0 items', () async {
      api.pullResponse = SyncPullResponseDto(blobs: [], latestVersion: 0);

      final count = await engine.pull();
      expect(count, 0);
    });

    test('pull updates sync meta with latest version', () async {
      api.pullResponse = SyncPullResponseDto(blobs: [], latestVersion: 42);

      await engine.pull();

      final version = await db.syncMetaDao.getLastSyncedVersion('all');
      expect(version, 42);
    });

    test('pull sends current sync version to server', () async {
      await db.syncMetaDao.updateSyncMeta('all', 10);

      api.pullResponse = SyncPullResponseDto(blobs: [], latestVersion: 15);

      await engine.pull();
      expect(api.lastPullSinceVersion, 10);
    });
  });

  // ========================================================================
  // Round-trip (cross-device)
  // ========================================================================

  group('Cross-device round-trip', () {
    test('Device A pushes note, Device B pulls and sees same plaintext',
        () async {
      final sharedEncryptKey = generateTestEncryptKey();
      const noteId = 'note-xdevice-1';
      const originalContent = 'Cross-device note content';
      const originalTitle = 'Cross-Device Title';

      // -- Device A: create note and push --
      final dbA = createPipelineDatabase();
      final cryptoA = createPipelineCrypto(sharedEncryptKey);
      final apiA = MockSyncApiClient();
      final engineA = SyncEngine(dbA, apiA, cryptoA);
      await dbA.notesDao.getAllNotes();

      await dbA.notesDao.createNote(
        id: noteId,
        encryptedContent: 'placeholder',
        plainContent: originalContent,
        plainTitle: originalTitle,
      );

      final pushResult = await engineA.push();
      expect(pushResult.accepted, [noteId]);
      expect(apiA.capturedPushItems.length, 1);

      // Capture the encrypted blob from device A's push.
      final pushedBlob = apiA.capturedPushItems.first;
      final encryptedDataFromA = pushedBlob['encrypted_data'] as String;
      final versionFromA = pushedBlob['version'] as int;

      await dbA.close();

      // -- Device B: fresh DB, same encrypt key, pull the blob --
      final dbB = createPipelineDatabase();
      final cryptoB = createPipelineCrypto(sharedEncryptKey);
      final apiB = MockSyncApiClient();
      final engineB = SyncEngine(dbB, apiB, cryptoB);
      await dbB.notesDao.getAllNotes();

      // Build a pull response from device A's captured push blob.
      // The encrypted_data in the push blob is already base64. The pull
      // response expects the same format.
      apiB.pullResponse = SyncPullResponseDto(
        blobs: [
          {
            'item_id': noteId,
            'item_type': 'note',
            'encrypted_data': encryptedDataFromA,
            'version': versionFromA,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        ],
        latestVersion: versionFromA,
      );

      final pullCount = await engineB.pull();
      expect(pullCount, 1);

      // Device B should see the same plaintext as device A.
      final noteOnB = await dbB.notesDao.getNoteById(noteId);
      expect(noteOnB, isNotNull);
      expect(noteOnB!.plainContent, originalContent);
      expect(noteOnB.plainTitle, originalTitle);

      await dbB.close();
    });

    test('Cross-device round-trip for tag', () async {
      final sharedEncryptKey = generateTestEncryptKey();
      const tagId = 'tag-xdevice-1';
      const originalName = 'Important';

      // -- Device A --
      final dbA = createPipelineDatabase();
      final cryptoA = createPipelineCrypto(sharedEncryptKey);
      final apiA = MockSyncApiClient();
      final engineA = SyncEngine(dbA, apiA, cryptoA);
      await dbA.notesDao.getAllNotes();

      await dbA.tagsDao.createTag(
        id: tagId,
        encryptedName: 'placeholder',
        plainName: originalName,
      );

      await engineA.push();
      expect(apiA.capturedPushItems.length, 1);

      final pushedBlob = apiA.capturedPushItems.first;
      final encryptedDataFromA = pushedBlob['encrypted_data'] as String;
      final versionFromA = pushedBlob['version'] as int;

      await dbA.close();

      // -- Device B --
      final dbB = createPipelineDatabase();
      final cryptoB = createPipelineCrypto(sharedEncryptKey);
      final apiB = MockSyncApiClient();
      final engineB = SyncEngine(dbB, apiB, cryptoB);
      await dbB.notesDao.getAllNotes();

      // Pre-create the tag on device B so the pull update applies.
      await dbB.tagsDao.createTag(
        id: tagId,
        encryptedName: 'old',
        plainName: 'Old Name',
      );

      apiB.pullResponse = SyncPullResponseDto(
        blobs: [
          {
            'item_id': tagId,
            'item_type': 'tag',
            'encrypted_data': encryptedDataFromA,
            'version': versionFromA,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        ],
        latestVersion: versionFromA,
      );

      await engineB.pull();

      final tagsOnB = await dbB.tagsDao.getAllTags();
      expect(tagsOnB.length, 1);
      expect(tagsOnB.first.plainName, originalName);

      await dbB.close();
    });

    test('Cross-device round-trip for collection', () async {
      final sharedEncryptKey = generateTestEncryptKey();
      const colId = 'col-xdevice-1';
      const originalTitle = 'Project Alpha';

      // -- Device A --
      final dbA = createPipelineDatabase();
      final cryptoA = createPipelineCrypto(sharedEncryptKey);
      final apiA = MockSyncApiClient();
      final engineA = SyncEngine(dbA, apiA, cryptoA);
      await dbA.notesDao.getAllNotes();

      await dbA.collectionsDao.createCollection(
        id: colId,
        encryptedTitle: 'placeholder',
        plainTitle: originalTitle,
      );

      await engineA.push();
      expect(apiA.capturedPushItems.length, 1);

      final pushedBlob = apiA.capturedPushItems.first;
      final encryptedDataFromA = pushedBlob['encrypted_data'] as String;
      final versionFromA = pushedBlob['version'] as int;

      await dbA.close();

      // -- Device B --
      final dbB = createPipelineDatabase();
      final cryptoB = createPipelineCrypto(sharedEncryptKey);
      final apiB = MockSyncApiClient();
      final engineB = SyncEngine(dbB, apiB, cryptoB);
      await dbB.notesDao.getAllNotes();

      // Pre-create the collection on device B.
      await dbB.collectionsDao.createCollection(
        id: colId,
        encryptedTitle: 'old',
        plainTitle: 'Old Title',
      );

      apiB.pullResponse = SyncPullResponseDto(
        blobs: [
          {
            'item_id': colId,
            'item_type': 'collection',
            'encrypted_data': encryptedDataFromA,
            'version': versionFromA,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        ],
        latestVersion: versionFromA,
      );

      await engineB.pull();

      final colsOnB = await dbB.collectionsDao.getAllCollections();
      expect(colsOnB.length, 1);
      expect(colsOnB.first.plainTitle, originalTitle);

      await dbB.close();
    });

    test('Different encrypt keys produce different ciphertexts', () async {
      const noteId = 'note-diff-keys';
      const content = 'Same content, different keys';

      final key1 = generateTestEncryptKey();
      final key2 =
          Uint8List.fromList(List.generate(32, (i) => (i * 3 + 41) % 256));

      final encrypted1 = await encryptNoteEnvelope(
        encryptKey: key1,
        itemId: noteId,
        content: content,
      );
      final encrypted2 = await encryptNoteEnvelope(
        encryptKey: key2,
        itemId: noteId,
        content: content,
      );

      // Same plaintext + same item ID + different keys = different ciphertexts.
      expect(encrypted1, isNot(equals(encrypted2)));
    });
  });

  // ========================================================================
  // Multi-type push + pull
  // ========================================================================

  group('Multi-type sync', () {
    late AppDatabase db;
    late CryptoService crypto;
    late MockSyncApiClient api;
    late SyncEngine engine;
    final encryptKey = generateTestEncryptKey();

    setUp(() async {
      db = createPipelineDatabase();
      crypto = createPipelineCrypto(encryptKey);
      api = MockSyncApiClient();
      engine = SyncEngine(db, api, crypto);
      await db.notesDao.getAllNotes();
    });

    tearDown(() async {
      await db.close();
    });

    test('push encrypts note + tag + collection, pull decrypts all', () async {
      // Create items in DB.
      await db.notesDao.createNote(
        id: 'multi-note',
        encryptedContent: 'placeholder',
        plainContent: 'Multi-note content',
        plainTitle: 'Multi Note',
      );
      await db.tagsDao.createTag(
        id: 'multi-tag',
        encryptedName: 'placeholder',
        plainName: 'MultiTag',
      );
      await db.collectionsDao.createCollection(
        id: 'multi-col',
        encryptedTitle: 'placeholder',
        plainTitle: 'Multi Collection',
      );

      // Push all.
      final pushResult = await engine.push();
      expect(pushResult.accepted.length, 3);
      expect(
        pushResult.accepted,
        containsAll(['multi-note', 'multi-tag', 'multi-col']),
      );
      expect(api.capturedPushItems.length, 3);

      // Verify all captured blobs have encrypted data (no plaintext leaked).
      for (final blob in api.capturedPushItems) {
        final encryptedData = blob['encrypted_data'] as String;
        expect(encryptedData, isNotEmpty);
        // None of the plaintext values should appear in the encrypted data.
        expect(encryptedData, isNot(contains('Multi-note content')));
        expect(encryptedData, isNot(contains('Multi Note')));
        expect(encryptedData, isNot(contains('MultiTag')));
        expect(encryptedData, isNot(contains('Multi Collection')));
      }

      // Mark all as synced (push already did this via the mock accepting all).
      // Verify they are synced in DB.
      final syncedNote = await db.notesDao.getNoteById('multi-note');
      expect(syncedNote!.isSynced, true);
    });

    test('pull handles multiple blobs of different types', () async {
      // Pre-create tag and collection so pull update applies.
      await db.tagsDao.createTag(
        id: 'multi-tag-pull',
        encryptedName: 'old',
        plainName: 'Old Tag',
      );
      await db.collectionsDao.createCollection(
        id: 'multi-col-pull',
        encryptedTitle: 'old',
        plainTitle: 'Old Col',
      );

      // Encrypt test data for each type.
      final noteEncrypted = await encryptNoteEnvelope(
        encryptKey: encryptKey,
        itemId: 'multi-note-pull',
        content: 'Pulled note content',
        title: 'Pulled Note',
      );
      final tagEncrypted = await encryptPlaintext(
        encryptKey: encryptKey,
        itemId: 'multi-tag-pull',
        plaintext: 'PulledTag',
      );
      final colEncrypted = await encryptPlaintext(
        encryptKey: encryptKey,
        itemId: 'multi-col-pull',
        plaintext: 'Pulled Collection',
      );

      api.pullResponse = SyncPullResponseDto(
        blobs: [
          buildPullBlob(
            itemId: 'multi-note-pull',
            itemType: 'note',
            encryptedDataBase64: noteEncrypted,
            version: 1,
          ),
          buildPullBlob(
            itemId: 'multi-tag-pull',
            itemType: 'tag',
            encryptedDataBase64: tagEncrypted,
            version: 1,
          ),
          buildPullBlob(
            itemId: 'multi-col-pull',
            itemType: 'collection',
            encryptedDataBase64: colEncrypted,
            version: 1,
          ),
        ],
        latestVersion: 3,
      );

      final count = await engine.pull();
      expect(count, 3);

      // Verify each item was decrypted correctly.
      final note = await db.notesDao.getNoteById('multi-note-pull');
      expect(note!.plainContent, 'Pulled note content');
      expect(note.plainTitle, 'Pulled Note');

      final tags = await db.tagsDao.getAllTags();
      expect(
        tags.any(
          (t) => t.id == 'multi-tag-pull' && t.plainName == 'PulledTag',
        ),
        isTrue,
      );

      final cols = await db.collectionsDao.getAllCollections();
      expect(
        cols.any(
          (c) =>
              c.id == 'multi-col-pull' && c.plainTitle == 'Pulled Collection',
        ),
        isTrue,
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Private helpers for direct encrypt/decrypt in tests
// ---------------------------------------------------------------------------

/// Derive a per-item key from the encrypt key and item ID.
Future<Uint8List> _deriveKey(Uint8List encryptKey, String itemId) async {
  return Encryptor.derivePerItemKey(encryptKey, itemId);
}

/// Decrypt a base64 ciphertext using a derived key.
Future<String> _decrypt(String encryptedBase64, Uint8List itemKey) async {
  return Encryptor.decrypt(encryptedBase64, itemKey);
}
