import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../crypto/crypto_service.dart';
import '../database/app_database.dart';
import 'restore_strategy.dart';

/// Service for exporting and importing encrypted vault backups.
class BackupService {
  final AppDatabase _db;
  final CryptoService _crypto;
  static const _uuid = Uuid();

  BackupService(this._db, this._crypto);

  /// Export all user data as an encrypted backup file.
  Future<Uint8List> exportBackup() async {
    if (!_crypto.isUnlocked) {
      throw StateError('Crypto service must be unlocked to create backup');
    }

    final notes = await _db.notesDao.getAllNotes();
    final tags = await _db.tagsDao.getAllTags();
    final collections = await _db.collectionsDao.getAllCollections();
    final contents = await _db.generatedContentsDao.getAll();

    final data = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'notes': notes
          .map((n) => {
                'id': n.id,
                'encrypted_content': n.encryptedContent,
                'encrypted_title': n.encryptedTitle,
                'plain_content': n.plainContent,
                'plain_title': n.plainTitle,
                'created_at': n.createdAt.toIso8601String(),
                'updated_at': n.updatedAt.toIso8601String(),
                'version': n.version,
                'is_synced': n.isSynced,
                'deleted_at': n.deletedAt?.toIso8601String(),
              },)
          .toList(),
      'tags': tags
          .map((t) => {
                'id': t.id,
                'encrypted_name': t.encryptedName,
                'plain_name': t.plainName,
                'version': t.version,
                'is_synced': t.isSynced,
              },)
          .toList(),
      'collections': collections
          .map((c) => {
                'id': c.id,
                'encrypted_title': c.encryptedTitle,
                'plain_title': c.plainTitle,
                'version': c.version,
                'is_synced': c.isSynced,
              },)
          .toList(),
      'contents': contents
          .map((c) => {
                'id': c.id,
                'encrypted_body': c.encryptedBody,
                'plain_body': c.plainBody,
                'platform_style': c.platformStyle,
                'ai_model_used': c.aiModelUsed,
                'version': c.version,
                'is_synced': c.isSynced,
              },)
          .toList(),
    };

    final jsonStr = jsonEncode(data);

    final backupKeyId = 'backup-${DateTime.now().millisecondsSinceEpoch}';
    final encrypted = await _crypto.encryptForItem(backupKeyId, jsonStr);

    final envelope = jsonEncode({
      'format': 'anynote-backup-v1',
      'backup_key_id': backupKeyId,
      'encrypted_data': encrypted,
    });

    return Uint8List.fromList(utf8.encode(envelope));
  }

  /// Import data from an encrypted backup file.
  /// Returns the number of items imported.
  /// Existing items are skipped (equivalent to [ConflictStrategy.skip]).
  Future<int> importBackup(Uint8List data) async {
    if (!_crypto.isUnlocked) {
      throw StateError('Crypto service must be unlocked to import backup');
    }

    final backupData = await _decryptBackup(data);
    var count = 0;

    for (final noteJson in (backupData['notes'] as List)) {
      final n = noteJson as Map<String, dynamic>;
      final existing = await _db.notesDao.getNoteById(n['id'] as String);
      if (existing == null) {
        await _db.notesDao.createNote(
          id: n['id'] as String,
          encryptedContent: n['encrypted_content'] as String,
          encryptedTitle: n['encrypted_title'] as String?,
          plainContent: n['plain_content'] as String?,
          plainTitle: n['plain_title'] as String?,
        );
        count++;
      }
    }

    for (final tagJson in (backupData['tags'] as List)) {
      final t = tagJson as Map<String, dynamic>;
      final existing = await _db.tagsDao.getAllTags();
      if (!existing.any((tag) => tag.id == (t['id'] as String))) {
        await _db.tagsDao.createTag(
          id: t['id'] as String,
          encryptedName: t['encrypted_name'] as String,
          plainName: t['plain_name'] as String?,
        );
        count++;
      }
    }

    for (final colJson in (backupData['collections'] as List)) {
      final c = colJson as Map<String, dynamic>;
      final existing = await _db.collectionsDao.getAllCollections();
      if (!existing.any((col) => col.id == (c['id'] as String))) {
        await _db.collectionsDao.createCollection(
          id: c['id'] as String,
          encryptedTitle: c['encrypted_title'] as String,
          plainTitle: c['plain_title'] as String?,
        );
        count++;
      }
    }

    for (final contentJson in (backupData['contents'] as List)) {
      final c = contentJson as Map<String, dynamic>;
      final existing = await _db.generatedContentsDao.getById(c['id'] as String);
      if (existing == null) {
        await _db.generatedContentsDao.create(
          id: c['id'] as String,
          encryptedBody: c['encrypted_body'] as String,
          plainBody: c['plain_body'] as String?,
          platformStyle: (c['platform_style'] as String?) ?? 'generic',
          aiModelUsed: (c['ai_model_used'] as String?) ?? '',
        );
        count++;
      }
    }

    return count;
  }

  /// Restore from an encrypted backup with conflict-strategy-aware handling.
  ///
  /// For each item in the backup:
  /// - If it does not exist locally, it is inserted normally.
  /// - If it already exists (same UUID), the [strategy] determines the action:
  ///   - [ConflictStrategy.skip]: keep the local version, skip the backup item.
  ///   - [ConflictStrategy.overwrite]: replace the local version with the backup.
  ///   - [ConflictStrategy.keepBoth]: keep the local version and insert the
  ///     backup item under a new UUID with " (restored)" appended to its title.
  ///
  /// [onProgress] is called after each item with a [RestoreProgress] update.
  Future<RestoreResult> restoreWithStrategy(
    Uint8List data, {
    required ConflictStrategy strategy,
    void Function(RestoreProgress)? onProgress,
  }) async {
    if (!_crypto.isUnlocked) {
      throw StateError('Crypto service must be unlocked to restore backup');
    }

    final backupData = await _decryptBackup(data);

    final notesList = (backupData['notes'] as List).cast<Map<String, dynamic>>();
    final tagsList = (backupData['tags'] as List).cast<Map<String, dynamic>>();
    final collectionsList =
        (backupData['collections'] as List).cast<Map<String, dynamic>>();
    final contentsList =
        (backupData['contents'] as List).cast<Map<String, dynamic>>();

    final totalItems =
        notesList.length + tagsList.length + collectionsList.length + contentsList.length;

    var restored = 0;
    var skipped = 0;
    var conflicts = 0;
    final errors = <String>[];
    var current = 0;

    // --- Notes ---
    for (final n in notesList) {
      try {
        final id = n['id'] as String;
        final existing = await _db.notesDao.getNoteById(id);

        if (existing == null) {
          await _db.notesDao.createNote(
            id: id,
            encryptedContent: n['encrypted_content'] as String,
            encryptedTitle: n['encrypted_title'] as String?,
            plainContent: n['plain_content'] as String?,
            plainTitle: n['plain_title'] as String?,
          );
          restored++;
        } else {
          conflicts++;
          switch (strategy) {
            case ConflictStrategy.skip:
              skipped++;
              break;
            case ConflictStrategy.overwrite:
              await _db.notesDao.updateNote(
                id: id,
                encryptedContent: n['encrypted_content'] as String?,
                encryptedTitle: n['encrypted_title'] as String?,
                plainContent: n['plain_content'] as String?,
                plainTitle: n['plain_title'] as String?,
              );
              restored++;
              break;
            case ConflictStrategy.keepBoth:
              final newId = _uuid.v4();
              final originalTitle = n['plain_title'] as String?;
              await _db.notesDao.createNote(
                id: newId,
                encryptedContent: n['encrypted_content'] as String,
                encryptedTitle: n['encrypted_title'] as String?,
                plainContent: n['plain_content'] as String?,
                plainTitle: originalTitle != null
                    ? '$originalTitle (restored)'
                    : null,
              );
              restored++;
              break;
          }
        }
      } catch (e) {
        errors.add('Note ${n['id']}: $e');
      }
      current++;
      onProgress?.call(RestoreProgress(
        current: current,
        total: totalItems,
        step: 'notes',
      ),);
    }

    // --- Tags ---
    for (final t in tagsList) {
      try {
        final id = t['id'] as String;
        final allTags = await _db.tagsDao.getAllTags();
        final existing = allTags.any((tag) => tag.id == id);

        if (!existing) {
          await _db.tagsDao.createTag(
            id: id,
            encryptedName: t['encrypted_name'] as String,
            plainName: t['plain_name'] as String?,
          );
          restored++;
        } else {
          conflicts++;
          switch (strategy) {
            case ConflictStrategy.skip:
              skipped++;
              break;
            case ConflictStrategy.overwrite:
              await _db.tagsDao.updateTag(
                id: id,
                encryptedName: t['encrypted_name'] as String?,
                plainName: t['plain_name'] as String?,
              );
              restored++;
              break;
            case ConflictStrategy.keepBoth:
              final newId = _uuid.v4();
              final originalName = t['plain_name'] as String?;
              await _db.tagsDao.createTag(
                id: newId,
                encryptedName: t['encrypted_name'] as String,
                plainName: originalName != null
                    ? '$originalName (restored)'
                    : null,
              );
              restored++;
              break;
          }
        }
      } catch (e) {
        errors.add('Tag ${t['id']}: $e');
      }
      current++;
      onProgress?.call(RestoreProgress(
        current: current,
        total: totalItems,
        step: 'tags',
      ),);
    }

    // --- Collections ---
    for (final c in collectionsList) {
      try {
        final id = c['id'] as String;
        final allCollections = await _db.collectionsDao.getAllCollections();
        final existing = allCollections.any((col) => col.id == id);

        if (!existing) {
          await _db.collectionsDao.createCollection(
            id: id,
            encryptedTitle: c['encrypted_title'] as String,
            plainTitle: c['plain_title'] as String?,
          );
          restored++;
        } else {
          conflicts++;
          switch (strategy) {
            case ConflictStrategy.skip:
              skipped++;
              break;
            case ConflictStrategy.overwrite:
              await _db.collectionsDao.updateCollection(
                id: id,
                encryptedTitle: c['encrypted_title'] as String?,
                plainTitle: c['plain_title'] as String?,
              );
              restored++;
              break;
            case ConflictStrategy.keepBoth:
              final newId = _uuid.v4();
              final originalTitle = c['plain_title'] as String?;
              await _db.collectionsDao.createCollection(
                id: newId,
                encryptedTitle: c['encrypted_title'] as String,
                plainTitle: originalTitle != null
                    ? '$originalTitle (restored)'
                    : null,
              );
              restored++;
              break;
          }
        }
      } catch (e) {
        errors.add('Collection ${c['id']}: $e');
      }
      current++;
      onProgress?.call(RestoreProgress(
        current: current,
        total: totalItems,
        step: 'collections',
      ),);
    }

    // --- Generated Contents ---
    for (final c in contentsList) {
      try {
        final id = c['id'] as String;
        final existing = await _db.generatedContentsDao.getById(id);

        if (existing == null) {
          await _db.generatedContentsDao.create(
            id: id,
            encryptedBody: c['encrypted_body'] as String,
            plainBody: c['plain_body'] as String?,
            platformStyle: (c['platform_style'] as String?) ?? 'generic',
            aiModelUsed: (c['ai_model_used'] as String?) ?? '',
          );
          restored++;
        } else {
          conflicts++;
          switch (strategy) {
            case ConflictStrategy.skip:
              skipped++;
              break;
            case ConflictStrategy.overwrite:
              await _db.generatedContentsDao.updateContent(
                id: id,
                encryptedBody: c['encrypted_body'] as String?,
                plainBody: c['plain_body'] as String?,
              );
              restored++;
              break;
            case ConflictStrategy.keepBoth:
              final newId = _uuid.v4();
              final originalBody = c['plain_body'] as String?;
              await _db.generatedContentsDao.create(
                id: newId,
                encryptedBody: c['encrypted_body'] as String,
                plainBody: originalBody != null
                    ? '$originalBody (restored)'
                    : null,
                platformStyle: (c['platform_style'] as String?) ?? 'generic',
                aiModelUsed: (c['ai_model_used'] as String?) ?? '',
              );
              restored++;
              break;
          }
        }
      } catch (e) {
        errors.add('Content ${c['id']}: $e');
      }
      current++;
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

  /// Decrypt and parse backup data, returning the inner JSON map.
  Future<Map<String, dynamic>> _decryptBackup(Uint8List data) async {
    final jsonStr = utf8.decode(data);
    final envelope = jsonDecode(jsonStr) as Map<String, dynamic>;

    final format = envelope['format'] as String?;
    if (format != 'anynote-backup-v1') {
      throw FormatException('Unsupported backup format: $format');
    }

    final backupKeyId = envelope['backup_key_id'] as String;
    final encryptedData = envelope['encrypted_data'] as String;

    final decrypted = await _crypto.decryptForItem(backupKeyId, encryptedData);
    if (decrypted == null) {
      throw StateError(
          'Failed to decrypt backup. The encryption keys may not match.',);
    }

    return jsonDecode(decrypted) as Map<String, dynamic>;
  }
}
