import 'dart:convert';
import 'dart:io' if (dart.library.js) 'package:anynote/core/stubs/io_stub.dart';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

import '../crypto/crypto_service.dart';

/// Metadata about a backup file after verification.
class BackupInfo {
  /// Format string from the envelope (e.g. 'anynote-backup-v1').
  final String format;

  /// Backup key ID used for encryption.
  final String backupKeyId;

  /// Total number of items in the backup.
  final int totalItems;

  /// Number of notes.
  final int noteCount;

  /// Number of tags.
  final int tagCount;

  /// Number of collections.
  final int collectionCount;

  /// Number of AI-generated content items.
  final int contentCount;

  /// Export timestamp from the backup data (null if not decrypted).
  final String? exportedAt;

  /// Backup format version number from the inner JSON.
  final int version;

  /// Whether the backup could be fully decrypted with the current key.
  final bool canDecrypt;

  /// Validation errors found during verification.
  final List<String> errors;

  const BackupInfo({
    required this.format,
    required this.backupKeyId,
    this.totalItems = 0,
    this.noteCount = 0,
    this.tagCount = 0,
    this.collectionCount = 0,
    this.contentCount = 0,
    this.exportedAt,
    this.version = 0,
    this.canDecrypt = false,
    this.errors = const [],
  });

  /// Whether the backup file is structurally valid.
  bool get isValid => errors.isEmpty;

  /// Whether the backup has any items.
  bool get hasItems => totalItems > 0;
}

/// Preview of items in a decrypted backup for user review before restore.
class RestorePreview {
  /// Note titles (decrypted if key available, otherwise encrypted placeholder).
  final List<String> noteTitles;

  /// Earliest creation date among backup notes.
  final DateTime? earliestDate;

  /// Latest creation date among backup notes.
  final DateTime? latestDate;

  /// Number of notes.
  final int noteCount;

  /// Number of tags.
  final int tagCount;

  /// Number of collections.
  final int collectionCount;

  /// Number of AI-generated content items.
  final int contentCount;

  /// Number of notes that already exist locally (by UUID match).
  final int existingNoteCount;

  /// Number of tags that already exist locally.
  final int existingTagCount;

  /// Number of collections that already exist locally.
  final int existingCollectionCount;

  /// Number of content items that already exist locally.
  final int existingContentCount;

  const RestorePreview({
    this.noteTitles = const [],
    this.earliestDate,
    this.latestDate,
    this.noteCount = 0,
    this.tagCount = 0,
    this.collectionCount = 0,
    this.contentCount = 0,
    this.existingNoteCount = 0,
    this.existingTagCount = 0,
    this.existingCollectionCount = 0,
    this.existingContentCount = 0,
  });

  /// Total items that would conflict with local data.
  int get totalConflicts =>
      existingNoteCount +
      existingTagCount +
      existingCollectionCount +
      existingContentCount;

  /// Whether there are any conflicts.
  bool get hasConflicts => totalConflicts > 0;
}

/// Validates backup file format and integrity, and provides previews of
/// backup content for user review before restoring.
class BackupVerifier {
  final CryptoService _crypto;

  BackupVerifier(this._crypto);

  /// Validate the backup file format and integrity without requiring decryption.
  ///
  /// Checks:
  /// - File exists and is non-empty
  /// - JSON envelope is valid
  /// - Format header is recognized ('anynote-backup-v1')
  /// - Required fields are present (backup_key_id, encrypted_data)
  /// - If [CryptoService] is unlocked, attempts decryption to count items
  ///
  /// On web, use [verifyContent] instead which accepts a string content.
  Future<BackupInfo> verify(String backupPath) async {
    if (kIsWeb) {
      return const BackupInfo(
        format: '',
        backupKeyId: '',
        errors: [
          'Backup verification from file path is not supported on web. '
              'Use verifyContent() with the file content instead.'
        ],
      );
    }

    final _ = <String>[];

    // 1. File existence and size check.
    final file = File(backupPath);
    if (!await file.exists()) {
      return const BackupInfo(
        format: '',
        backupKeyId: '',
        errors: ['Backup file not found'],
      );
    }

    final fileSize = await file.length();
    if (fileSize == 0) {
      return const BackupInfo(
        format: '',
        backupKeyId: '',
        errors: ['Backup file is empty'],
      );
    }

    // 2. Parse JSON envelope.
    final jsonStr = await file.readAsString();
    return _verifyEnvelope(jsonStr);
  }

  /// Validate backup content provided as a JSON string.
  ///
  /// Web-compatible alternative to [verify] that accepts the backup content
  /// directly instead of a file path. On web, the caller is responsible for
  /// reading the file (e.g. via the File API or a file picker).
  Future<BackupInfo> verifyContent(String jsonContent) async {
    return _verifyEnvelope(jsonContent);
  }

  /// Internal verification logic operating on the JSON envelope string.
  Future<BackupInfo> _verifyEnvelope(String jsonStr) async {
    final errors = <String>[];

    // Parse JSON envelope.
    Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      return BackupInfo(
        format: '',
        backupKeyId: '',
        errors: ['Invalid backup file format: ${e.toString()}'],
      );
    }

    // Check format header.
    final format = envelope['format'] as String? ?? '';
    if (format != 'anynote-backup-v1') {
      return BackupInfo(
        format: format,
        backupKeyId: '',
        errors: ['Unsupported backup format: $format'],
      );
    }

    // Check required fields.
    final backupKeyId = envelope['backup_key_id'] as String? ?? '';
    final encryptedData = envelope['encrypted_data'] as String? ?? '';

    if (backupKeyId.isEmpty) {
      errors.add('Missing backup_key_id in backup envelope');
    }
    if (encryptedData.isEmpty) {
      errors.add('Missing encrypted_data in backup envelope');
    }

    if (errors.isNotEmpty) {
      return BackupInfo(
        format: format,
        backupKeyId: backupKeyId,
        errors: errors,
      );
    }

    // Attempt decryption to validate inner structure and count items.
    bool canDecrypt = false;
    int noteCount = 0;
    int tagCount = 0;
    int collectionCount = 0;
    int contentCount = 0;
    String? exportedAt;
    int version = 0;

    if (_crypto.isUnlocked) {
      try {
        final decrypted =
            await _crypto.decryptForItem(backupKeyId, encryptedData);
        if (decrypted != null) {
          canDecrypt = true;
          final backupData = jsonDecode(decrypted) as Map<String, dynamic>;

          version = backupData['version'] as int? ?? 0;
          exportedAt = backupData['exported_at'] as String?;

          noteCount = (backupData['notes'] as List?)?.length ?? 0;
          tagCount = (backupData['tags'] as List?)?.length ?? 0;
          collectionCount = (backupData['collections'] as List?)?.length ?? 0;
          contentCount = (backupData['contents'] as List?)?.length ?? 0;
        } else {
          errors.add('Decryption failed: returned null. '
              'The encryption key may not match the backup.');
        }
      } catch (e) {
        errors.add('Decryption failed: ${e.toString()}');
      }
    } else {
      // Cannot verify inner contents without encryption key.
      errors
          .add('Encryption keys not unlocked. Cannot verify backup contents.');
    }

    return BackupInfo(
      format: format,
      backupKeyId: backupKeyId,
      totalItems: noteCount + tagCount + collectionCount + contentCount,
      noteCount: noteCount,
      tagCount: tagCount,
      collectionCount: collectionCount,
      contentCount: contentCount,
      exportedAt: exportedAt,
      version: version,
      canDecrypt: canDecrypt,
      errors: errors,
    );
  }

  /// Preview what will be restored from a backup file.
  ///
  /// Requires [CryptoService] to be unlocked. Decrypts the backup, lists
  /// note titles, computes date ranges, and counts items by type. Also
  /// checks against [existingNoteIds], [existingTagIds], [existingCollectionIds],
  /// and [existingContentIds] to count conflicts.
  ///
  /// On web, use [previewContent] instead which accepts a string content.
  Future<RestorePreview> preview(
    String backupPath,
    Set<String> existingNoteIds,
    Set<String> existingTagIds,
    Set<String> existingCollectionIds,
    Set<String> existingContentIds,
  ) async {
    if (kIsWeb) {
      return const RestorePreview();
    }

    if (!_crypto.isUnlocked) {
      throw StateError('Crypto service must be unlocked to preview backup');
    }

    final file = File(backupPath);
    final jsonStr = await file.readAsString();
    return _previewEnvelope(
      jsonStr,
      existingNoteIds,
      existingTagIds,
      existingCollectionIds,
      existingContentIds,
    );
  }

  /// Preview backup content provided as a JSON string.
  ///
  /// Web-compatible alternative to [preview] that accepts the backup content
  /// directly instead of a file path.
  Future<RestorePreview> previewContent(
    String jsonContent,
    Set<String> existingNoteIds,
    Set<String> existingTagIds,
    Set<String> existingCollectionIds,
    Set<String> existingContentIds,
  ) async {
    return _previewEnvelope(
      jsonContent,
      existingNoteIds,
      existingTagIds,
      existingCollectionIds,
      existingContentIds,
    );
  }

  /// Internal preview logic operating on the JSON envelope string.
  Future<RestorePreview> _previewEnvelope(
    String jsonStr,
    Set<String> existingNoteIds,
    Set<String> existingTagIds,
    Set<String> existingCollectionIds,
    Set<String> existingContentIds,
  ) async {
    if (!_crypto.isUnlocked) {
      throw StateError('Crypto service must be unlocked to preview backup');
    }

    final envelope = jsonDecode(jsonStr) as Map<String, dynamic>;

    final backupKeyId = envelope['backup_key_id'] as String;
    final encryptedData = envelope['encrypted_data'] as String;

    final decrypted = await _crypto.decryptForItem(backupKeyId, encryptedData);
    if (decrypted == null) {
      throw StateError('Failed to decrypt backup for preview');
    }

    final backupData = jsonDecode(decrypted) as Map<String, dynamic>;

    final notes = (backupData['notes'] as List?) ?? [];
    final tags = (backupData['tags'] as List?) ?? [];
    final collections = (backupData['collections'] as List?) ?? [];
    final contents = (backupData['contents'] as List?) ?? [];

    // Extract note titles for preview.
    final noteTitles = <String>[];
    DateTime? earliestDate;
    DateTime? latestDate;

    for (final noteJson in notes) {
      final n = noteJson as Map<String, dynamic>;

      // Prefer plain_title, fall back to encrypted placeholder.
      final title = (n['plain_title'] as String?) ?? '(encrypted)';
      noteTitles.add(title);

      final createdAt = n['created_at'] as String?;
      if (createdAt != null) {
        try {
          final dt = DateTime.parse(createdAt);
          if (earliestDate == null || dt.isBefore(earliestDate)) {
            earliestDate = dt;
          }
          if (latestDate == null || dt.isAfter(latestDate)) {
            latestDate = dt;
          }
        } catch (e) {
          // Skip unparseable dates.
          debugPrint(
              '[BackupVerifier] skipped unparseable date "$createdAt": $e',);
        }
      }
    }

    // Count existing (conflicting) items.
    var existingNoteCount = 0;
    for (final n in notes) {
      if (existingNoteIds.contains((n as Map<String, dynamic>)['id'])) {
        existingNoteCount++;
      }
    }

    var existingTagCount = 0;
    for (final t in tags) {
      if (existingTagIds.contains((t as Map<String, dynamic>)['id'])) {
        existingTagCount++;
      }
    }

    var existingCollectionCount = 0;
    for (final c in collections) {
      if (existingCollectionIds.contains((c as Map<String, dynamic>)['id'])) {
        existingCollectionCount++;
      }
    }

    var existingContentCount = 0;
    for (final c in contents) {
      if (existingContentIds.contains((c as Map<String, dynamic>)['id'])) {
        existingContentCount++;
      }
    }

    return RestorePreview(
      noteTitles: noteTitles,
      earliestDate: earliestDate,
      latestDate: latestDate,
      noteCount: notes.length,
      tagCount: tags.length,
      collectionCount: collections.length,
      contentCount: contents.length,
      existingNoteCount: existingNoteCount,
      existingTagCount: existingTagCount,
      existingCollectionCount: existingCollectionCount,
      existingContentCount: existingContentCount,
    );
  }
}
