/// Value written to `PRAGMA application_id` right after a plaintext database
/// has been encrypted (see `db_file_guard.dart`): `sqlcipher_export`
/// recreates FTS tables empty, so the full-text index must be rebuilt once.
///
/// The flag lives in the database file itself so the rebuild also happens if
/// the process dies between the migration and the rebuild. AnyNote must not
/// set `application_id` for anything else — it is reserved for this flag.
///
/// Lives apart from the migration code because that part cannot be compiled
/// for the web, while `AppDatabase` can.
const int kIndexRebuildPending = 0x414E5A01;
