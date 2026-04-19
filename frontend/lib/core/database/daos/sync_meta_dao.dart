import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'sync_meta_dao.g.dart';

@DriftAccessor(tables: [SyncMeta])
class SyncMetaDao extends DatabaseAccessor<AppDatabase>
    with _$SyncMetaDaoMixin {
  SyncMetaDao(super.db);

  /// Get last synced version for an item type.
  Future<int> getLastSyncedVersion(String itemType) async {
    final meta = await (select(syncMeta)..where((s) => s.itemType.equals(itemType)))
        .getSingleOrNull();
    return meta?.lastSyncedVersion ?? 0;
  }

  /// Update last synced version.
  Future<void> updateSyncMeta(String itemType, int version) async {
    await into(syncMeta).insert(
      SyncMetaCompanion.insert(
        itemType: itemType,
        lastSyncedVersion: Value(version),
        lastSyncedAt: Value(DateTime.now()),
      ),
      mode: InsertMode.replace,
    );
  }

  /// Get all sync metadata.
  Future<List<SyncMetaData>> getAll() {
    return select(syncMeta).get();
  }
}
