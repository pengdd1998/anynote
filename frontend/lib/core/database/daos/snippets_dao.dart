import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'snippets_dao.g.dart';

@DriftAccessor(tables: [Snippets])
class SnippetsDao extends DatabaseAccessor<AppDatabase>
    with _$SnippetsDaoMixin {
  SnippetsDao(super.db);

  /// Watch all snippets ordered by most recently updated.
  Stream<List<Snippet>> watchAllSnippets() {
    return (select(snippets)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  /// Get a single snippet by its ID.
  Future<Snippet?> getSnippetById(String id) {
    return (select(snippets)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Search snippets by title, language, category, or tags.
  Future<List<Snippet>> searchSnippets(String query) {
    final lowerQuery = '%${query.toLowerCase()}%';
    return (select(snippets)
          ..where(
            (t) =>
                t.title.lower().like(lowerQuery) |
                t.language.lower().like(lowerQuery) |
                t.category.lower().like(lowerQuery) |
                t.tags.lower().like(lowerQuery),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// Filter snippets by category.
  Future<List<Snippet>> getSnippetsByCategory(String category) {
    return (select(snippets)
          ..where((t) => t.category.equals(category))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// Filter snippets by language.
  Future<List<Snippet>> getSnippetsByLanguage(String language) {
    return (select(snippets)
          ..where((t) => t.language.equals(language))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// Insert a new snippet.
  Future<void> insertSnippet(SnippetsCompanion snippet) async {
    await into(snippets).insert(snippet);
  }

  /// Update an existing snippet.
  Future<void> updateSnippet(SnippetsCompanion snippet) async {
    await (update(snippets)..where((t) => t.id.equals(snippet.id.value)))
        .write(snippet);
  }

  /// Delete a snippet by ID.
  Future<void> deleteSnippet(String id) async {
    await (delete(snippets)..where((t) => t.id.equals(id))).go();
  }

  /// Increment the usage count for a snippet.
  Future<void> incrementUsageCount(String id) async {
    await (update(snippets)..where((t) => t.id.equals(id))).write(
      const SnippetsCompanion(
        usageCount: Value.absent(),
      ),
    );
    // Use a raw increment to avoid read-modify-write races.
    await customStatement(
      'UPDATE snippets SET usage_count = usage_count + 1, updated_at = updated_at WHERE id = ?',
      [id],
    );
  }

  /// Get all distinct categories (non-empty) ordered alphabetically.
  Future<List<String>> getAllCategories() async {
    final rows = await customSelect(
      'SELECT DISTINCT category FROM snippets WHERE category != \'\' ORDER BY category',
      readsFrom: {snippets},
    ).get();
    return rows.map((row) => row.read<String>('category')).toList();
  }

  /// Get all distinct languages (non-empty) ordered alphabetically.
  Future<List<String>> getAllLanguages() async {
    final rows = await customSelect(
      'SELECT DISTINCT language FROM snippets WHERE language != \'\' ORDER BY language',
      readsFrom: {snippets},
    ).get();
    return rows.map((row) => row.read<String>('language')).toList();
  }
}
