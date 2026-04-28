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

  /// Note color as hex string (e.g. '#FF5722'). Nullable means no color set.
  /// Local-only, not synced to server.
  TextColumn get color => text().nullable()();

  /// Custom sort order for manual drag-and-drop reordering.
  /// Lower values appear first. Local-only, not synced to server.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tags table - stores encrypted tag names.
@TableIndex(name: 'idx_tags_is_synced', columns: {#isSynced})
@TableIndex(name: 'idx_tags_parent_id', columns: {#parentId})
class Tags extends Table {
  TextColumn get id => text()();

  /// Encrypted tag name (base64)
  TextColumn get encryptedName => text()();

  /// Decrypted name cache (local only)
  TextColumn get plainName => text().nullable()();

  /// Tag color as hex string (e.g. '#FF5722'). Nullable means no color set.
  /// Local-only, not synced to server.
  TextColumn get color => text().nullable()();

  /// Parent tag ID for hierarchical tags. Nullable means root-level tag.
  TextColumn get parentId =>
      text().nullable().withDefault(const Constant(null))();

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

/// Note links - bidirectional relationships between notes (wiki-style [[links]]).
/// Local-only data, never synced to server. The sourceId is the note containing
/// the [[link]], and targetId is the linked note.
@TableIndex(name: 'idx_note_links_source_id', columns: {#sourceId})
@TableIndex(name: 'idx_note_links_target_id', columns: {#targetId})
class NoteLinks extends Table {
  /// Client-generated UUID for the link itself
  TextColumn get id => text()();

  /// ID of the note containing the [[link]] (source)
  TextColumn get sourceId => text().references(Notes, #id)();

  /// ID of the linked note (target)
  TextColumn get targetId => text().references(Notes, #id)();

  /// Type of link: 'wiki' for [[syntax]] links
  TextColumn get linkType => text().withDefault(const Constant('wiki'))();

  /// Creation timestamp
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Note properties - custom key-value metadata for notes.
/// Supports multiple value types: text, number, date.
/// Local-only data, never synced to server (properties are user-specific views).
@TableIndex(name: 'idx_note_properties_note_id', columns: {#noteId})
@TableIndex(name: 'idx_note_properties_key', columns: {#key})
@TableIndex(name: 'idx_note_properties_note_id_key', columns: {#noteId, #key})
class NoteProperties extends Table {
  /// Client-generated UUID
  TextColumn get id => text()();

  /// Reference to the note this property belongs to
  TextColumn get noteId =>
      text().references(Notes, #id, onDelete: KeyAction.cascade)();

  /// Property key (e.g., 'status', 'priority', 'due_date')
  TextColumn get key => text()();

  /// Value type: 'text', 'number', 'date'
  TextColumn get valueType => text().withDefault(const Constant('text'))();

  /// Text value (used when valueType is 'text')
  TextColumn get valueText => text().nullable()();

  /// Number value (used when valueType is 'number')
  RealColumn get valueNumber => real().nullable()();

  /// Date value (used when valueType is 'date')
  DateTimeColumn get valueDate => dateTime().nullable()();

  /// Creation timestamp
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Last update timestamp
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Collections (notebooks/folders) - stores encrypted titles.
@TableIndex(name: 'idx_collections_is_synced', columns: {#isSynced})
class Collections extends Table {
  TextColumn get id => text()();

  /// Encrypted collection title
  TextColumn get encryptedTitle => text()();

  /// Decrypted title cache
  TextColumn get plainTitle => text().nullable()();

  /// Collection color as hex string (e.g. '#FF5722'). Nullable means no color set.
  /// Local-only, not synced to server.
  TextColumn get color => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(0))();

  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Many-to-many relationship between collections and notes.
@TableIndex(
  name: 'idx_collection_notes_collection_id',
  columns: {#collectionId},
)
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
  TextColumn get platformStyle =>
      text().withDefault(const Constant('generic'))();

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

  /// What this template is for (nullable, for display in the picker)
  TextColumn get description => text().nullable()();

  /// Encrypted template content blob (base64 encoded)
  TextColumn get encryptedContent => text()();

  /// Decrypted content cache (local only, never synced)
  TextColumn get plainContent => text().nullable()();

  /// Grouping category: 'work', 'personal', 'creative', or 'custom'.
  /// Built-in templates are pre-assigned; user templates default to 'custom'.
  TextColumn get category => text().withDefault(const Constant('custom'))();

  /// Whether this is a built-in template that cannot be edited/deleted
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();

  /// How many times this template has been used to create a note
  IntColumn get usageCount => integer().withDefault(const Constant(0))();

  /// Creation timestamp
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Last update timestamp
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

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
  TextColumn get status => text().withDefault(
        const Constant(
          'pending',
        ),
      )(); // 'pending', 'in_progress', 'failed', 'completed'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Collaboration state persistence - stores serialized CRDT document state
/// per note so that offline edits are preserved and can be resumed.
@TableIndex(name: 'idx_collab_states_note_id', columns: {#noteId})
class CollabStates extends Table {
  /// Auto-incrementing primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Reference to the note this collab state belongs to.
  TextColumn get noteId => text().references(Notes, #id)();

  /// Serialized CRDT document state (JSON).
  TextColumn get documentState => text()();

  /// Last known Lamport clock value for incremental sync.
  IntColumn get lastVersion => integer().withDefault(const Constant(0))();

  /// When this state was last updated.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Code snippets - reusable code fragments organized by language and category.
/// Local-only data, never synced to server.
@DataClassName('Snippet')
@TableIndex(name: 'idx_snippets_language', columns: {#language})
@TableIndex(name: 'idx_snippets_category', columns: {#category})
class Snippets extends Table {
  /// Client-generated UUID.
  TextColumn get id => text()();

  /// Snippet title / display name.
  TextColumn get title => text()();

  /// Raw code content.
  TextColumn get code => text()();

  /// Programming language (e.g. 'Dart', 'Python'). Empty string if unset.
  TextColumn get language => text().withDefault(const Constant(''))();

  /// Optional human-readable description.
  TextColumn get description => text().withDefault(const Constant(''))();

  /// Optional grouping category.
  TextColumn get category => text().withDefault(const Constant(''))();

  /// Comma-separated tag list for search/filter.
  TextColumn get tags => text().withDefault(const Constant(''))();

  /// How many times this snippet has been inserted into a note.
  IntColumn get usageCount => integer().withDefault(const Constant(0))();

  /// Creation timestamp.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Last update timestamp.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Saved searches - named search queries that users can save and reuse.
/// Local-only data, never synced to server.
@DataClassName('SavedSearch')
class SavedSearches extends Table {
  /// Client-generated UUID.
  TextColumn get id => text()();

  /// User-visible name for this saved search.
  TextColumn get name => text()();

  /// Raw query string (may contain search operators like tag:xxx, status:xxx).
  TextColumn get query => text()();

  /// Creation timestamp.
  DateTimeColumn get createdAt => dateTime()();

  /// Last update timestamp.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Note images - metadata for images attached to notes.
/// Tracks file path, dimensions, hash, and sync status for each image.
@TableIndex(name: 'idx_note_images_note_id', columns: {#noteId})
@TableIndex(name: 'idx_note_images_is_synced', columns: {#isSynced})
class NoteImages extends Table {
  /// Client-generated UUID.
  TextColumn get id => text()();

  /// Reference to the note this image belongs to.
  TextColumn get noteId => text().withDefault(const Constant(''))();

  /// Local filesystem path to the image file.
  TextColumn get path => text()();

  /// MD5 hash of the original image bytes (for deduplication).
  TextColumn get hash => text()();

  /// File size in bytes after compression.
  IntColumn get fileSize => integer().withDefault(const Constant(0))();

  /// Image width in pixels.
  IntColumn get width => integer().withDefault(const Constant(0))();

  /// Image height in pixels.
  IntColumn get height => integer().withDefault(const Constant(0))();

  /// Whether this image has been synced to the server.
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  /// Creation timestamp.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
