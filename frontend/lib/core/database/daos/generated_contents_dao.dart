import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'generated_contents_dao.g.dart';

@DriftAccessor(tables: [GeneratedContents])
class GeneratedContentsDao extends DatabaseAccessor<AppDatabase>
    with _$GeneratedContentsDaoMixin {
  GeneratedContentsDao(super.db);

  /// Get all generated contents.
  Future<List<GeneratedContent>> getAll() {
    return (select(generatedContents)
          ..orderBy([(gc) => OrderingTerm.desc(gc.updatedAt)]))
        .get();
  }

  /// Watch all generated contents.
  Stream<List<GeneratedContent>> watchAll() {
    return (select(generatedContents)
          ..orderBy([(gc) => OrderingTerm.desc(gc.updatedAt)]))
        .watch();
  }

  /// Get by ID.
  Future<GeneratedContent?> getById(String id) {
    return (select(generatedContents)..where((gc) => gc.id.equals(id)))
        .getSingleOrNull();
  }

  /// Create generated content.
  Future<String> create({
    required String id,
    required String encryptedBody,
    String? plainBody,
    String platformStyle = 'generic',
    String aiModelUsed = '',
  }) async {
    final now = DateTime.now();
    await into(generatedContents).insert(GeneratedContentsCompanion.insert(
      id: id,
      encryptedBody: encryptedBody,
      plainBody: Value(plainBody),
      platformStyle: Value(platformStyle),
      aiModelUsed: Value(aiModelUsed),
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }

  /// Update generated content.
  Future<void> update({
    required String id,
    String? encryptedBody,
    String? plainBody,
  }) async {
    await (update(generatedContents)..where((gc) => gc.id.equals(id)))
        .write(GeneratedContentsCompanion(
      encryptedBody: Value(encryptedBody),
      plainBody: Value(plainBody),
      updatedAt: Value(DateTime.now()),
      isSynced: const Value(false),
    ));
  }

  /// Delete generated content.
  Future<void> delete(String id) async {
    await (delete(generatedContents)..where((gc) => gc.id.equals(id))).go();
  }

  /// Get unsynced contents.
  Future<List<GeneratedContent>> getUnsynced() {
    return (select(generatedContents)..where((gc) => gc.isSynced.equals(false)))
        .get();
  }

  /// Mark as synced.
  Future<void> markSynced(String id) async {
    await (update(generatedContents)..where((gc) => gc.id.equals(id)))
        .write(const GeneratedContentsCompanion(isSynced: Value(true)));
  }
}
