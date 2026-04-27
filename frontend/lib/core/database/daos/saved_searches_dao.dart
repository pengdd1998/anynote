import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';
import '../tables.dart';

part 'saved_searches_dao.g.dart';

/// Data Access Object for saved searches.
///
/// Provides CRUD operations for named search queries that users can save
/// and reuse. All data is local-only and never synced.
@DriftAccessor(tables: [SavedSearches])
class SavedSearchesDao extends DatabaseAccessor<AppDatabase>
    with _$SavedSearchesDaoMixin {
  SavedSearchesDao(super.db);

  /// Get all saved searches, ordered by most recently updated first.
  Future<List<SavedSearch>> getAll() {
    return (select(savedSearches)
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .get();
  }

  /// Watch all saved searches (reactive stream).
  Stream<List<SavedSearch>> watchAll() {
    return (select(savedSearches)
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .watch();
  }

  /// Get a single saved search by ID.
  Future<SavedSearch?> getById(String id) {
    return (select(savedSearches)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  /// Create a new saved search. Returns the generated ID.
  Future<String> create({
    required String name,
    required String query,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    await into(savedSearches).insert(
      SavedSearchesCompanion.insert(
        id: id,
        name: name,
        query: query,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  /// Update an existing saved search.
  Future<void> updateSearch({
    required String id,
    String? name,
    String? query,
  }) {
    return (update(savedSearches)..where((tbl) => tbl.id.equals(id))).write(
      SavedSearchesCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        query: query != null ? Value(query) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Delete a saved search by ID.
  Future<void> deleteSearch(String id) {
    return (delete(savedSearches)..where((tbl) => tbl.id.equals(id))).go();
  }
}
