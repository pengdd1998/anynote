import 'dart:convert';
import 'dart:io' show File
    if (dart.library.js) 'package:anynote/core/stubs/io_stub.dart';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../crypto/crypto_service.dart';
import '../database/app_database.dart';
import '../performance/performance_monitor.dart';
import '../network/api_client.dart';
import '../storage/image_storage.dart';
import 'conflict_resolver.dart';
import 'sync_progress.dart';

/// Sync engine orchestrates bidirectional sync between client and server
/// with full E2E encryption.
///
/// Protocol:
/// 1. Pull: GET /sync/pull?since={version} -> receive encrypted blobs
/// 2. Decrypt each blob locally using per-item keys via CryptoService
/// 3. Store decrypted plaintext in local Drift DB + update FTS5 index
/// 4. Push: Encrypt local unsynced items -> POST /sync/push -> mark synced
///
/// The server never sees plaintext data.
class SyncEngine {
  final AppDatabase _db;
  final ApiClient _api;
  final CryptoService _crypto;

  /// Cached stable device ID. Generated once, persisted in SharedPreferences.
  static String? _cachedDeviceId;

  SyncEngine(this._db, this._api, this._crypto);

  /// Returns a stable device ID, generating and persisting one if needed.
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
    }
    _cachedDeviceId = deviceId;
    return deviceId;
  }

  /// Reset the cached device ID (for testing).
  static void resetDeviceIdCache() => _cachedDeviceId = null;

  /// Full sync cycle: pull then push.
  ///
  /// Emits progress events via [SyncProgressNotifier] so the UI can display
  /// a progress bar and current-item label.
  Future<SyncResult> sync() async {
    final pm = PerformanceMonitor.instance;
    final notifier = SyncProgressNotifier.instance;
    pm.start('sync');

    try {
      final pullResult = await pull();
      final pushResult = await push();
      pm.end('sync');

      notifier.emit(
        SyncProgress(
          phase: SyncPhase.done,
          completedCount: pullResult + pushResult.accepted.length,
          totalCount: pullResult + pushResult.accepted.length,
          completedAt: DateTime.now(),
        ),
      );

      return SyncResult(
        pulledCount: pullResult,
        pushedCount: pushResult.accepted.length,
        conflicts: pushResult.conflicts,
      );
    } catch (e) {
      pm.end('sync');
      notifier.emit(
        SyncProgress(
          phase: SyncPhase.error,
          failedItems: [
            SyncFailedItem(
              itemId: '',
              itemType: '',
              error: e.toString(),
            ),
          ],
        ),
      );
      rethrow;
    }
  }

  /// Pull remote changes, decrypt, and apply to local DB.
  /// Returns the number of items pulled.
  ///
  /// If the crypto service is not unlocked (first launch / offline), blobs
  /// are stored encrypted-only and will be decrypted on a future sync when
  /// the key becomes available.
  Future<int> pull() async {
    final syncMetaDao = _db.syncMetaDao;
    final sinceVersion = await syncMetaDao.getLastSyncedVersion('all');
    final notifier = SyncProgressNotifier.instance;

    final response = await _api.syncPull(sinceVersion);

    final total = response.blobs.length;
    notifier.emit(
      SyncProgress(
        phase: SyncPhase.pulling,
        completedCount: 0,
        totalCount: total,
      ),
    );

    var count = 0;
    for (final rawBlob in response.blobs) {
      // Parse the raw JSON blob from the API response into a typed SyncBlob.
      final blob = _parseBlob(rawBlob as Map<String, dynamic>);
      notifier.emit(
        notifier.current.copyWith(
          currentItemLabel: '${blob.itemType} ${blob.itemId.substring(0, 8)}',
          completedCount: count,
        ),
      );
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
        case 'image':
          await _applyImageBlob(blob);
          break;
      }
      count++;
      notifier.emit(notifier.current.copyWith(completedCount: count));
    }

    // Update sync meta with latest version
    await syncMetaDao.updateSyncMeta('all', response.latestVersion);

    return count;
  }

  /// Push local changes to server, encrypting each item before sending.
  ///
  /// If crypto is not unlocked, the push is skipped entirely -- we cannot
  /// send plaintext to the zero-knowledge server.
  Future<SyncPushResponse> push() async {
    // Cannot push without encryption keys -- the server is zero-knowledge.
    if (!_crypto.isUnlocked) {
      return SyncPushResponse(accepted: [], conflicts: []);
    }

    final notifier = SyncProgressNotifier.instance;
    final items = <SyncPushItem>[];
    final deviceId = await getDeviceId();

    // Gather and encrypt unsynced notes (parallel)
    final unsyncedNotes = await _db.notesDao.getUnsyncedNotes();
    final noteResults = await Future.wait(
      unsyncedNotes.map((note) async {
        final encryptedData = await _encryptNoteForPush(note);
        if (encryptedData == null) return null;
        return SyncPushItem(
          itemId: note.id,
          itemType: 'note',
          version: note.version,
          encryptedData: encryptedData,
          blobSize: encryptedData.length,
          deviceId: deviceId,
        );
      }),
    );
    items.addAll(noteResults.whereType<SyncPushItem>());

    // Gather and encrypt unsynced tags (parallel)
    final unsyncedTags = await _db.tagsDao.getUnsyncedTags();
    final tagResults = await Future.wait(
      unsyncedTags.map((tag) async {
        final encryptedData = await _encryptTagForPush(tag);
        if (encryptedData == null) return null;
        return SyncPushItem(
          itemId: tag.id,
          itemType: 'tag',
          version: tag.version,
          encryptedData: encryptedData,
          blobSize: encryptedData.length,
          deviceId: deviceId,
        );
      }),
    );
    items.addAll(tagResults.whereType<SyncPushItem>());

    // Gather and encrypt unsynced collections (parallel)
    final unsyncedCollections =
        await _db.collectionsDao.getUnsyncedCollections();
    final collectionResults = await Future.wait(
      unsyncedCollections.map((collection) async {
        final encryptedData = await _encryptCollectionForPush(collection);
        if (encryptedData == null) return null;
        return SyncPushItem(
          itemId: collection.id,
          itemType: 'collection',
          version: collection.version,
          encryptedData: encryptedData,
          blobSize: encryptedData.length,
          deviceId: deviceId,
        );
      }),
    );
    items.addAll(collectionResults.whereType<SyncPushItem>());

    // Gather and encrypt unsynced generated contents (parallel)
    final unsyncedContents = await _db.generatedContentsDao.getUnsynced();
    final contentResults = await Future.wait(
      unsyncedContents.map((content) async {
        final encryptedData = await _encryptContentForPush(content);
        if (encryptedData == null) return null;
        return SyncPushItem(
          itemId: content.id,
          itemType: 'content',
          version: content.version,
          encryptedData: encryptedData,
          blobSize: encryptedData.length,
          deviceId: deviceId,
        );
      }),
    );
    items.addAll(contentResults.whereType<SyncPushItem>());

    // Gather and encrypt unsynced images (parallel)
    final unsyncedImages = await _db.imagesDao.getUnsyncedImages();
    final imageResults = await Future.wait(
      unsyncedImages.map((image) async {
        // Read image file bytes (skip if file has been deleted)
        final file = File(image.path);
        if (!await file.exists()) return null;
        final bytes = await file.readAsBytes();

        // Encrypt the image data (base64-encode first, matching note envelope pattern)
        final encryptedBase64 =
            await _crypto.encryptForItem(image.id, base64Encode(bytes));
        final encryptedBytes = base64Decode(encryptedBase64);

        return SyncPushItem(
          itemId: image.id,
          itemType: 'image',
          version: 0,
          encryptedData: encryptedBytes,
          blobSize: encryptedBytes.length,
          deviceId: deviceId,
        );
      }),
    );
    items.addAll(imageResults.whereType<SyncPushItem>());

    if (items.isEmpty) {
      return SyncPushResponse(accepted: [], conflicts: []);
    }

    notifier.emit(
      SyncProgress(
        phase: SyncPhase.pushing,
        completedCount: 0,
        totalCount: items.length,
        currentItemLabel: 'Encrypting ${items.length} items',
      ),
    );

    final rawResponse = await _api.syncPush(
      SyncPushRequest(blobs: items).toJson(),
    );

    // Parse the server JSON response into a typed SyncPushResponse.
    final response = _parsePushResponse(rawResponse as Map<String, dynamic>);

    // Mark accepted items as synced (O(1) lookup + batch per type)
    final itemById = {for (final item in items) item.itemId: item};
    final notesToSync = <String>[];
    final tagsToSync = <String>[];
    final collectionsToSync = <String>[];
    final contentsToSync = <String>[];
    final imagesToSync = <String>[];

    for (final id in response.accepted) {
      final item = itemById[id];
      if (item == null) continue;
      switch (item.itemType) {
        case 'note':
          notesToSync.add(id);
        case 'tag':
          tagsToSync.add(id);
        case 'collection':
          collectionsToSync.add(id);
        case 'content':
          contentsToSync.add(id);
        case 'image':
          imagesToSync.add(id);
      }
    }

    // Batch mark synced
    if (notesToSync.isNotEmpty) await _db.notesDao.markSyncedBatch(notesToSync);
    if (tagsToSync.isNotEmpty) await _db.tagsDao.markSyncedBatch(tagsToSync);
    if (collectionsToSync.isNotEmpty) {
      await _db.collectionsDao.markSyncedBatch(collectionsToSync);
    }
    if (contentsToSync.isNotEmpty) {
      await _db.generatedContentsDao.markSyncedBatch(contentsToSync);
    }
    if (imagesToSync.isNotEmpty) await _db.imagesDao.markSyncedBatch(imagesToSync);

    return response;
  }

  // ── Pull: decrypt and apply blobs ──────────────────────

  /// Apply a pulled note blob to the local DB.
  ///
  /// Decrypts the blob content to populate plainContent/plainTitle.
  /// If crypto is not unlocked, stores only the encrypted data; the
  /// plaintext fields remain null until a subsequent sync can decrypt.
  Future<void> _applyNoteBlob(SyncBlob blob) async {
    final existing = await _db.notesDao.getNoteById(blob.itemId);

    // Attempt decryption of the blob payload.
    final decrypted = await _tryDecryptBlob(blob.itemId, blob.encryptedData);
    String? plainContent;
    String? plainTitle;

    if (decrypted != null) {
      // The server stores a JSON envelope so that a single blob can carry
      // both title and content for a note.
      try {
        final envelope = jsonDecode(decrypted) as Map<String, dynamic>;
        plainContent = envelope['content'] as String?;
        plainTitle = envelope['title'] as String?;
      } catch (e) {
        debugPrint(
          '[SyncEngine] Note envelope parse error, using raw content: $e',
        );
        // Fallback: treat the entire decrypted payload as the note content.
        plainContent = decrypted;
      }
    }

    final encryptedBase64 = base64Encode(blob.encryptedData);

    if (existing == null) {
      // New note from server -- insert with both encrypted and plain data.
      await _db.notesDao.createNote(
        id: blob.itemId,
        encryptedContent: encryptedBase64,
        encryptedTitle: plainTitle != null
            ? await _crypto.encryptForItem(blob.itemId, plainTitle)
            : null,
        plainContent: plainContent,
        plainTitle: plainTitle,
      );
    } else {
      // Existing note -- resolve conflict with LWW.
      final result = ConflictResolver.resolve(
        local: existing,
        remote: blob,
        localUpdatedAt: existing.updatedAt,
        remoteUpdatedAt: blob.updatedAt,
      );

      if (result.winner == blob) {
        // Remote version wins -- update local with decrypted content.
        await _db.notesDao.updateNote(
          id: blob.itemId,
          encryptedContent: encryptedBase64,
          encryptedTitle: plainTitle != null
              ? await _crypto.encryptForItem(blob.itemId, plainTitle)
              : null,
          plainContent: plainContent,
          plainTitle: plainTitle,
        );
      }
      // If local wins, we keep the local version (will be pushed next sync).
    }
  }

  /// Apply a pulled tag blob to the local DB.
  Future<void> _applyTagBlob(SyncBlob blob) async {
    final decrypted = await _tryDecryptBlob(blob.itemId, blob.encryptedData);
    final encryptedBase64 = base64Encode(blob.encryptedData);

    await _db.tagsDao.updateTag(
      id: blob.itemId,
      encryptedName: encryptedBase64,
      plainName: decrypted,
    );
  }

  /// Apply a pulled collection blob to the local DB.
  Future<void> _applyCollectionBlob(SyncBlob blob) async {
    final decrypted = await _tryDecryptBlob(blob.itemId, blob.encryptedData);
    final encryptedBase64 = base64Encode(blob.encryptedData);

    await _db.collectionsDao.updateCollection(
      id: blob.itemId,
      encryptedTitle: encryptedBase64,
      plainTitle: decrypted,
    );
  }

  /// Apply a pulled generated-content blob to the local DB.
  Future<void> _applyContentBlob(SyncBlob blob) async {
    final decrypted = await _tryDecryptBlob(blob.itemId, blob.encryptedData);
    final encryptedBase64 = base64Encode(blob.encryptedData);

    await _db.generatedContentsDao.updateContent(
      id: blob.itemId,
      encryptedBody: encryptedBase64,
      plainBody: decrypted,
    );
  }

  /// Apply a pulled image blob to local storage.
  ///
  /// Decrypts the blob payload (base64-encoded image bytes), writes the image
  /// to local storage, and upserts the image metadata record. If crypto is not
  /// unlocked, the blob is silently skipped -- it will be re-delivered on a
  /// future pull when the key becomes available.
  Future<void> _applyImageBlob(SyncBlob blob) async {
    final decrypted = await _tryDecryptBlob(blob.itemId, blob.encryptedData);
    if (decrypted == null) return; // Can't decrypt, skip for now

    // Decode the decrypted base64 data back to raw image bytes
    final imageBytes = Uint8List.fromList(base64Decode(decrypted));

    // Save to local storage (skip compression -- already compressed on source)
    final path = await ImageStorage.saveImage(
      imageBytes,
      'synced',
      compress: false,
    );

    // Check if image record already exists
    final existing = await _db.imagesDao.getImageById(blob.itemId);
    if (existing == null) {
      // Insert new image record
      await _db.imagesDao.upsertImage(
        NoteImagesCompanion(
          id: Value(blob.itemId),
          noteId: const Value(''),
          path: Value(path),
          hash: const Value(''),
          fileSize: Value(imageBytes.length),
          isSynced: const Value(true),
        ),
      );
    } else {
      // Update existing record with the new path and mark synced
      await _db.imagesDao.upsertImage(
        NoteImagesCompanion(
          id: Value(blob.itemId),
          noteId: Value(existing.noteId),
          path: Value(path),
          hash: const Value(''),
          fileSize: Value(imageBytes.length),
          isSynced: const Value(true),
        ),
      );
    }
  }

  // ── Push: encrypt items before sending ─────────────────

  /// Encrypt a note for push. Returns null if encryption fails.
  ///
  /// The note's plainContent and plainTitle are packed into a JSON envelope
  /// {"content": "...", "title": "..."} and encrypted as a single blob.
  Future<Uint8List?> _encryptNoteForPush(Note note) async {
    try {
      // Build the plaintext envelope for the note.
      final envelope = <String, dynamic>{};
      if (note.plainContent != null) {
        envelope['content'] = note.plainContent!;
      } else {
        // No plaintext available -- the note may have been created before
        // crypto was unlocked. Use the existing encrypted content as-is.
        return _existingEncryptedData(note.encryptedContent);
      }
      if (note.plainTitle != null) {
        envelope['title'] = note.plainTitle!;
      }

      final plaintext = jsonEncode(envelope);
      final encrypted = await _crypto.encryptForItem(note.id, plaintext);
      return base64Decode(encrypted);
    } catch (e) {
      debugPrint('[SyncEngine] Note encryption for push failed: $e');
      return null;
    }
  }

  /// Encrypt a tag for push. Returns null if encryption fails.
  Future<Uint8List?> _encryptTagForPush(Tag tag) async {
    try {
      if (tag.plainName != null) {
        final encrypted = await _crypto.encryptForItem(tag.id, tag.plainName!);
        return base64Decode(encrypted);
      }
      return _existingEncryptedData(tag.encryptedName);
    } catch (e) {
      debugPrint('[SyncEngine] Tag encryption for push failed: $e');
      return null;
    }
  }

  /// Encrypt a collection for push. Returns null if encryption fails.
  Future<Uint8List?> _encryptCollectionForPush(Collection collection) async {
    try {
      if (collection.plainTitle != null) {
        final encrypted =
            await _crypto.encryptForItem(collection.id, collection.plainTitle!);
        return base64Decode(encrypted);
      }
      return _existingEncryptedData(collection.encryptedTitle);
    } catch (e) {
      debugPrint('[SyncEngine] Collection encryption for push failed: $e');
      return null;
    }
  }

  /// Encrypt a generated content for push. Returns null if encryption fails.
  Future<Uint8List?> _encryptContentForPush(GeneratedContent content) async {
    try {
      if (content.plainBody != null) {
        final encrypted =
            await _crypto.encryptForItem(content.id, content.plainBody!);
        return base64Decode(encrypted);
      }
      return _existingEncryptedData(content.encryptedBody);
    } catch (e) {
      debugPrint('[SyncEngine] Content encryption for push failed: $e');
      return null;
    }
  }

  // ── Helpers ────────────────────────────────────────────

  /// Attempt to decrypt a blob. Returns null if crypto is not unlocked
  /// or if decryption fails (corrupted blob, wrong key, etc.).
  Future<String?> _tryDecryptBlob(
    String itemId,
    List<int> encryptedData,
  ) async {
    if (!_crypto.isUnlocked) return null;
    try {
      final encryptedBase64 = base64Encode(encryptedData);
      return _crypto.decryptForItem(itemId, encryptedBase64);
    } catch (e) {
      debugPrint('[SyncEngine] Blob decryption failed for item $itemId: $e');
      return null;
    }
  }

  /// Convert existing base64-encoded encrypted data back to raw bytes
  /// for the push payload. Used as a fallback when plaintext is not
  /// available (item was created before crypto was unlocked).
  Uint8List? _existingEncryptedData(String encryptedBase64) {
    try {
      return base64Decode(encryptedBase64);
    } catch (e) {
      debugPrint(
        '[SyncEngine] Base64 decode of existing encrypted data failed: $e',
      );
      return null;
    }
  }

  /// Parse a raw JSON map from the API response into a SyncBlob.
  SyncBlob _parseBlob(Map<String, dynamic> json) {
    return SyncBlob(
      itemId: json['item_id'] as String,
      itemType: json['item_type'] as String,
      encryptedData: _decodeEncryptedData(json['encrypted_data']),
      version: json['version'] as int,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Decode the encrypted_data field from the API response.
  /// The server returns it as a base64 string.
  Uint8List _decodeEncryptedData(dynamic data) {
    if (data is String) {
      return base64Decode(data);
    }
    if (data is List) {
      return Uint8List.fromList(data.cast<int>());
    }
    throw FormatException(
      'Unexpected encrypted_data format: ${data.runtimeType}',
    );
  }

  /// Parse the push response JSON from the server.
  SyncPushResponse _parsePushResponse(Map<String, dynamic> json) {
    final acceptedRaw = json['accepted'] as List<dynamic>? ?? [];
    final conflictsRaw = json['conflicts'] as List<dynamic>? ?? [];

    return SyncPushResponse(
      accepted: acceptedRaw.map((e) => e.toString()).toList(),
      conflicts: conflictsRaw
          .map(
            (e) => SyncConflict(
              itemId: (e as Map<String, dynamic>)['item_id'] as String,
              serverVersion: e['server_version'] as int,
            ),
          )
          .toList(),
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

class SyncPushRequest {
  final List<SyncPushItem> blobs;

  SyncPushRequest({required this.blobs});

  Map<String, dynamic> toJson() => {
        'blobs': blobs.map((b) => b.toJson()).toList(),
      };
}

class SyncPushItem {
  final String itemId;
  final String itemType;
  final int version;
  final List<int> encryptedData;
  final int blobSize;
  final String deviceId;

  SyncPushItem({
    required this.itemId,
    required this.itemType,
    required this.version,
    required this.encryptedData,
    required this.blobSize,
    this.deviceId = '',
  });

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'item_type': itemType,
        'version': version,
        'encrypted_data': base64Encode(encryptedData),
        'blob_size': blobSize,
        if (deviceId.isNotEmpty) 'device_id': deviceId,
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
