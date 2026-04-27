import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'templates_dao.g.dart';

@DriftAccessor(tables: [NoteTemplates])
class TemplatesDao extends DatabaseAccessor<AppDatabase>
    with _$TemplatesDaoMixin {
  TemplatesDao(super.db);

  /// Create a new template.
  Future<String> createTemplate({
    required String id,
    required String name,
    required String encryptedContent,
    String? description,
    String? plainContent,
    String category = 'custom',
    bool isBuiltIn = false,
  }) async {
    await into(noteTemplates).insert(
      NoteTemplatesCompanion.insert(
        id: id,
        name: name,
        description: Value(description),
        encryptedContent: encryptedContent,
        plainContent: Value(plainContent),
        category: Value(category),
        isBuiltIn: Value(isBuiltIn),
      ),
    );
    return id;
  }

  /// Get all templates ordered by usage count descending.
  Future<List<NoteTemplate>> getAllTemplates() {
    return (select(noteTemplates)
          ..orderBy([
            (t) => OrderingTerm.desc(t.isBuiltIn),
            (t) => OrderingTerm.desc(t.usageCount),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .get();
  }

  /// Watch all templates (reactive).
  Stream<List<NoteTemplate>> watchAllTemplates() {
    return (select(noteTemplates)
          ..orderBy([
            (t) => OrderingTerm.desc(t.isBuiltIn),
            (t) => OrderingTerm.desc(t.usageCount),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .watch();
  }

  /// Get templates filtered by category.
  Future<List<NoteTemplate>> getTemplatesByCategory(String category) {
    return (select(noteTemplates)
          ..where((t) => t.category.equals(category))
          ..orderBy([
            (t) => OrderingTerm.desc(t.usageCount),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .get();
  }

  /// Get only built-in templates.
  Future<List<NoteTemplate>> getBuiltInTemplates() {
    return (select(noteTemplates)
          ..where((t) => t.isBuiltIn.equals(true))
          ..orderBy([
            (t) => OrderingTerm.asc(t.name),
          ]))
        .get();
  }

  /// Get only user-created templates.
  Future<List<NoteTemplate>> getUserTemplates() {
    return (select(noteTemplates)
          ..where((t) => t.isBuiltIn.equals(false))
          ..orderBy([
            (t) => OrderingTerm.desc(t.usageCount),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .get();
  }

  /// Get a single template by ID.
  Future<NoteTemplate?> getTemplateById(String id) {
    return (select(noteTemplates)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Update an existing template.
  Future<void> updateTemplate({
    required String id,
    String? name,
    String? description,
    String? encryptedContent,
    String? plainContent,
    String? category,
  }) async {
    await (update(noteTemplates)..where((t) => t.id.equals(id))).write(
      NoteTemplatesCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        description:
            description != null ? Value(description) : const Value.absent(),
        encryptedContent: encryptedContent != null
            ? Value(encryptedContent)
            : const Value.absent(),
        plainContent: Value(plainContent),
        category: category != null ? Value(category) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Delete a template by ID.
  Future<void> deleteTemplate(String id) async {
    await (delete(noteTemplates)..where((t) => t.id.equals(id))).go();
  }

  /// Increment the usage count for a template by 1.
  Future<void> incrementUsageCount(String id) async {
    final template = await getTemplateById(id);
    if (template == null) return;
    await (update(noteTemplates)..where((t) => t.id.equals(id))).write(
      NoteTemplatesCompanion(
        usageCount: Value(template.usageCount + 1),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Count total templates.
  Future<int> countTemplates() {
    final countExpr = noteTemplates.id.count();
    final query = selectOnly(noteTemplates)..addColumns([countExpr]);
    // ignore: unnecessary_non_null_assertion
    return query.map((row) => row.read(countExpr)!).getSingle();
  }

  /// Search templates by name or description.
  Future<List<NoteTemplate>> searchTemplates(String query) {
    final lowerQuery = query.toLowerCase();
    return (select(noteTemplates)
          ..where(
            (t) =>
                t.name.lower().contains(lowerQuery) |
                t.description.lower().contains(lowerQuery),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.usageCount),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .get();
  }
}
