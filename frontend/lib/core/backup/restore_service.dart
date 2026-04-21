import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../crypto/crypto_service.dart';
import '../database/app_database.dart';
import 'restore_strategy.dart';

/// Service for restoring data from encrypted backup files with conflict
/// resolution support.
///
/// The restore process:
/// 1. Decrypt the backup using the provided backup key ID and crypto service.
/// 2. Compare each backup item against existing local data by UUID.
/// 3. Apply the chosen [ConflictStrategy] for duplicates.
/// 4. Re-encrypt items when using keepBoth (new UUID = new per-item key).
/// 5. Store restored items in the database and queue them for sync.
class RestoreService {
  final AppDatabase _db;
  final CryptoService _crypto;
  static const _uuid = Uuid();

  RestoreService(this._db, this._crypto);

  /// Restore items from a backup file with the chosen conflict strategy.
  ///
  /// [backupData] -- raw bytes of the backup file.
  /// [strategy] -- how to handle items that already exist locally.
  /// [onProgress] -- optional callback for progress updates.
  ///
  /// Returns a [RestoreResult] with counts of restored, skipped, and
  /// conflicting items.
  Future<RestoreResult> restore(
    List<int> backupData,
    ConflictStrategy strategy, {
    void Function(RestoreProgress)? onProgress,
  }) async {
    if (!_crypto.isUnlocked) {
      throw StateError('Crypto service must be unlocked to restore backup');
    }

    final errors = <String>[];
    var restored = 0;
    var skipped = 0;
    var conflicts = 0;

    // 1. Parse envelope.
    final jsonStr = utf8.decode(backupData);
    final envelope = jsonDecode(jsonStr) as Map<String, dynamic>;

    final format = envelope['format'] as String?;
    if (format != 'anynote-backup-v1') {
      throw FormatException('Unsupported backup format: $format');
    }

    final backupKeyId = envelope['backup_key_id'] as String;
    final encryptedData = envelope['encrypted_data'] as String;

    // 2. Decrypt backup.
    final decrypted = await _crypto.decryptForItem(backupKeyId, encryptedData);
    if (decrypted == null) {
      throw StateError(
          'Failed to decrypt backup. The encryption keys may not match.',);

    }

    final backupDataMap = jsonDecode(decrypted) as Map<String, dynamic>;

    final notes = (backupDataMap['notes'] as List?) ?? [];
    final tags = (backupDataMap['tags'] as List?) ?? [];
    final collections = (backupDataMap['collections'] as List?) ?? [];
    final contents = (backupDataMap['contents'] as List?) ?? [];

    final totalItems =
        notes.length + tags.length + collections.length + contents.length;
    var current = 0;

    // 3. Load existing local item IDs for conflict detection.
    final existingNotes = await _db.notesDao.getAllNotes();
    final existingNoteIds = existingNotes.map((n) => n.id).toSet();

    final existingTags = await _db.tagsDao.getAllTags();
    final existingTagIds = existingTags.map((t) => t.id).toSet();

    final existingCollections = await _db.collectionsDao.getAllCollections();
    final existingCollectionIds =
        existingCollections.map((c) => c.id).toSet();

    final existingContentList = await _db.generatedContentsDao.getAll();
    final existingContentIds =
        existingContentList.map((c) => c.id).toSet();

    // 4. Restore notes.
    onProgress?.call(RestoreProgress(
      current: current,
      total: totalItems,
      step: 'notes',
    ),);

    for (final noteJson in notes) {
      current++;
      final n = noteJson as Map<String, dynamic>;

      try {
        final noteId = n['id'] as String;
        if (existingNoteIds.contains(noteId)) {
          conflicts++;
          switch (strategy) {
            case ConflictStrategy.skip:
              skipped++;
              onProgress?.call(RestoreProgress(
                current: current,
                total: totalItems,
                step: 'notes',
              ),);
              continue;

            case ConflictStrategy.overwrite:
              await _db.notesDao.updateNote(
                id: noteId,
                encryptedContent: n['encrypted_content'] as String,
                encryptedTitle: n['encrypted_title'] as String?,
                plainContent: n['plain_content'] as String?,
                plainTitle: n['plain_title'] as String?,
              );
              restored++;

            case ConflictStrategy.keepBoth:
              // Create a new note with a new UUID. Re-encrypt the plaintext
              // content for the new item key. The old encrypted content cannot
              // be re-used because per-item keys are derived from the UUID.
              final newId = _uuid.v4();
              final plainContent = n['plain_content'] as String?;
              final plainTitle = n['plain_title'] as String?;
              final restoredTitle =
                  plainTitle != null ? '$plainTitle (restored)' : null;

              String newEncryptedContent;
              String? newEncryptedTitle;

              if (plainContent != null) {
                newEncryptedContent =
                    await _crypto.encryptForItem(newId, plainContent);
              } else {
                // If no plaintext is available, we cannot re-encrypt for a
                // new item key. Fall back to copying the existing encrypted
                // content, which will only be decryptable with the original key.
                newEncryptedContent = n['encrypted_content'] as String;
              }

              if (plainTitle != null) {
                newEncryptedTitle =
                    await _crypto.encryptForItem(newId, plainTitle);
              } else if (n['encrypted_title'] != null) {
                newEncryptedTitle = n['encrypted_title'] as String?;
              }

              await _db.notesDao.createNote(
                id: newId,
                encryptedContent: newEncryptedContent,
                encryptedTitle: newEncryptedTitle,
                plainContent: plainContent,
                plainTitle: restoredTitle,
              );
              restored++;
          }
        } else {
          // No conflict: insert directly.
          await _db.notesDao.createNote(
            id: noteId,
            encryptedContent: n['encrypted_content'] as String,
            encryptedTitle: n['encrypted_title'] as String?,
            plainContent: n['plain_content'] as String?,
            plainTitle: n['plain_title'] as String?,
          );
          restored++;
        }
      } catch (e) {
        final id = n['id'];
        errors.add('Note ${id ?? 'unknown'}: ${e.toString()}');
      }

      onProgress?.call(RestoreProgress(
        current: current,
        total: totalItems,
        step: 'notes',
      ),);
    }

    // 5. Restore tags.
    for (final tagJson in tags) {
      current++;
      final t = tagJson as Map<String, dynamic>;
      final tagId = t['id'] as String;

      try {
        if (existingTagIds.contains(tagId)) {
          conflicts++;
          switch (strategy) {
            case ConflictStrategy.skip:
              skipped++;
              onProgress?.call(RestoreProgress(
                current: current,
                total: totalItems,
                step: 'tags',
              ),);
              continue;

            case ConflictStrategy.overwrite:
              await _db.tagsDao.updateTag(
                id: tagId,
                encryptedName: t['encrypted_name'] as String,
                plainName: t['plain_name'] as String?,
              );
              restored++;

            case ConflictStrategy.keepBoth:
              final newId = _uuid.v4();
              final plainName = t['plain_name'] as String?;
              final restoredName =
                  plainName != null ? '$plainName (restored)' : null;

              String newEncryptedName;
              if (plainName != null) {
                newEncryptedName =
                    await _crypto.encryptForItem(newId, plainName);
              } else {
                newEncryptedName = t['encrypted_name'] as String;
              }

              await _db.tagsDao.createTag(
                id: newId,
                encryptedName: newEncryptedName,
                plainName: restoredName,
              );
              restored++;
          }
        } else {
          await _db.tagsDao.createTag(
            id: tagId,
            encryptedName: t['encrypted_name'] as String,
            plainName: t['plain_name'] as String?,
          );
          restored++;
        }
      } catch (e) {
        errors.add('Tag $tagId: ${e.toString()}');
      }

      onProgress?.call(RestoreProgress(
        current: current,
        total: totalItems,
        step: 'tags',
      ),);
    }

    // 6. Restore collections.
    for (final colJson in collections) {
      current++;
      final c = colJson as Map<String, dynamic>;
      final colId = c['id'] as String;

      try {
        if (existingCollectionIds.contains(colId)) {
          conflicts++;
          switch (strategy) {
            case ConflictStrategy.skip:
              skipped++;
              onProgress?.call(RestoreProgress(
                current: current,
                total: totalItems,
                step: 'collections',
              ),);
              continue;

            case ConflictStrategy.overwrite:
              await _db.collectionsDao.updateCollection(
                id: colId,
                encryptedTitle: c['encrypted_title'] as String,
                plainTitle: c['plain_title'] as String?,
              );
              restored++;

            case ConflictStrategy.keepBoth:
              final newId = _uuid.v4();
              final plainTitle = c['plain_title'] as String?;
              final restoredTitle =
                  plainTitle != null ? '$plainTitle (restored)' : null;

              String newEncryptedTitle;
              if (plainTitle != null) {
                newEncryptedTitle =
                    await _crypto.encryptForItem(newId, plainTitle);
              } else {
                newEncryptedTitle = c['encrypted_title'] as String;
              }

              await _db.collectionsDao.createCollection(
                id: newId,
                encryptedTitle: newEncryptedTitle,
                plainTitle: restoredTitle,
              );
              restored++;
          }
        } else {
          await _db.collectionsDao.createCollection(
            id: colId,
            encryptedTitle: c['encrypted_title'] as String,
            plainTitle: c['plain_title'] as String?,
          );
          restored++;
        }
      } catch (e) {
        errors.add('Collection $colId: ${e.toString()}');
      }

      onProgress?.call(RestoreProgress(
        current: current,
        total: totalItems,
        step: 'collections',
      ),);
    }

    // 7. Restore AI-generated contents.
    for (final contentJson in contents) {
      current++;
      final c = contentJson as Map<String, dynamic>;
      final contentId = c['id'] as String;

      try {
        if (existingContentIds.contains(contentId)) {
          conflicts++;
          switch (strategy) {
            case ConflictStrategy.skip:
              skipped++;
              onProgress?.call(RestoreProgress(
                current: current,
                total: totalItems,
                step: 'contents',
              ),);
              continue;

            case ConflictStrategy.overwrite:
              await _db.generatedContentsDao.updateContent(
                id: contentId,
                encryptedBody: c['encrypted_body'] as String,
                plainBody: c['plain_body'] as String?,
              );
              restored++;

            case ConflictStrategy.keepBoth:
              final newId = _uuid.v4();
              final plainBody = c['plain_body'] as String?;

              String newEncryptedBody;
              if (plainBody != null) {
                newEncryptedBody =
                    await _crypto.encryptForItem(newId, plainBody);
              } else {
                newEncryptedBody = c['encrypted_body'] as String;
              }

              await _db.generatedContentsDao.create(
                id: newId,
                encryptedBody: newEncryptedBody,
                plainBody: plainBody,
                platformStyle:
                    (c['platform_style'] as String?) ?? 'generic',
                aiModelUsed: (c['ai_model_used'] as String?) ?? '',
              );
              restored++;
          }
        } else {
          await _db.generatedContentsDao.create(
            id: contentId,
            encryptedBody: c['encrypted_body'] as String,
            plainBody: c['plain_body'] as String?,
            platformStyle:
                (c['platform_style'] as String?) ?? 'generic',
            aiModelUsed: (c['ai_model_used'] as String?) ?? '',
          );
          restored++;
        }
      } catch (e) {
        errors.add('Content $contentId: ${e.toString()}');
      }

      onProgress?.call(RestoreProgress(
        current: current,
        total: totalItems,
        step: 'contents',
      ),);
    }

    return RestoreResult(
      restored: restored,
      skipped: skipped,
      conflicts: conflicts,
      errors: errors,
    );
  }
}
