import 'package:drift/drift.dart';

/// Notes table - stores encrypted note content with plaintext cache.
/// Encrypted fields are synced to server; plain fields exist only locally.
@TableIndex(name: 'idx_notes_deleted_at', columns: {#deletedAt})
@TableIndex(name: 'idx_notes_created_at', columns: {#createdAt})
@TableIndex(name: 'idx_notes_updated_at', columns: {#updatedAt})
@TableIndex(name: 'idx_notes_is_pinned', columns: {#isPinned})
@TableIndex(name: 'idx_notes_is_synced', columns: {#isSynced})
class Notes extends Table {
  /// Client-generated UUID
  TextColumn get id => text()();

  /// Encrypted note content blob (base64 encoded)
  TextColumn get encryptedContent => text()();

  /// Encrypted note title (base64, nullable)
  TextColumn get encryptedTitle => text().nullable()();

  /// Version number for sync (incremental)
  IntColumn get version => integer().withDefault(const Constant(0))();

  /// Creation timestamp
  DateTimeColumn get createdAt => dateTime()();

  /// Last update timestamp
  DateTimeColumn get updatedAt => dateTime()();

  /// Soft delete timestamp
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Whether this note is synced to server
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  /// Whether this note is pinned (local only)
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  /// Decrypted content cache (local only, never synced)
  TextColumn get plainContent => text().nullable()();

  /// Decrypted title cache (local only, never synced)
  TextColumn get plainTitle => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tags table - stores encrypted tag names.
@TableIndex(name: 'idx_tags_is_synced', columns: {#isSynced})
class Tags extends Table {
  TextColumn get id => text()();

  /// Encrypted tag name (base64)
  TextColumn get encryptedName => text()();

  /// Decrypted name cache (local only)
  TextColumn get plainName => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(0))();

  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Many-to-many relationship between notes and tags.
@TableIndex(name: 'idx_note_tags_tag_id', columns: {#tagId})
@TableIndex(name: 'idx_note_tags_note_id', columns: {#noteId})
class NoteTags extends Table {
  TextColumn get noteId => text().references(Notes, #id)();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {noteId, tagId};
}

/// Collections (notebooks/folders) - stores encrypted titles.
@TableIndex(name: 'idx_collections_is_synced', columns: {#isSynced})
class Collections extends Table {
  TextColumn get id => text()();

  /// Encrypted collection title
  TextColumn get encryptedTitle => text()();

  /// Decrypted title cache
  TextColumn get plainTitle => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(0))();

  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Many-to-many relationship between collections and notes.
@TableIndex(name: 'idx_collection_notes_collection_id', columns: {#collectionId})
@TableIndex(name: 'idx_collection_notes_note_id', columns: {#noteId})
class CollectionNotes extends Table {
  TextColumn get collectionId => text().references(Collections, #id)();
  TextColumn get noteId => text().references(Notes, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {collectionId, noteId};
}

/// AI-generated content (outlines, drafts, etc.) stored encrypted.
class GeneratedContents extends Table {
  TextColumn get id => text()();

  /// Encrypted content body
  TextColumn get encryptedBody => text()();

  /// Decrypted body cache
  TextColumn get plainBody => text().nullable()();

  /// Target platform style (not encrypted - will be published publicly)
  TextColumn get platformStyle => text().withDefault(const Constant('generic'))();

  /// AI model used to generate this content
  TextColumn get aiModelUsed => text().withDefault(const Constant(''))();

  IntColumn get version => integer().withDefault(const Constant(0))();

  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// FTS5 virtual table for full-text search on decrypted content.
/// Populated after decryption; searched locally without network.
class NotesFts extends Table {
  TextColumn get noteId => text()();
  TextColumn get content => text()();
  TextColumn get title => text().nullable()();

  @override
  Set<Column> get primaryKey => {noteId};
}

/// Note version history - stores encrypted snapshots of note content at each save.
@TableIndex(name: 'idx_note_versions_note_id', columns: {#noteId})
class NoteVersions extends Table {
  /// Client-generated UUID
  TextColumn get id => text()();

  /// Reference to the parent note
  TextColumn get noteId => text().references(Notes, #id)();

  /// Encrypted note title snapshot (base64, nullable)
  TextColumn get encryptedTitle => text().nullable()();

  /// Decrypted title cache (local only)
  TextColumn get plainTitle => text().nullable()();

  /// Encrypted note content snapshot (base64)
  TextColumn get encryptedContent => text()();

  /// Decrypted content cache (local only)
  TextColumn get plainContent => text().nullable()();

  /// Monotonically increasing version number per note
  IntColumn get versionNumber => integer()();

  /// When this version was created
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Note templates - stores reusable note templates.
/// Built-in templates are seeded on first run and cannot be deleted.
/// Custom templates are user-created and encrypted for sync.
class NoteTemplates extends Table {
  /// Client-generated UUID
  TextColumn get id => text()();

  /// Template display name (stored encrypted for custom templates)
  TextColumn get name => text()();

  /// Encrypted template content blob (base64 encoded)
  TextColumn get encryptedContent => text()();

  /// Decrypted content cache (local only, never synced)
  TextColumn get plainContent => text().nullable()();

  /// Category: 'built_in' or 'custom'
  TextColumn get category => text().withDefault(const Constant('custom'))();

  /// Whether this is a built-in template that cannot be edited/deleted
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();

  /// Creation timestamp
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Sync metadata - tracks sync state per item type.
class SyncMeta extends Table {
  TextColumn get itemType => text()();
  IntColumn get lastSyncedVersion => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {itemType};
}

/// Sync operations queue - tracks pending create/update/delete operations
/// for reliable offline-first sync with exponential backoff retry.
@TableIndex(name: 'idx_sync_ops_status', columns: {#status})
@TableIndex(name: 'idx_sync_ops_item', columns: {#itemId})
class SyncOperations extends Table {
  TextColumn get id => text()();
  TextColumn get operationType => text()(); // 'create', 'update', 'delete'
  TextColumn get itemType => text()(); // 'note', 'tag', 'collection', 'content'
  TextColumn get itemId => text()();
  TextColumn get payload => text()(); // JSON payload
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  IntColumn get maxRetries => integer().withDefault(const Constant(5))();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // 'pending', 'in_progress', 'failed', 'completed'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
