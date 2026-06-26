import 'package:drift/drift.dart';

import '../tables.dart';
import '../app_database.dart';

part 'post_template_dao.g.dart';

/// Data access for the `post_templates` table.
///
/// Returns Drift-generated [PostTemplateRow] objects. Callers convert to the
/// domain [PostTemplate] model (see `features/compose/domain/post_template.dart`)
/// when they need the helper methods (`promptFragment`, etc.).
@DriftAccessor(tables: [PostTemplates])
class PostTemplateDao extends DatabaseAccessor<AppDatabase>
    with _$PostTemplateDaoMixin {
  PostTemplateDao(super.db);

  /// Watch all templates (built-in + user-created), ordered oldest-first.
  Stream<List<PostTemplateRow>> watchAll() =>
      (select(postTemplates)
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  /// Get all templates once.
  Future<List<PostTemplateRow>> getAll() =>
      (select(postTemplates)
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  /// Get a single template by ID.
  Future<PostTemplateRow?> getById(String id) =>
      (select(postTemplates)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Insert (or replace if the ID exists).
  Future<void> upsert(PostTemplateRow row) =>
      into(postTemplates).insert(row, mode: InsertMode.insertOrReplace);

  /// Update an existing template by ID.
  Future<void> updateFields(
    String id, {
    required String name,
    required String description,
    required String systemPrompt,
    String? structureHint,
    String? toneHint,
  }) =>
      (update(postTemplates)..where((t) => t.id.equals(id))).write(
        PostTemplatesCompanion(
          name: Value(name),
          description: Value(description),
          systemPrompt: Value(systemPrompt),
          structureHint: Value(structureHint),
          toneHint: Value(toneHint),
        ),
      );

  /// Delete a template by ID. Returns rows affected (0 if not found).
  Future<int> deleteById(String id) =>
      (delete(postTemplates)..where((t) => t.id.equals(id))).go();
}
