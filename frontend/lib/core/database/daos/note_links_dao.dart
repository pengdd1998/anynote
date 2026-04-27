import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'note_links_dao.g.dart';

/// Data Access Object for note link operations.
///
/// Provides CRUD operations for wiki-style [[note links]] with
/// local-only storage. Links are never synced to server.
@DriftAccessor(tables: [NoteLinks])
class NoteLinksDao extends DatabaseAccessor<AppDatabase>
    with _$NoteLinksDaoMixin {
  NoteLinksDao(super.db);

  /// Create a new note link.
  Future<void> createLink({
    required String id,
    required String sourceId,
    required String targetId,
    required String linkType,
  }) {
    return into(noteLinks).insert(
      NoteLinksCompanion.insert(
        id: id,
        sourceId: sourceId,
        targetId: targetId,
        linkType: Value(linkType),
      ),
    );
  }

  /// Get all outbound links from a note (links FROM this note).
  Future<List<NoteLink>> getOutboundLinks(String noteId) {
    return (select(noteLinks)..where((tbl) => tbl.sourceId.equals(noteId)))
        .get();
  }

  /// Get all inbound links to a note (links TO this note, backlinks).
  Future<List<NoteLink>> getBacklinks(String noteId) {
    return (select(noteLinks)..where((tbl) => tbl.targetId.equals(noteId)))
        .get();
  }

  /// Delete a specific link.
  Future<void> deleteLink(String sourceId, String targetId) {
    return (delete(noteLinks)
          ..where(
            (tbl) =>
                tbl.sourceId.equals(sourceId) & tbl.targetId.equals(targetId),
          ))
        .go();
  }

  /// Get all links (for graph visualization).
  Future<List<NoteLink>> getAllLinks() => select(noteLinks).get();

  /// Delete all links for a note (when note is deleted).
  Future<void> deleteLinksForNote(String noteId) {
    return (delete(noteLinks)
          ..where(
            (tbl) => tbl.sourceId.equals(noteId) | tbl.targetId.equals(noteId),
          ))
        .go();
  }
}
