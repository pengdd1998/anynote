import 'dart:convert';

import '../database/app_database.dart';
import '../database/daos/notes_dao.dart';
import '../database/daos/tags_dao.dart';
import '../database/daos/collections_dao.dart';
import '../database/daos/sync_meta_dao.dart';
import '../network/api_client.dart';
import 'version_vector.dart';
import 'conflict_resolver.dart';

/// Sync engine orchestrates bidirectional sync between client and server.
///
/// Protocol:
/// 1. Pull: GET /sync/pull?since={version} → get encrypted blobs
/// 2. Decrypt blobs locally → apply to local DB
/// 3. Push: POST /sync/push → send local changes (encrypted)
///
/// The server never sees plaintext data.
class SyncEngine {
  final AppDatabase _db;
  final ApiClient _api;

  SyncEngine(this._db, this._api);

  /// Full sync cycle: pull then push.
  Future<SyncResult> sync() async {
    final pullResult = await pull();
    final pushResult = await push();
    return SyncResult(
      pulledCount: pullResult,
      pushedCount: pushResult.accepted.length,
      conflicts: pushResult.conflicts,
    );
  }

  /// Pull remote changes and apply to local DB.
  /// Returns the number of items pulled.
  Future<int> pull() async {
    final syncMetaDao = _db.syncMetaDao;
    final sinceVersion = await syncMetaDao.getLastSyncedVersion('all');

    final response = await _api.syncPull(sinceVersion);

    var count = 0;
    for (final blob in response.blobs) {
      switch (blob.itemType) {
        case 'note':
          await _applyNoteBlob(blob);
          break;
        case 'tag':
          await _applyTagBlob(blob);
          break;
        case 'collection':
          await _applyCollectionBlob(blob);
          break;
        case 'content':
          await _applyContentBlob(blob);
          break;
      }
      count++;
    }

    // Update sync meta with latest version
    await syncMetaDao.updateSyncMeta('all', response.latestVersion);

    return count;
  }

  /// Push local changes to server.
  Future<SyncPushResponse> push() async {
    final items = <SyncPushItem>[];

    // Gather unsynced notes
    final unsyncedNotes = await _db.notesDao.getUnsyncedNotes();
    for (final note in unsyncedNotes) {
      items.add(SyncPushItem(
        itemId: note.id,
        itemType: 'note',
        version: note.version,
        encryptedData: base64Decode(note.encryptedContent),
        blobSize: note.encryptedContent.length,
      ));
    }

    // Gather unsynced tags
    final unsyncedTags = await _db.tagsDao.getUnsyncedTags();
    for (final tag in unsyncedTags) {
      items.add(SyncPushItem(
        itemId: tag.id,
        itemType: 'tag',
        version: tag.version,
        encryptedData: base64Decode(tag.encryptedName),
        blobSize: tag.encryptedName.length,
      ));
    }

    // Gather unsynced collections
    final unsyncedCollections = await _db.collectionsDao.getUnsyncedCollections();
    for (final collection in unsyncedCollections) {
      items.add(SyncPushItem(
        itemId: collection.id,
        itemType: 'collection',
        version: collection.version,
        encryptedData: base64Decode(collection.encryptedTitle),
        blobSize: collection.encryptedTitle.length,
      ));
    }

    if (items.isEmpty) {
      return SyncPushResponse(accepted: [], conflicts: []);
    }

    final response = await _api.syncPush(SyncPushRequest(blobs: items));

    // Mark accepted items as synced
    for (final id in response.accepted) {
      // Find the item in our list and mark it synced
      final item = items.firstWhere(
        (i) => i.itemId == id.toString(),
        orElse: () => items.first,
      );
      switch (item.itemType) {
        case 'note':
          await _db.notesDao.markSynced(item.itemId);
          break;
        case 'tag':
          await _db.tagsDao.markSynced(item.itemId);
          break;
        case 'collection':
          await _db.collectionsDao.markSynced(item.itemId);
          break;
      }
    }

    return response;
  }

  /// Apply a pulled note blob to local DB.
  Future<void> _applyNoteBlob(SyncBlob blob) async {
    final existing = await _db.notesDao.getNoteById(blob.itemId);

    if (existing == null) {
      // New note from server - insert with encrypted data
      // Plaintext will be populated after decryption
      await _db.notesDao.createNote(
        id: blob.itemId,
        encryptedContent: base64Encode(blob.encryptedData),
      );
    } else {
      // Existing note - resolve conflict with LWW
      final result = ConflictResolver.resolve(
        local: existing,
        remote: blob,
        localUpdatedAt: existing.updatedAt,
        remoteUpdatedAt: blob.updatedAt,
      );

      if (result.winner == blob) {
        // Server version wins, update local
        await _db.notesDao.updateNote(
          id: blob.itemId,
          encryptedContent: base64Encode(blob.encryptedData),
        );
      }
      // If local wins, we keep local version (will be pushed next sync)
    }
  }

  Future<void> _applyTagBlob(SyncBlob blob) async {
    // Similar to note blob application
    await _db.tagsDao.updateTag(
      id: blob.itemId,
      encryptedName: base64Encode(blob.encryptedData),
    );
  }

  Future<void> _applyCollectionBlob(SyncBlob blob) async {
    await _db.collectionsDao.updateCollection(
      id: blob.itemId,
      encryptedTitle: base64Encode(blob.encryptedData),
    );
  }

  Future<void> _applyContentBlob(SyncBlob blob) async {
    await _db.generatedContentsDao.update(
      id: blob.itemId,
      encryptedBody: base64Encode(blob.encryptedData),
    );
  }
}

class SyncResult {
  final int pulledCount;
  final int pushedCount;
  final List<SyncConflict> conflicts;

  SyncResult({
    required this.pulledCount,
    required this.pushedCount,
    this.conflicts = const [],
  });

  bool get hasConflicts => conflicts.isNotEmpty;
}

// ── Data transfer objects for sync ──

class SyncBlob {
  final String itemId;
  final String itemType;
  final List<int> encryptedData;
  final int version;
  final DateTime updatedAt;

  SyncBlob({
    required this.itemId,
    required this.itemType,
    required this.encryptedData,
    required this.version,
    required this.updatedAt,
  });
}

class SyncPullResponseDto {
  final List<SyncBlob> blobs;
  final int latestVersion;

  SyncPullResponseDto({required this.blobs, required this.latestVersion});
}

class SyncPushRequest {
  final List<SyncPushItem> blobs;

  SyncPushRequest({required this.blobs});
}

class SyncPushItem {
  final String itemId;
  final String itemType;
  final int version;
  final List<int> encryptedData;
  final int blobSize;

  SyncPushItem({
    required this.itemId,
    required this.itemType,
    required this.version,
    required this.encryptedData,
    required this.blobSize,
  });

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'item_type': itemType,
        'version': version,
        'encrypted_data': base64Encode(encryptedData),
        'blob_size': blobSize,
      };
}

class SyncPushResponse {
  final List<String> accepted;
  final List<SyncConflict> conflicts;

  SyncPushResponse({required this.accepted, required this.conflicts});
}

class SyncConflict {
  final String itemId;
  final int serverVersion;

  SyncConflict({required this.itemId, required this.serverVersion});
}
