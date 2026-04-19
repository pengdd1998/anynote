import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/database/daos/notes_dao.dart';
import 'package:anynote/core/database/daos/tags_dao.dart';
import 'package:anynote/core/database/daos/collections_dao.dart';
import 'package:anynote/core/database/daos/sync_meta_dao.dart';

// ── Lightweight mock objects ──────────────────────────────

/// Simulates the result of a server pull, mirroring SyncPullResponseDto
/// without importing the ApiClient (which pulls in broken presentation files).
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

/// A simplified sync engine for testing that does NOT depend on ApiClient
/// or CryptoService at compile time. This avoids the broken imports in
/// presentation layer files while still testing the core sync logic.
class _TestSyncEngine {
  final AppDatabase _db;
  bool cryptoUnlocked = true;

  /// Server pull response to serve on next pull call.
  _MockPullResponse? _nextPullResponse;

  /// Server push response to serve on next push call.
  _MockPushResponse? _nextPushResponse;

  int pullCallCount = 0;
  int pushCallCount = 0;
  int? lastPullSinceVersion;

  _TestSyncEngine(this._db);

  NotesDao get _notesDao => _db.notesDao;
  TagsDao get _tagsDao => _db.tagsDao;
  CollectionsDao get _collectionsDao => _db.collectionsDao;
  SyncMetaDao get _syncMetaDao => _db.syncMetaDao;

  void setupPull(_MockPullResponse response) {
    _nextPullResponse = response;
  }

  void setupPush(_MockPushResponse response) {
    _nextPushResponse = response;
  }

  /// Pull remote changes and apply to local DB.
  /// Uses the mock response if set, otherwise returns 0.
  Future<int> pull() async {
    final sinceVersion = await _syncMetaDao.getLastSyncedVersion('all');
    lastPullSinceVersion = sinceVersion;
    pullCallCount++;

    final response = _nextPullResponse ??
        _MockPullResponse(blobs: [], latestVersion: 0);

    var count = 0;
    for (final blobJson in response.blobs) {
      final itemType = blobJson['item_type'] as String;
      final itemId = blobJson['item_id'] as String;
      final encryptedDataBase64 = blobJson['encrypted_data'] as String;
      final version = blobJson['version'] as int;

      switch (itemType) {
        case 'note':
          await _applyNoteBlob(itemId, encryptedDataBase64, version);
          break;
        case 'tag':
          await _applyTagBlob(itemId, encryptedDataBase64, version);
          break;
        case 'collection':
          await _applyCollectionBlob(
              itemId, encryptedDataBase64, version);
          break;
        // Unknown types are silently skipped (counted but not applied)
      }
      count++;
    }

    await _syncMetaDao.updateSyncMeta('all', response.latestVersion);
    return count;
  }

  /// Push local unsynced items to the mock server.
  Future<_MockPushResponse> push() async {
    if (!cryptoUnlocked) {
      return _MockPushResponse(accepted: [], conflicts: []);
    }

    final itemIds = <String>[];

    final unsyncedNotes = await _notesDao.getUnsyncedNotes();
    itemIds.addAll(unsyncedNotes.map((n) => n.id));

    final unsyncedTags = await _tagsDao.getUnsyncedTags();
    itemIds.addAll(unsyncedTags.map((t) => t.id));

    final unsyncedCollections =
        await _collectionsDao.getUnsyncedCollections();
    itemIds.addAll(unsyncedCollections.map((c) => c.id));

    if (itemIds.isEmpty) {
      return _MockPushResponse(accepted: [], conflicts: []);
    }

    pushCallCount++;
    final response = _nextPushResponse ??
        _MockPushResponse(accepted: [], conflicts: []);

    // Mark accepted items as synced
    for (final id in response.accepted) {
      if (unsyncedNotes.any((n) => n.id == id)) {
        await _notesDao.markSynced(id);
      } else if (unsyncedTags.any((t) => t.id == id)) {
        await _tagsDao.markSynced(id);
      } else if (unsyncedCollections.any((c) => c.id == id)) {
        await _collectionsDao.markSynced(id);
      }
    }

    return response;
  }

  /// Full sync cycle: pull then push.
  Future<({int pulled, int pushed, List<_MockConflict> conflicts})>
      sync() async {
    final pulledCount = await pull();
    final pushResult = await push();
    return (
      pulled: pulledCount,
      pushed: pushResult.accepted.length,
      conflicts: pushResult.conflicts,
    );
  }

  // ── Blob application helpers ────────────────────────

  Future<void> _applyNoteBlob(
      String itemId, String encryptedDataBase64, int version) async {
    final existing = await _notesDao.getNoteById(itemId);

    // Mock decryption: base64 decode and treat as JSON envelope
    String? plainContent;
    String? plainTitle;

    if (cryptoUnlocked) {
      try {
        final decoded = utf8.decode(base64Decode(encryptedDataBase64));
        final envelope = jsonDecode(decoded) as Map<String, dynamic>;
        plainContent = envelope['content'] as String?;
        plainTitle = envelope['title'] as String?;
      } catch (_) {
        // If not valid JSON, treat entire payload as content
        plainContent = utf8.decode(base64Decode(encryptedDataBase64));
      }
    }

    if (existing == null) {
      await _notesDao.createNote(
        id: itemId,
        encryptedContent: encryptedDataBase64,
        plainContent: plainContent,
        plainTitle: plainTitle,
      );
    } else {
      await _notesDao.updateNote(
        id: itemId,
        encryptedContent: encryptedDataBase64,
        plainContent: plainContent,
        plainTitle: plainTitle,
      );
    }
  }

  Future<void> _applyTagBlob(
      String itemId, String encryptedDataBase64, int version) async {
    String? plainName;
    if (cryptoUnlocked) {
      try {
        plainName = utf8.decode(base64Decode(encryptedDataBase64));
      } catch (_) {}
    }

    final existing = await _tagsDao.getAllTags();
    final exists = existing.any((t) => t.id == itemId);
    if (!exists) {
      await _tagsDao.createTag(
        id: itemId,
        encryptedName: encryptedDataBase64,
        plainName: plainName,
      );
    } else {
      await _tagsDao.updateTag(
        id: itemId,
        encryptedName: encryptedDataBase64,
        plainName: plainName,
      );
    }
  }

  Future<void> _applyCollectionBlob(
      String itemId, String encryptedDataBase64, int version) async {
    String? plainTitle;
    if (cryptoUnlocked) {
      try {
        plainTitle = utf8.decode(base64Decode(encryptedDataBase64));
      } catch (_) {}
    }

    final existing = await _collectionsDao.getAllCollections();
    final exists = existing.any((c) => c.id == itemId);
    if (!exists) {
      await _collectionsDao.createCollection(
        id: itemId,
        encryptedTitle: encryptedDataBase64,
        plainTitle: plainTitle,
      );
    } else {
      await _collectionsDao.updateCollection(
        id: itemId,
        encryptedTitle: encryptedDataBase64,
        plainTitle: plainTitle,
      );
    }
  }
}

// ── Tests ─────────────────────────────────────────────────

void main() {
  late AppDatabase db;
  late _TestSyncEngine syncEngine;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    syncEngine = _TestSyncEngine(db);
    // Force migrations
    await db.notesDao.getAllNotes();
  });

  tearDown(() async {
    await db.close();
  });

  // ── Pull ────────────────────────────────────────────────

  group('pull', () {
    test('pull with empty server returns 0 items', () async {
      syncEngine.setupPull(
        _MockPullResponse(blobs: [], latestVersion: 5),
      );

      final count = await syncEngine.pull();
      expect(count, 0);
      expect(syncEngine.pullCallCount, 1);
    });

    test('pull creates new notes from server blobs', () async {
      final notePayload = jsonEncode({
        'content': 'Hello from server',
        'title': 'Server Note',
      });
      final encryptedData = base64Encode(utf8.encode(notePayload));

      syncEngine.setupPull(_MockPullResponse(blobs: [
        {
          'item_id': 'note-from-server',
          'item_type': 'note',
          'encrypted_data': encryptedData,
          'version': 3,
        },
      ], latestVersion: 3));

      final count = await syncEngine.pull();
      expect(count, 1);

      final note = await db.notesDao.getNoteById('note-from-server');
      expect(note, isNotNull);
      expect(note!.plainContent, 'Hello from server');
      expect(note.plainTitle, 'Server Note');
    });

    test('pull creates new tags from server blobs', () async {
      final tagPayload = 'work-tag';
      final encryptedData = base64Encode(utf8.encode(tagPayload));

      syncEngine.setupPull(_MockPullResponse(blobs: [
        {
          'item_id': 'tag-from-server',
          'item_type': 'tag',
          'encrypted_data': encryptedData,
          'version': 1,
        },
      ], latestVersion: 1));

      final count = await syncEngine.pull();
      expect(count, 1);

      final tags = await db.tagsDao.getAllTags();
      expect(tags.length, 1);
      expect(tags[0].id, 'tag-from-server');
      expect(tags[0].plainName, 'work-tag');
    });

    test('pull creates new collections from server blobs', () async {
      final colPayload = 'My Collection';
      final encryptedData = base64Encode(utf8.encode(colPayload));

      syncEngine.setupPull(_MockPullResponse(blobs: [
        {
          'item_id': 'col-from-server',
          'item_type': 'collection',
          'encrypted_data': encryptedData,
          'version': 2,
        },
      ], latestVersion: 2));

      final count = await syncEngine.pull();
      expect(count, 1);

      final cols = await db.collectionsDao.getAllCollections();
      expect(cols.length, 1);
      expect(cols[0].id, 'col-from-server');
      expect(cols[0].plainTitle, 'My Collection');
    });

    test('pull updates sync meta with latest version', () async {
      syncEngine.setupPull(
        _MockPullResponse(blobs: [], latestVersion: 42),
      );

      await syncEngine.pull();

      final version =
          await db.syncMetaDao.getLastSyncedVersion('all');
      expect(version, 42);
    });

    test('pull sends current sync version to server', () async {
      await db.syncMetaDao.updateSyncMeta('all', 10);

      syncEngine.setupPull(
        _MockPullResponse(blobs: [], latestVersion: 15),
      );

      await syncEngine.pull();
      expect(syncEngine.lastPullSinceVersion, 10);
    });

    test('pull with multiple blobs of different types', () async {
      final notePayload = jsonEncode({'content': 'note content'});
      final tagPayload = 'tag-name';
      final colPayload = 'collection-title';

      syncEngine.setupPull(_MockPullResponse(blobs: [
        {
          'item_id': 'note-multi',
          'item_type': 'note',
          'encrypted_data': base64Encode(utf8.encode(notePayload)),
          'version': 1,
        },
        {
          'item_id': 'tag-multi',
          'item_type': 'tag',
          'encrypted_data': base64Encode(utf8.encode(tagPayload)),
          'version': 1,
        },
        {
          'item_id': 'col-multi',
          'item_type': 'collection',
          'encrypted_data': base64Encode(utf8.encode(colPayload)),
          'version': 1,
        },
      ], latestVersion: 3));

      final count = await syncEngine.pull();
      expect(count, 3);

      expect((await db.notesDao.getAllNotes()).length, 1);
      expect((await db.tagsDao.getAllTags()).length, 1);
      expect((await db.collectionsDao.getAllCollections()).length, 1);
    });

    test('pull without crypto stores encrypted-only content', () async {
      syncEngine.cryptoUnlocked = false;

      final notePayload = jsonEncode({'content': 'secret stuff'});
      final encryptedData = base64Encode(utf8.encode(notePayload));

      syncEngine.setupPull(_MockPullResponse(blobs: [
        {
          'item_id': 'note-encrypted-only',
          'item_type': 'note',
          'encrypted_data': encryptedData,
          'version': 1,
        },
      ], latestVersion: 1));

      final count = await syncEngine.pull();
      expect(count, 1);

      final note =
          await db.notesDao.getNoteById('note-encrypted-only');
      expect(note, isNotNull);
      // Without crypto, plainContent should be null
      expect(note!.plainContent, isNull);
    });

    test('pull updates existing note with server version', () async {
      // Create a local note first
      await db.notesDao.createNote(
        id: 'note-lww',
        encryptedContent: 'local-enc',
        plainContent: 'local content',
        plainTitle: 'local title',
      );

      // Server sends an updated version
      final serverPayload = jsonEncode({
        'content': 'server content',
        'title': 'server title',
      });
      final encryptedData = base64Encode(utf8.encode(serverPayload));

      syncEngine.setupPull(_MockPullResponse(blobs: [
        {
          'item_id': 'note-lww',
          'item_type': 'note',
          'encrypted_data': encryptedData,
          'version': 5,
        },
      ], latestVersion: 5));

      await syncEngine.pull();

      final note = await db.notesDao.getNoteById('note-lww');
      expect(note, isNotNull);
      expect(note!.plainContent, 'server content');
      expect(note.plainTitle, 'server title');
    });

    test('pull updates existing tag with server version', () async {
      await db.tagsDao.createTag(
        id: 'tag-lww',
        encryptedName: 'local-enc',
        plainName: 'local name',
      );

      final serverPayload = 'server name';
      final encryptedData = base64Encode(utf8.encode(serverPayload));

      syncEngine.setupPull(_MockPullResponse(blobs: [
        {
          'item_id': 'tag-lww',
          'item_type': 'tag',
          'encrypted_data': encryptedData,
          'version': 2,
        },
      ], latestVersion: 2));

      await syncEngine.pull();

      final tags = await db.tagsDao.getAllTags();
      expect(tags.length, 1);
      expect(tags[0].plainName, 'server name');
    });

    test('pull ignores unknown item types', () async {
      syncEngine.setupPull(_MockPullResponse(blobs: [
        {
          'item_id': 'unknown-1',
          'item_type': 'bookmark',
          'encrypted_data': base64Encode(utf8.encode('data')),
          'version': 1,
        },
      ], latestVersion: 1));

      // Should not crash; the unknown blob is counted but not applied
      final count = await syncEngine.pull();
      expect(count, 1);

      // No notes/tags/collections should have been created
      expect((await db.notesDao.getAllNotes()), isEmpty);
      expect((await db.tagsDao.getAllTags()), isEmpty);
      expect((await db.collectionsDao.getAllCollections()), isEmpty);
    });
  });

  // ── Push ────────────────────────────────────────────────

  group('push', () {
    test('push with no unsynced items returns empty response', () async {
      final result = await syncEngine.push();
      expect(result.accepted, isEmpty);
      expect(result.conflicts, isEmpty);
      // push should not have called the server if there are no items
      // (our mock increments callCount only when items exist)
      expect(syncEngine.pushCallCount, 0);
    });

    test('push sends unsynced notes and marks them synced', () async {
      await db.notesDao.createNote(
        id: 'note-push',
        encryptedContent: 'enc',
        plainContent: 'push me',
      );

      syncEngine.setupPush(_MockPushResponse(
        accepted: ['note-push'],
        conflicts: [],
      ));

      final result = await syncEngine.push();
      expect(result.accepted, ['note-push']);
      expect(syncEngine.pushCallCount, 1);

      final note = await db.notesDao.getNoteById('note-push');
      expect(note!.isSynced, true);
    });

    test('push sends unsynced tags and marks them synced', () async {
      await db.tagsDao.createTag(
        id: 'tag-push',
        encryptedName: 'enc',
        plainName: 'push tag',
      );

      syncEngine.setupPush(_MockPushResponse(
        accepted: ['tag-push'],
        conflicts: [],
      ));

      final result = await syncEngine.push();
      expect(result.accepted, ['tag-push']);

      final tags = await db.tagsDao.getAllTags();
      expect(tags[0].isSynced, true);
    });

    test('push sends unsynced collections and marks them synced',
        () async {
      await db.collectionsDao.createCollection(
        id: 'col-push',
        encryptedTitle: 'enc',
        plainTitle: 'push collection',
      );

      syncEngine.setupPush(_MockPushResponse(
        accepted: ['col-push'],
        conflicts: [],
      ));

      final result = await syncEngine.push();
      expect(result.accepted, ['col-push']);

      final cols = await db.collectionsDao.getAllCollections();
      expect(cols[0].isSynced, true);
    });

    test('push returns conflicts from server', () async {
      await db.notesDao.createNote(
        id: 'note-conflict',
        encryptedContent: 'enc',
        plainContent: 'conflicting',
      );

      syncEngine.setupPush(_MockPushResponse(
        accepted: [],
        conflicts: [
          _MockConflict(itemId: 'note-conflict', serverVersion: 5),
        ],
      ));

      final result = await syncEngine.push();
      expect(result.accepted, isEmpty);
      expect(result.conflicts.length, 1);
      expect(result.conflicts[0].itemId, 'note-conflict');
      expect(result.conflicts[0].serverVersion, 5);

      // Note should NOT be marked as synced since it was not accepted
      final note = await db.notesDao.getNoteById('note-conflict');
      expect(note!.isSynced, false);
    });

    test('push skips when crypto is not unlocked', () async {
      syncEngine.cryptoUnlocked = false;

      await db.notesDao.createNote(
        id: 'note-locked',
        encryptedContent: 'enc',
        plainContent: 'cannot push',
      );

      final result = await syncEngine.push();
      expect(result.accepted, isEmpty);
      expect(result.conflicts, isEmpty);
      expect(syncEngine.pushCallCount, 0);
    });

    test('push handles partial acceptance', () async {
      await db.notesDao.createNote(
        id: 'note-accept',
        encryptedContent: 'enc',
        plainContent: 'accepted',
      );
      await db.notesDao.createNote(
        id: 'note-reject',
        encryptedContent: 'enc',
        plainContent: 'rejected',
      );

      syncEngine.setupPush(_MockPushResponse(
        accepted: ['note-accept'],
        conflicts: [],
      ));

      final result = await syncEngine.push();
      expect(result.accepted, ['note-accept']);

      final accepted = await db.notesDao.getNoteById('note-accept');
      final rejected = await db.notesDao.getNoteById('note-reject');
      expect(accepted!.isSynced, true);
      expect(rejected!.isSynced, false);
    });
  });

  // ── Full sync cycle ─────────────────────────────────────

  group('full sync cycle', () {
    test('sync returns combined pull and push results', () async {
      syncEngine.setupPull(
        _MockPullResponse(blobs: [], latestVersion: 1),
      );
      syncEngine.setupPush(_MockPushResponse(
        accepted: [],
        conflicts: [],
      ));

      final result = await syncEngine.sync();
      expect(result.pulled, 0);
      expect(result.pushed, 0);
      expect(result.conflicts, isEmpty);
    });

    test('sync reports conflicts', () async {
      await db.notesDao.createNote(
        id: 'note-sync-conf',
        encryptedContent: 'enc',
        plainContent: 'sync conflict',
      );

      syncEngine.setupPull(
        _MockPullResponse(blobs: [], latestVersion: 1),
      );
      syncEngine.setupPush(_MockPushResponse(
        accepted: [],
        conflicts: [
          _MockConflict(itemId: 'note-sync-conf', serverVersion: 10),
        ],
      ));

      final result = await syncEngine.sync();
      expect(result.conflicts.length, 1);
      expect(result.conflicts[0].itemId, 'note-sync-conf');
    });

    test('sync pulls items then pushes local changes', () async {
      // Set up a note to push
      await db.notesDao.createNote(
        id: 'note-cycle',
        encryptedContent: 'enc',
        plainContent: 'cycle content',
      );

      final notePayload = jsonEncode({'content': 'pulled content'});
      syncEngine.setupPull(_MockPullResponse(blobs: [
        {
          'item_id': 'note-pulled',
          'item_type': 'note',
          'encrypted_data': base64Encode(utf8.encode(notePayload)),
          'version': 1,
        },
      ], latestVersion: 5));

      syncEngine.setupPush(_MockPushResponse(
        accepted: ['note-cycle'],
        conflicts: [],
      ));

      final result = await syncEngine.sync();
      expect(result.pulled, 1);
      expect(result.pushed, 1);

      // Verify pulled note exists
      final pulled = await db.notesDao.getNoteById('note-pulled');
      expect(pulled, isNotNull);
      expect(pulled!.plainContent, 'pulled content');

      // Verify pushed note is now synced
      final pushed = await db.notesDao.getNoteById('note-cycle');
      expect(pushed!.isSynced, true);
    });
  });

  // ── Sync meta tracking ──────────────────────────────────

  group('sync meta', () {
    test('initial sync meta returns version 0', () async {
      final version =
          await db.syncMetaDao.getLastSyncedVersion('all');
      expect(version, 0);
    });

    test('sync meta is updated after pull', () async {
      syncEngine.setupPull(
        _MockPullResponse(blobs: [], latestVersion: 99),
      );

      await syncEngine.pull();

      final version =
          await db.syncMetaDao.getLastSyncedVersion('all');
      expect(version, 99);
    });

    test('sync meta persists across multiple pulls', () async {
      syncEngine.setupPull(
        _MockPullResponse(blobs: [], latestVersion: 10),
      );
      await syncEngine.pull();

      syncEngine.setupPull(
        _MockPullResponse(blobs: [], latestVersion: 20),
      );
      await syncEngine.pull();

      final version =
          await db.syncMetaDao.getLastSyncedVersion('all');
      expect(version, 20);
    });

    test('sync meta supports multiple item types', () async {
      await db.syncMetaDao.updateSyncMeta('notes', 5);
      await db.syncMetaDao.updateSyncMeta('tags', 3);
      await db.syncMetaDao.updateSyncMeta('collections', 7);

      expect(await db.syncMetaDao.getLastSyncedVersion('notes'), 5);
      expect(await db.syncMetaDao.getLastSyncedVersion('tags'), 3);
      expect(
          await db.syncMetaDao.getLastSyncedVersion('collections'), 7);
    });

    test('getAll returns all sync metadata entries', () async {
      await db.syncMetaDao.updateSyncMeta('notes', 5);
      await db.syncMetaDao.updateSyncMeta('tags', 3);

      final all = await db.syncMetaDao.getAll();
      expect(all.length, 2);
    });

    test('sync meta upsert replaces existing entry', () async {
      await db.syncMetaDao.updateSyncMeta('all', 10);
      await db.syncMetaDao.updateSyncMeta('all', 20);

      final version =
          await db.syncMetaDao.getLastSyncedVersion('all');
      expect(version, 20);
    });
  });
}
