import 'package:drift/drift.dart';

/// Notes table - stores encrypted note content with plaintext cache.
/// Encrypted fields are synced to server; plain fields exist only locally.
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

  /// Decrypted content cache (local only, never synced)
  TextColumn get plainContent => text().nullable()();

  /// Decrypted title cache (local only, never synced)
  TextColumn get plainTitle => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tags table - stores encrypted tag names.
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
class NoteTags extends Table {
  TextColumn get noteId => text().references(Notes, #id)();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {noteId, tagId};
}

/// Collections (notebooks/folders) - stores encrypted titles.
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

/// Sync metadata - tracks sync state per item type.
class SyncMeta extends Table {
  TextColumn get itemType => text()();
  IntColumn get lastSyncedVersion => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {itemType};
}
