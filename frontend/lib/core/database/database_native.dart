import 'dart:io' show File, Platform;
import 'dart:math' show Random;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/open.dart' show open, OperatingSystem;
import 'package:sqlite3/sqlite3.dart' as sqlite3_lib;
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

import '../platform/platform_utils.dart';

/// Secure-storage key holding the local database passphrase.
///
/// The key is a device-generated random 64-char hex string, created on the
/// first database open and never changed afterwards (so the database stays
/// readable across restarts and app updates). It is NOT derived from the
/// user's master key: the database must open before any login happens.
const String _dbKeyStorageKey = 'db_encryption_key_v1';

/// Applied once per isolate before any sqlite3 use (see [open.overrideFor] —
/// library overrides are per-isolate).
bool _sqlCipherLoaderApplied = false;

/// Make sure the SQLCipher build is the library that `package:sqlite3`
/// loads on this isolate. Safe to call repeatedly; on platforms other than
/// Android the SQLCipher pod/build is linked transparently and no override
/// is needed.
void _ensureSqlCipherLoader() {
  if (_sqlCipherLoaderApplied) return;
  if (PlatformUtils.isAndroid) {
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
/// while the UI claimed end-to-end encryption. This version actually
/// encrypts: sqlcipher_flutter_libs ships SQLCipher builds of SQLite, the
/// key lives in secure storage, and legacy plaintext databases are migrated
/// in place (with a backup) on first open.
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

    final cacheBase = (await getTemporaryDirectory()).path;
    sqlite3_lib.sqlite3.tempDirectory = cacheBase;

    final key = await _obtainDbKey();
    await _migratePlaintextIfNeeded(file, key);

    return NativeDatabase.createInBackground(
      file,
      // The background isolate loads the sqlite3 library itself, and
      // library overrides are per-isolate — apply the override there too.
      isolateSetup: () {
        _ensureSqlCipherLoader();
      },
      setup: (db) {
        db.execute("PRAGMA key = '$key'");
      },
    );
  });
}

/// Read the database passphrase from secure storage, generating and
/// persisting a fresh random 256-bit hex key on first run.
Future<String> _obtainDbKey() async {
  const storage = FlutterSecureStorage();
  final existing = await storage.read(key: _dbKeyStorageKey);
  if (existing != null && existing.isNotEmpty) return existing;

  final random = Random.secure();
  final key =
      List.generate(64, (_) => random.nextInt(16).toRadixString(16)).join();
  await storage.write(key: _dbKeyStorageKey, value: key);
  return key;
}

/// If the database file on disk is a legacy PLAINTEXT database, encrypt it
/// in place (with a kept backup). Already-encrypted databases are left
/// untouched. Fails open: on any migration error the plaintext database
/// keeps working (with a warning) rather than losing data.
Future<void> _migratePlaintextIfNeeded(File file, String key) async {
  if (!file.existsSync()) return; // Fresh install — nothing to migrate.

  // Probe: a plaintext database opens and queries fine WITHOUT a key;
  // an SQLCipher-encrypted file throws ("file is not a database").
  var isPlaintext = false;
  try {
    final probe = sqlite3_lib.sqlite3.open(file.path);
    try {
      probe.select('SELECT count(*) FROM sqlite_master');
      isPlaintext = true;
    } finally {
      probe.dispose();
    }
  } catch (_) {
    isPlaintext = false; // Encrypted (or unreadable) — leave it alone.
  }
  if (!isPlaintext) return;

  final tmpPath = '${file.path}.encrypting';
  final tmp = File(tmpPath);
  if (tmp.existsSync()) tmp.deleteSync();

  try {
    // Open plaintext (no key), export into a key-protected attached copy.
    final plain = sqlite3_lib.sqlite3.open(file.path);
    try {
      final escapedPath = tmpPath.replaceAll("'", "''");
      plain.execute(
        "ATTACH DATABASE '$escapedPath' AS migrate KEY '$key'",
      );
      plain.select("SELECT sqlcipher_export('migrate')");
      plain.execute('DETACH DATABASE migrate');
    } finally {
      plain.dispose();
    }

    // Verify the encrypted copy actually opens with the key before
    // touching the original.
    final verify = sqlite3_lib.sqlite3.open(tmpPath);
    try {
      verify.execute("PRAGMA key = '$key'");
      verify.select('SELECT count(*) FROM sqlite_master');
    } finally {
      verify.dispose();
    }

    // Keep a plaintext backup (defense against regressions), then swap.
    final backupPath = '${file.path}.plaintext-backup';
    final backup = File(backupPath);
    if (backup.existsSync()) backup.deleteSync();
    file.renameSync(backupPath);
    tmp.renameSync(file.path);
    debugPrint(
      '[DB] legacy plaintext database migrated to SQLCipher '
      '(plaintext backup kept at $backupPath)',
    );
  } catch (e) {
    debugPrint(
      '[DB] plaintext→SQLCipher migration failed, continuing unencrypted: $e',
    );
    if (tmp.existsSync()) tmp.deleteSync();
  }
}
