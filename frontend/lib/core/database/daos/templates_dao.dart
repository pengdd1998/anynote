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
    String? plainContent,
    String category = 'custom',
    bool isBuiltIn = false,
  }) async {
    await into(noteTemplates).insert(NoteTemplatesCompanion.insert(
      id: id,
      name: name,
      encryptedContent: encryptedContent,
      plainContent: Value(plainContent),
      category: Value(category),
      isBuiltIn: Value(isBuiltIn),
    ));
    return id;
  }

  /// Get all templates, ordered by built-in first then by name.
  Future<List<NoteTemplate>> getAllTemplates() {
    return (select(noteTemplates)
          ..orderBy([
            (t) => OrderingTerm.desc(t.isBuiltIn),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .get();
  }

  /// Watch all templates (reactive).
  Stream<List<NoteTemplate>> watchAllTemplates() {
    return (select(noteTemplates)
          ..orderBy([
            (t) => OrderingTerm.desc(t.isBuiltIn),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .watch();
  }

  /// Get a single template by ID.
  Future<NoteTemplate> getTemplateById(String id) {
    return (select(noteTemplates)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  /// Delete a template by ID.
  Future<void> deleteTemplate(String id) async {
    await (delete(noteTemplates)..where((t) => t.id.equals(id))).go();
  }

  /// Update an existing template.
  Future<void> updateTemplate({
    required String id,
    String? name,
    String? encryptedContent,
    String? plainContent,
  }) async {
    await (update(noteTemplates)..where((t) => t.id.equals(id)))
        .write(NoteTemplatesCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      encryptedContent: encryptedContent != null
          ? Value(encryptedContent)
          : const Value.absent(),
      plainContent: Value(plainContent),
    ));
  }

  /// Count total templates.
  Future<int> countTemplates() {
    final countExpr = noteTemplates.id.count();
    final query = selectOnly(noteTemplates)..addColumns([countExpr]);
    // ignore: unnecessary_non_null_assertion
    return query.map((row) => row.read(countExpr)!).getSingle();
  }

  /// Get only built-in templates.
  Future<List<NoteTemplate>> getBuiltInTemplates() {
    return (select(noteTemplates)..where((t) => t.isBuiltIn.equals(true)))
        .get();
  }

  /// Get only custom templates.
  Future<List<NoteTemplate>> getCustomTemplates() {
    return (select(noteTemplates)..where((t) => t.isBuiltIn.equals(false)))
        .get();
  }
}
