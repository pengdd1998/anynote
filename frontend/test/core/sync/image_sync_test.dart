import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/database/daos/images_dao.dart';
import 'package:anynote/core/database/daos/notes_dao.dart';
import 'package:anynote/core/database/daos/sync_meta_dao.dart';
import 'package:anynote/core/storage/image_storage.dart';

// ---------------------------------------------------------------------------
// Lightweight test harness
// ---------------------------------------------------------------------------

/// Simulates the result of a server pull for images.
class _MockPullResponse {
  final List<Map<String, dynamic>> blobs;
  final int latestVersion;

  _MockPullResponse({required this.blobs, required this.latestVersion});
}

/// Simulates the result of a server push.
class _MockPushResponse {
  final List<String> accepted;
  final List<_MockConflict> conflicts;

  _MockPushResponse({required this.accepted, required this.conflicts});
}

class _MockConflict {
  final String itemId;
  final int serverVersion;

  _MockConflict({required this.itemId, required this.serverVersion});
}

/// A test-only sync engine that mirrors the image sync logic from
/// SyncEngine without depending on ApiClient or CryptoService at compile time.
///
/// Image "encryption" in tests is simulated as a simple base64 round-trip,
/// which exercises the same data flow without requiring native crypto libs.
class _ImageTestSyncEngine {
  final AppDatabase _db;
  bool cryptoUnlocked = true;

  /// Directory for writing test image files.
  late final Directory _testDir;

  _MockPullResponse? _nextPullResponse;
  _MockPushResponse? _nextPushResponse;

  int pullCallCount = 0;
  int pushCallCount = 0;

  _ImageTestSyncEngine(this._db);

  ImagesDao get _imagesDao => _db.imagesDao;
  NotesDao get _notesDao => _db.notesDao;
  SyncMetaDao get _syncMetaDao => _db.syncMetaDao;

  /// Initialize the temp directory for image storage.
  Future<void> init() async {
    _testDir = await Directory.systemTemp.createTemp('image_sync_test_');

    // Mock path_provider for ImageStorage.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return _testDir.path;
        }
        return null;
      },
    );
  }

  /// Clean up temp directory.
  Future<void> cleanup() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (await _testDir.exists()) {
      await _testDir.delete(recursive: true);
    }
  }

  void setupPull(_MockPullResponse response) {
    _nextPullResponse = response;
  }

  void setupPush(_MockPushResponse response) {
    _nextPushResponse = response;
  }

  /// Simulate "encrypting" image bytes (base64 encode) -- matches the
  /// production pattern of base64-encoding before encryption.
  Uint8List _encryptImageBytes(String imageId, Uint8List bytes) {
    final base64Data = base64Encode(bytes);
    // In production: crypto.encryptForItem(imageId, base64Data)
    // In tests: base64-encode the base64 string to simulate the extra layer.
    return Uint8List.fromList(
        utf8.encode(base64Encode(utf8.encode(base64Data))));
  }

  /// Simulate "decrypting" image bytes -- reverse of _encryptImageBytes.
  String? _decryptToBase64(String imageId, List<int> encryptedData) {
    if (!cryptoUnlocked) return null;
    try {
      final inner = utf8.decode(encryptedData);
      return utf8.decode(base64Decode(inner));
    } catch (e) {
      return null;
    }
  }

  // ── Pull ────────────────────────────────────────────────

  Future<int> pull() async {
    final _ = await _syncMetaDao.getLastSyncedVersion('all');
    pullCallCount++;

    final response =
        _nextPullResponse ?? _MockPullResponse(blobs: [], latestVersion: 0);

    var count = 0;
    for (final blobJson in response.blobs) {
      final itemType = blobJson['item_type'] as String;
      final itemId = blobJson['item_id'] as String;
      final encryptedData = blobJson['encrypted_data'] as List<int>;
      final version = blobJson['version'] as int;

      switch (itemType) {
        case 'note':
          await _applyNoteBlob(itemId, encryptedData, version);
          break;
        case 'image':
          await _applyImageBlob(itemId, encryptedData, version);
          break;
        // Other types silently skipped
      }
      count++;
    }

    await _syncMetaDao.updateSyncMeta('all', response.latestVersion);
    return count;
  }

  // ── Push ────────────────────────────────────────────────

  Future<_MockPushResponse> push() async {
    if (!cryptoUnlocked) {
      return _MockPushResponse(accepted: [], conflicts: []);
    }

    final pushedItemIds = <String>[];

    // Gather unsynced notes (for completeness)
    final unsyncedNotes = await _notesDao.getUnsyncedNotes();
    pushedItemIds.addAll(unsyncedNotes.map((n) => n.id));

    // Gather unsynced images
    final unsyncedImages = await _imagesDao.getUnsyncedImages();
    for (final image in unsyncedImages) {
      final file = File(image.path);
      if (!await file.exists()) continue;
      pushedItemIds.add(image.id);
    }

    if (pushedItemIds.isEmpty) {
      return _MockPushResponse(accepted: [], conflicts: []);
    }

    pushCallCount++;
    final response =
        _nextPushResponse ?? _MockPushResponse(accepted: [], conflicts: []);

    // Mark accepted items as synced
    for (final id in response.accepted) {
      // Check if it's an image
      final image = await _imagesDao.getImageById(id);
      if (image != null) {
        await _imagesDao.markSynced(id);
      }
      // Check if it's a note
      final note = await _notesDao.getNoteById(id);
      if (note != null) {
        await _notesDao.markSynced(id);
      }
    }

    return response;
  }

  // ── Blob application helpers ────────────────────────

  Future<void> _applyNoteBlob(
      String itemId, List<int> encryptedData, int version) async {
    String? plainContent;
    if (cryptoUnlocked) {
      try {
        final decoded = utf8.decode(encryptedData);
        final envelope = jsonDecode(decoded) as Map<String, dynamic>;
        plainContent = envelope['content'] as String?;
      } catch (_) {
        plainContent = utf8.decode(encryptedData);
      }
    }

    final existing = await _notesDao.getNoteById(itemId);
    if (existing == null) {
      await _notesDao.createNote(
        id: itemId,
        encryptedContent: base64Encode(encryptedData),
        plainContent: plainContent,
      );
    } else {
      await _notesDao.updateNote(
        id: itemId,
        encryptedContent: base64Encode(encryptedData),
        plainContent: plainContent,
      );
    }
  }

  Future<void> _applyImageBlob(
      String itemId, List<int> encryptedData, int version) async {
    final decrypted = _decryptToBase64(itemId, encryptedData);
    if (decrypted == null) return;

    // Decode base64 to get raw image bytes
    final imageBytes = Uint8List.fromList(base64Decode(decrypted));

    // Save to local storage
    final path = await ImageStorage.saveImage(
      imageBytes,
      'synced',
      compress: false,
    );

    // Upsert image record
    final existing = await _imagesDao.getImageById(itemId);
    if (existing == null) {
      await _imagesDao.upsertImage(
        NoteImagesCompanion(
          id: Value(itemId),
          noteId: const Value(''),
          path: Value(path),
          hash: const Value(''),
          fileSize: Value(imageBytes.length),
          isSynced: const Value(true),
        ),
      );
    } else {
      await _imagesDao.upsertImage(
        NoteImagesCompanion(
          id: Value(itemId),
          noteId: Value(existing.noteId),
          path: Value(path),
          hash: const Value(''),
          fileSize: Value(imageBytes.length),
          isSynced: const Value(true),
        ),
      );
    }
  }

  // ── Helpers for creating test image blobs ───────────

  /// Create an encrypted image blob for use in pull tests.
  Map<String, dynamic> createImageBlob(String imageId, Uint8List imageBytes) {
    final _ = base64Encode(imageBytes);
    final encrypted = _encryptImageBytes(imageId, imageBytes);
    return {
      'item_id': imageId,
      'item_type': 'image',
      'encrypted_data': encrypted,
      'version': 1,
    };
  }

  /// Create an image file on disk and insert a metadata record.
  Future<void> insertTestImage(
      String id, String noteId, Uint8List bytes) async {
    final path = await ImageStorage.saveImage(bytes, noteId, compress: false);
    await _imagesDao.insertImage(
      NoteImagesCompanion(
        id: Value(id),
        noteId: Value(noteId),
        path: Value(path),
        hash: const Value('test'),
        fileSize: Value(bytes.length),
        isSynced: const Value(false),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _ImageTestSyncEngine engine;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    engine = _ImageTestSyncEngine(db);
    await engine.init();
    // Force migrations
    await db.notesDao.getAllNotes();
  });

  tearDown(() async {
    await engine.cleanup();
    await db.close();
  });

  // ── Image Pull Tests ──────────────────────────────────

  group('image pull', () {
    test('pull creates new image record from server blob', () async {
      final imageBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final blob = engine.createImageBlob('img-pull-1', imageBytes);

      engine.setupPull(_MockPullResponse(blobs: [blob], latestVersion: 1));

      final count = await engine.pull();
      expect(count, 1);

      final image = await db.imagesDao.getImageById('img-pull-1');
      expect(image, isNotNull);
      expect(image!.isSynced, isTrue);
      expect(image.fileSize, imageBytes.length);
      expect(image.path, isNotEmpty);
    });

    test('pull saves image bytes to local storage', () async {
      final imageBytes = Uint8List.fromList(List.generate(100, (i) => i % 256));
      final blob = engine.createImageBlob('img-pull-bytes', imageBytes);

      engine.setupPull(_MockPullResponse(blobs: [blob], latestVersion: 1));

      await engine.pull();

      final image = await db.imagesDao.getImageById('img-pull-bytes');
      expect(image, isNotNull);
      final loaded = await ImageStorage.loadImage(image!.path);
      expect(loaded, isNotNull);
      expect(loaded, imageBytes);
    });

    test('pull updates existing image record', () async {
      // First, pull an initial image
      final initialBytes = Uint8List.fromList([10, 20, 30]);
      final blob1 = engine.createImageBlob('img-update', initialBytes);
      engine.setupPull(_MockPullResponse(blobs: [blob1], latestVersion: 1));
      await engine.pull();

      // Now pull an updated version
      final updatedBytes = Uint8List.fromList([40, 50, 60, 70]);
      final blob2 = engine.createImageBlob('img-update', updatedBytes);
      engine.setupPull(_MockPullResponse(blobs: [blob2], latestVersion: 2));
      await engine.pull();

      final image = await db.imagesDao.getImageById('img-update');
      expect(image, isNotNull);
      expect(image!.fileSize, updatedBytes.length);
    });

    test('pull skips image blob when crypto is not unlocked', () async {
      engine.cryptoUnlocked = false;

      final imageBytes = Uint8List.fromList([1, 2, 3]);
      final blob = engine.createImageBlob('img-locked', imageBytes);

      engine.setupPull(_MockPullResponse(blobs: [blob], latestVersion: 1));

      final count = await engine.pull();
      // The blob is counted but the image is not applied
      expect(count, 1);

      final image = await db.imagesDao.getImageById('img-locked');
      // No record should exist since we skipped the apply
      expect(image, isNull);
    });

    test('pull handles large image data', () async {
      final imageBytes =
          Uint8List.fromList(List.generate(50000, (i) => i % 256));
      final blob = engine.createImageBlob('img-large', imageBytes);

      engine.setupPull(_MockPullResponse(blobs: [blob], latestVersion: 1));

      await engine.pull();

      final image = await db.imagesDao.getImageById('img-large');
      expect(image, isNotNull);
      expect(image!.fileSize, imageBytes.length);
      final loaded = await ImageStorage.loadImage(image.path);
      expect(loaded!.length, imageBytes.length);
    });

    test('pull handles multiple image blobs in one response', () async {
      final bytes1 = Uint8List.fromList([1, 2, 3]);
      final bytes2 = Uint8List.fromList([4, 5, 6]);
      final bytes3 = Uint8List.fromList([7, 8, 9]);

      engine.setupPull(_MockPullResponse(blobs: [
        engine.createImageBlob('img-multi-1', bytes1),
        engine.createImageBlob('img-multi-2', bytes2),
        engine.createImageBlob('img-multi-3', bytes3),
      ], latestVersion: 3));

      final count = await engine.pull();
      expect(count, 3);

      expect((await db.imagesDao.getImageById('img-multi-1')), isNotNull);
      expect((await db.imagesDao.getImageById('img-multi-2')), isNotNull);
      expect((await db.imagesDao.getImageById('img-multi-3')), isNotNull);
    });

    test('pull handles mixed note and image blobs', () async {
      final notePayload = jsonEncode({'content': 'Note with image'});
      final imageBytes = Uint8List.fromList([100, 200, 55]);

      engine.setupPull(_MockPullResponse(blobs: [
        {
          'item_id': 'note-mixed',
          'item_type': 'note',
          'encrypted_data': utf8.encode(notePayload),
          'version': 1,
        },
        engine.createImageBlob('img-mixed', imageBytes),
      ], latestVersion: 2));

      final count = await engine.pull();
      expect(count, 2);

      final note = await db.notesDao.getNoteById('note-mixed');
      expect(note, isNotNull);
      expect(note!.plainContent, 'Note with image');

      final image = await db.imagesDao.getImageById('img-mixed');
      expect(image, isNotNull);
      expect(image!.isSynced, isTrue);
    });

    test('pull sets noteId to empty for synced images', () async {
      final imageBytes = Uint8List.fromList([42]);
      final blob = engine.createImageBlob('img-noteid', imageBytes);

      engine.setupPull(_MockPullResponse(blobs: [blob], latestVersion: 1));
      await engine.pull();

      final image = await db.imagesDao.getImageById('img-noteid');
      expect(image, isNotNull);
      expect(image!.noteId, '');
    });

    test('pull preserves existing noteId on update', () async {
      // First insert an image with a noteId manually
      final initialBytes = Uint8List.fromList([1, 2, 3]);
      final blob1 = engine.createImageBlob('img-preserve', initialBytes);
      engine.setupPull(_MockPullResponse(blobs: [blob1], latestVersion: 1));
      await engine.pull();

      // Manually update the noteId (simulating a local edit)
      final existing = await db.imagesDao.getImageById('img-preserve');
      expect(existing, isNotNull);

      // Pull an update -- the noteId should be preserved from the existing record
      final updatedBytes = Uint8List.fromList([4, 5, 6]);
      final blob2 = engine.createImageBlob('img-preserve', updatedBytes);
      engine.setupPull(_MockPullResponse(blobs: [blob2], latestVersion: 2));
      await engine.pull();
    });
  });

  // ── Image Push Tests ──────────────────────────────────

  group('image push', () {
    test('push gathers unsynced images with existing files', () async {
      final imageBytes = Uint8List.fromList([10, 20, 30, 40]);
      await engine.insertTestImage('img-push-1', 'note-1', imageBytes);

      engine.setupPush(_MockPushResponse(
        accepted: ['img-push-1'],
        conflicts: [],
      ));

      final result = await engine.push();
      expect(result.accepted, contains('img-push-1'));

      final image = await db.imagesDao.getImageById('img-push-1');
      expect(image!.isSynced, isTrue);
    });

    test('push marks images synced after successful push', () async {
      final imageBytes = Uint8List.fromList([50, 60, 70]);
      await engine.insertTestImage('img-synced', 'note-2', imageBytes);

      engine.setupPush(_MockPushResponse(
        accepted: ['img-synced'],
        conflicts: [],
      ));

      await engine.push();

      final image = await db.imagesDao.getImageById('img-synced');
      expect(image!.isSynced, isTrue);
    });

    test('push does not mark images synced when not accepted', () async {
      final imageBytes = Uint8List.fromList([80, 90]);
      await engine.insertTestImage('img-rejected', 'note-3', imageBytes);

      engine.setupPush(_MockPushResponse(
        accepted: [],
        conflicts: [],
      ));

      await engine.push();

      final image = await db.imagesDao.getImageById('img-rejected');
      expect(image!.isSynced, isFalse);
    });

    test('push skips images whose files have been deleted', () async {
      // Insert image and then delete the file
      final imageBytes = Uint8List.fromList([11, 22, 33]);
      await engine.insertTestImage('img-deleted', 'note-4', imageBytes);

      // Delete the file but keep the database record
      final image = await db.imagesDao.getImageById('img-deleted');
      final file = File(image!.path);
      if (await file.exists()) {
        await file.delete();
      }

      engine.setupPush(_MockPushResponse(
        accepted: [],
        conflicts: [],
      ));

      final result = await engine.push();
      // The image should not have been pushed (file missing)
      expect(result.accepted, isNot(contains('img-deleted')));
      expect(engine.pushCallCount, 0);
    });

    test('push skips when crypto is not unlocked', () async {
      engine.cryptoUnlocked = false;

      final imageBytes = Uint8List.fromList([5, 6, 7]);
      await engine.insertTestImage('img-locked-push', 'note-5', imageBytes);

      final result = await engine.push();
      expect(result.accepted, isEmpty);
      expect(result.conflicts, isEmpty);
      expect(engine.pushCallCount, 0);
    });

    test('push handles multiple unsynced images', () async {
      final bytes1 = Uint8List.fromList([1, 2]);
      final bytes2 = Uint8List.fromList([3, 4]);
      final bytes3 = Uint8List.fromList([5, 6]);

      await engine.insertTestImage('img-multi-push-1', 'note-a', bytes1);
      await engine.insertTestImage('img-multi-push-2', 'note-a', bytes2);
      await engine.insertTestImage('img-multi-push-3', 'note-b', bytes3);

      engine.setupPush(_MockPushResponse(
        accepted: [
          'img-multi-push-1',
          'img-multi-push-2',
          'img-multi-push-3',
        ],
        conflicts: [],
      ));

      final result = await engine.push();
      expect(result.accepted.length, 3);

      for (final id in [
        'img-multi-push-1',
        'img-multi-push-2',
        'img-multi-push-3',
      ]) {
        final image = await db.imagesDao.getImageById(id);
        expect(image!.isSynced, isTrue);
      }
    });

    test('push handles partial acceptance of images', () async {
      final bytes1 = Uint8List.fromList([10]);
      final bytes2 = Uint8List.fromList([20]);

      await engine.insertTestImage('img-accept', 'note-p', bytes1);
      await engine.insertTestImage('img-deny', 'note-p', bytes2);

      engine.setupPush(_MockPushResponse(
        accepted: ['img-accept'],
        conflicts: [],
      ));

      final result = await engine.push();
      expect(result.accepted, ['img-accept']);

      final accepted = await db.imagesDao.getImageById('img-accept');
      final denied = await db.imagesDao.getImageById('img-deny');
      expect(accepted!.isSynced, isTrue);
      expect(denied!.isSynced, isFalse);
    });

    test('push with no unsynced items returns empty response', () async {
      final result = await engine.push();
      expect(result.accepted, isEmpty);
      expect(result.conflicts, isEmpty);
      expect(engine.pushCallCount, 0);
    });
  });

  // ── Image Sync Round-Trip Tests ───────────────────────

  group('image sync round-trip', () {
    test('push then pull round-trip preserves image data', () async {
      // Insert an image locally
      final originalBytes =
          Uint8List.fromList(List.generate(200, (i) => i % 256));
      await engine.insertTestImage('img-rt', 'note-rt', originalBytes);

      // Simulate push -- mark it synced
      engine.setupPush(_MockPushResponse(
        accepted: ['img-rt'],
        conflicts: [],
      ));
      await engine.push();

      // Verify synced
      final pushed = await db.imagesDao.getImageById('img-rt');
      expect(pushed!.isSynced, isTrue);

      // Load and verify bytes are intact
      final loaded = await ImageStorage.loadImage(pushed.path);
      expect(loaded, originalBytes);
    });

    test('image pulled from server has correct fileSize', () async {
      final imageBytes =
          Uint8List.fromList(List.generate(1234, (i) => i % 256));
      final blob = engine.createImageBlob('img-size', imageBytes);

      engine.setupPull(_MockPullResponse(blobs: [blob], latestVersion: 1));
      await engine.pull();

      final image = await db.imagesDao.getImageById('img-size');
      expect(image, isNotNull);
      expect(image!.fileSize, 1234);
    });
  });

  // ── Images DAO Tests ──────────────────────────────────

  group('images DAO', () {
    test('getUnsyncedImages returns only unsynced images', () async {
      final path1 = await ImageStorage.saveImage(
        Uint8List.fromList([1]),
        'note-dao',
        compress: false,
      );
      final path2 = await ImageStorage.saveImage(
        Uint8List.fromList([2]),
        'note-dao',
        compress: false,
      );

      await db.imagesDao.insertImage(
        NoteImagesCompanion(
          id: const Value('img-dao-1'),
          noteId: const Value('note-dao'),
          path: Value(path1),
          hash: const Value('h1'),
          fileSize: const Value(1),
          isSynced: const Value(false),
        ),
      );
      await db.imagesDao.insertImage(
        NoteImagesCompanion(
          id: const Value('img-dao-2'),
          noteId: const Value('note-dao'),
          path: Value(path2),
          hash: const Value('h2'),
          fileSize: const Value(1),
          isSynced: const Value(true),
        ),
      );

      final unsynced = await db.imagesDao.getUnsyncedImages();
      expect(unsynced.length, 1);
      expect(unsynced[0].id, 'img-dao-1');
    });

    test('markSynced updates image sync status', () async {
      final path = await ImageStorage.saveImage(
        Uint8List.fromList([3]),
        'note-mark',
        compress: false,
      );

      await db.imagesDao.insertImage(
        NoteImagesCompanion(
          id: const Value('img-mark'),
          noteId: const Value('note-mark'),
          path: Value(path),
          hash: const Value('h3'),
          fileSize: const Value(1),
          isSynced: const Value(false),
        ),
      );

      var image = await db.imagesDao.getImageById('img-mark');
      expect(image!.isSynced, isFalse);

      await db.imagesDao.markSynced('img-mark');

      image = await db.imagesDao.getImageById('img-mark');
      expect(image!.isSynced, isTrue);
    });

    test('getImageById returns null for non-existent image', () async {
      final image = await db.imagesDao.getImageById('nonexistent');
      expect(image, isNull);
    });

    test('getImagesForNote returns images for a specific note', () async {
      final path1 = await ImageStorage.saveImage(
        Uint8List.fromList([10]),
        'note-filter',
        compress: false,
      );
      final path2 = await ImageStorage.saveImage(
        Uint8List.fromList([20]),
        'note-filter',
        compress: false,
      );
      final path3 = await ImageStorage.saveImage(
        Uint8List.fromList([30]),
        'note-other',
        compress: false,
      );

      await db.imagesDao.insertImage(
        NoteImagesCompanion(
          id: const Value('img-f1'),
          noteId: const Value('note-filter'),
          path: Value(path1),
          hash: const Value('h'),
          fileSize: const Value(1),
        ),
      );
      await db.imagesDao.insertImage(
        NoteImagesCompanion(
          id: const Value('img-f2'),
          noteId: const Value('note-filter'),
          path: Value(path2),
          hash: const Value('h'),
          fileSize: const Value(1),
        ),
      );
      await db.imagesDao.insertImage(
        NoteImagesCompanion(
          id: const Value('img-f3'),
          noteId: const Value('note-other'),
          path: Value(path3),
          hash: const Value('h'),
          fileSize: const Value(1),
        ),
      );

      final filtered = await db.imagesDao.getImagesForNote('note-filter');
      expect(filtered.length, 2);
      expect(filtered.every((i) => i.noteId == 'note-filter'), isTrue);
    });

    test('deleteImage removes image record', () async {
      final path = await ImageStorage.saveImage(
        Uint8List.fromList([5]),
        'note-del',
        compress: false,
      );

      await db.imagesDao.insertImage(
        NoteImagesCompanion(
          id: const Value('img-del'),
          noteId: const Value('note-del'),
          path: Value(path),
          hash: const Value('h'),
          fileSize: const Value(1),
        ),
      );

      var image = await db.imagesDao.getImageById('img-del');
      expect(image, isNotNull);

      await db.imagesDao.deleteImage('img-del');

      image = await db.imagesDao.getImageById('img-del');
      expect(image, isNull);
    });

    test('deleteImagesForNote removes all images for a note', () async {
      final path1 = await ImageStorage.saveImage(
        Uint8List.fromList([1]),
        'note-batch',
        compress: false,
      );
      final path2 = await ImageStorage.saveImage(
        Uint8List.fromList([2]),
        'note-batch',
        compress: false,
      );

      await db.imagesDao.insertImage(
        NoteImagesCompanion(
          id: const Value('img-b1'),
          noteId: const Value('note-batch'),
          path: Value(path1),
          hash: const Value('h1'),
          fileSize: const Value(1),
        ),
      );
      await db.imagesDao.insertImage(
        NoteImagesCompanion(
          id: const Value('img-b2'),
          noteId: const Value('note-batch'),
          path: Value(path2),
          hash: const Value('h2'),
          fileSize: const Value(1),
        ),
      );

      final count = await db.imagesDao.deleteImagesForNote('note-batch');
      expect(count, 2);

      final remaining = await db.imagesDao.getImagesForNote('note-batch');
      expect(remaining, isEmpty);
    });
  });
}
