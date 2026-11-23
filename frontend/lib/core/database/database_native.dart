import 'dart:io' show File;
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/open.dart' show OperatingSystem, open;
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart'
    show applyWorkaroundToOpenSqlCipherOnOldAndroidVersions, openCipherOnAndroid;

import '../platform/platform_utils.dart';
import '../storage/app_secure_storage.dart';
import 'db_file_guard.dart';

/// Secure-storage entry holding the local database passphrase.
const String _dbKeyStorageKey = 'db_encryption_key_v1';

/// Whether this isolate already points `package:sqlite3` at SQLCipher. The
/// override is per-isolate, so every isolate that touches the database has to
/// apply it (see [open.overrideFor]).
bool _sqlCipherLoaderApplied = false;

void _ensureSqlCipherLoader() {
  if (_sqlCipherLoaderApplied) return;
  if (PlatformUtils.isAndroid) {
    // Elsewhere SQLCipher replaces the sqlite3 symbols inside the process
    // image and no override is needed.
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
  }
  _sqlCipherLoaderApplied = true;
}

/// Open the native database connection, encrypted at rest with SQLCipher.
///
/// This file is conditionally imported only on native platforms. On web,
/// [database_native_stub.dart] is used instead.
///
/// History (QA BUG-0, 2026-11): the previous implementation depended on
/// sqlite3_flutter_libs (a plain SQLite build, no SQLCipher) and executed
/// `PRAGMA key` against it — a no-op. Databases were written in plaintext
/// while the UI claimed end-to-end encryption. This version encrypts, and
/// [DbFileGuard] upgrades databases written by those older builds.
QueryExecutor openNativeDatabase() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'anynote.db.sqlite'));

    // Main isolate: SQLCipher loader + old-Android workaround (the
    // workaround uses platform channels, so it must run on the main
    // isolate; see sqlcipher_flutter_libs README).
    _ensureSqlCipherLoader();
    if (PlatformUtils.isAndroid) {
      await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    }
    final cacheDir = (await getTemporaryDirectory()).path;
    final key = await _obtainDbKey();

    // Checking the key against the file, and encrypting a legacy database,
    // each run a 256,000-round PBKDF2: do them off the UI thread.
    final plan = await Isolate.run(() {
      _ensureSqlCipherLoader();
      return DbFileGuard(tempDirectory: cacheDir)
          .prepare(dbFile: file, key: key);
    });
    final effectiveKey = plan.key;

    return NativeDatabase.createInBackground(
      file,
      // The background isolate loads the sqlite3 library itself, and
      // library overrides are per-isolate — apply the override there too.
      isolateSetup: _ensureSqlCipherLoader,
      // null only when a legacy database could not be encrypted; a plaintext
      // file opened with a key is always rejected as "not a database".
      setup: effectiveKey == null
          ? null
          : (db) => db.execute(databaseKeyPragma(effectiveKey)),
    );
  });
}

/// Reads the database passphrase from secure storage, creating it on first
/// run. It is a device-local random secret rather than something derived
/// from the user's master key, because the database has to open before
/// anyone is signed in.
Future<String> _obtainDbKey() async {
  // Must be the app-wide instance: a differently configured
  // FlutterSecureStorage reads and writes a different backend on Android.
  const storage = AppSecureStorage.instance;
  final existing = await storage.read(key: _dbKeyStorageKey);
  if (existing != null && existing.isNotEmpty) return existing;

  final key = generateDatabaseKey();
  await storage.write(key: _dbKeyStorageKey, value: key);
  return key;
}
