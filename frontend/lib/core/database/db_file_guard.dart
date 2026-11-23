import 'dart:developer' show log;
import 'dart:io';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart' show Database, Sqlite3;
import 'package:sqlite3/sqlite3.dart' as s3 show sqlite3;

import 'db_file_flags.dart';

/// First 16 bytes of every unencrypted SQLite database.
const _sqliteHeader = 'SQLite format 3\u0000';

/// How long the plaintext copy kept by a migration survives after it.
const defaultBackupRetention = Duration(days: 7);

/// What [DbFileGuard.prepare] decided about the database file.
enum DbFileOutcome {
  /// No database exists yet; the caller creates a fresh encrypted one.
  fresh,

  /// An encrypted database that opens with [DbFilePlan.key].
  ready,

  /// A legacy plaintext database was encrypted in place.
  migrated,

  /// The database is still plaintext because encrypting it failed. It opens
  /// WITHOUT a key so the app stays usable; the next launch retries.
  plaintext,

  /// The database is encrypted but the key does not open it (the key stored
  /// in secure storage was lost). The unreadable file was moved aside and a
  /// fresh database will be created in its place.
  keyMismatch,
}

class DbFilePlan {
  const DbFilePlan(this.outcome, this.key);

  final DbFileOutcome outcome;

  /// Passphrase for `PRAGMA key`, or null when the database must be opened
  /// without one (only for [DbFileOutcome.plaintext]). Turn it into a
  /// statement with [databaseKeyPragma].
  final String? key;
}

/// The statement that unlocks a database with [key]. `PRAGMA` takes no bound
/// parameters, so the key is embedded as a literal; keys come from
/// [generateDatabaseKey] (hex only) and the escaping is a safeguard.
String databaseKeyPragma(String key) =>
    "PRAGMA key = '${key.replaceAll("'", "''")}'";

/// Generates a random database passphrase (32 bytes of entropy, hex).
///
/// A device-local secret rather than a key derived from the user's master
/// key: the database has to open before anyone logs in.
String generateDatabaseKey() {
  final random = Random.secure();
  final bytes = Uint8List(32);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Prepares the on-disk database file for being opened with SQLCipher.
///
/// Plain Dart on purpose (no Flutter imports): the caller runs [prepare] on a
/// helper isolate, because both the key check and `sqlcipher_export` run a
/// 256,000-round PBKDF2 that would otherwise block the UI thread.
class DbFileGuard {
  DbFileGuard(
      {Sqlite3? sqlite3, this.tempDirectory, void Function(String)? logger})
      : _sqlite3 = sqlite3 ?? s3.sqlite3,
        _logger = logger ?? log;

  final Sqlite3 _sqlite3;
  final void Function(String) _logger;

  /// Directory for SQLite temporary storage; `sqlcipher_export` builds the
  /// target schema through temp tables, which some platforms cannot create
  /// under the default location.
  final String? tempDirectory;

  /// Inspects [dbFile] and brings it into a state where opening it with
  /// `PRAGMA key = [key]` works, or reports why it cannot.
  ///
  /// Never deletes user data: a migrated database keeps a plaintext backup
  /// (`<db>.plaintext-backup`) for [backupRetention], and a database whose
  /// key is lost is renamed to `<db>.orphan-<timestamp>` rather than removed.
  DbFilePlan prepare({
    required File dbFile,
    required String key,
    Duration backupRetention = defaultBackupRetention,
    DateTime? now,
  }) {
    final tmp = File('${dbFile.path}.encrypting');
    final backup = File('${dbFile.path}.plaintext-backup');
    final dir = tempDirectory;
    if (dir != null) _sqlite3.tempDirectory = dir;

    // -- Recover an interrupted previous run --------------------------------
    if (!dbFile.existsSync()) {
      if (tmp.existsSync()) {
        // Killed between the two renames of the swap; `tmp` was verified.
        _logger('finishing interrupted encryption of ${dbFile.path}');
        tmp.renameSync(dbFile.path);
      } else if (backup.existsSync()) {
        // Plaintext was moved aside but nothing replaced it: bring it back
        // and migrate again below.
        _logger('restoring ${backup.path} for encryption');
        backup.renameSync(dbFile.path);
      } else {
        return DbFilePlan(DbFileOutcome.fresh, key);
      }
    }

    if (_readHeader(dbFile) == _sqliteHeader) {
      return _encryptPlaintext(dbFile, tmp, backup, key);
    }

    // Encrypted (or unrecognisable): does the key open it?
    if (!_opensWith(dbFile, key)) {
      return _recoverUnreadable(
          dbFile, tmp, backup, key, now ?? DateTime.now());
    }

    _expireBackup(backup, backupRetention, now ?? DateTime.now());
    return DbFilePlan(DbFileOutcome.ready, key);
  }

  // ── Plaintext → encrypted ────────────────────────────────────────────────

  DbFilePlan _encryptPlaintext(
    File dbFile,
    File tmp,
    File backup,
    String key,
  ) {
    // A leftover from a run killed during the export is incomplete.
    _removeQuietly(tmp);

    try {
      final snapshot = _exportEncrypted(dbFile, tmp, key);
      _verifyEncrypted(tmp, key, snapshot);
    } catch (e) {
      _logger('could not encrypt ${dbFile.path} ($e); '
          'keeping the plaintext database and retrying next launch');
      _removeQuietly(tmp);
      return const DbFilePlan(DbFileOutcome.plaintext, null);
    }

    if (backup.existsSync()) _deleteWithSidecars(backup);
    dbFile.renameSync(backup.path);
    // The export folded the WAL into the main file, but keep whatever
    // sidecars remain next to the backup instead of leaving plaintext
    // behind under the live database's name.
    _moveSidecars(dbFile, backup);
    try {
      tmp.renameSync(dbFile.path);
    } catch (_) {
      backup.renameSync(dbFile.path);
      rethrow;
    }
    _logger('encrypted ${dbFile.path} '
        '(plaintext backup kept at ${backup.path} until it ages out)');
    return DbFilePlan(DbFileOutcome.migrated, key);
  }

  /// Copies the plaintext database into [tmp] through `sqlcipher_export`,
  /// returning the facts used later to verify the copy.
  ///
  /// `sqlcipher_export` carries tables, rows and schema objects — but not
  /// `PRAGMA user_version`. Without restoring it the copy reports version 0,
  /// which Drift takes for a brand-new database and re-runs `onCreate` over
  /// the existing tables, so the open fails and the app comes up empty and
  /// unable to save (the 2026-11 upgrade regression).
  _Snapshot _exportEncrypted(File dbFile, File tmp, String key) {
    final plain = _sqlite3.open(dbFile.path);
    try {
      // Merge any WAL into the main file first so the export sees every row.
      plain.select('PRAGMA wal_checkpoint(TRUNCATE)');
      final snapshot = _Snapshot(
        userVersion: plain.select('PRAGMA user_version').first.values[0] as int,
        tableCounts: _tableCounts(plain),
      );

      plain.execute('ATTACH DATABASE ? AS migrate KEY ?', [tmp.path, key]);
      try {
        plain.select("SELECT sqlcipher_export('migrate')");
        plain.execute('PRAGMA migrate.user_version = ${snapshot.userVersion}');
        plain.execute('PRAGMA migrate.application_id = $kIndexRebuildPending');
      } finally {
        plain.execute('DETACH DATABASE migrate');
      }
      return snapshot;
    } finally {
      plain.dispose();
    }
  }

  void _verifyEncrypted(File tmp, String key, _Snapshot snapshot) {
    final db = _sqlite3.open(tmp.path);
    try {
      db.execute(databaseKeyPragma(key));
      final version = db.select('PRAGMA user_version').first.values[0];
      if (version != snapshot.userVersion) {
        throw StateError(
            'user_version is $version, expected ${snapshot.userVersion}');
      }
      final counts = _tableCounts(db);
      for (final entry in snapshot.tableCounts.entries) {
        if (counts[entry.key] != entry.value) {
          throw StateError('table ${entry.key} has ${counts[entry.key]} rows, '
              'expected ${entry.value}');
        }
      }
      if (counts.length != snapshot.tableCounts.length) {
        throw StateError('encrypted copy has ${counts.length} tables, '
            'expected ${snapshot.tableCounts.length}');
      }
    } finally {
      db.dispose();
    }
  }

  // ── Encrypted database ───────────────────────────────────────────────────

  bool _opensWith(File dbFile, String key) {
    Database? db;
    try {
      db = _sqlite3.open(dbFile.path);
      db.execute(databaseKeyPragma(key));
      db.select('SELECT count(*) FROM sqlite_master');
      return true;
    } catch (e) {
      _logger('${dbFile.path} does not open with the stored key: $e');
      return false;
    } finally {
      db?.dispose();
    }
  }

  /// Handles an encrypted database the key no longer opens (the key kept in
  /// secure storage was lost or reset).
  ///
  /// The file is moved aside, never deleted. While the plaintext backup from
  /// the migration still exists it is restored and encrypted with the current
  /// key, which brings the data back; once the backup has aged out there is
  /// nothing left that can be decrypted and the caller starts a fresh
  /// database.
  DbFilePlan _recoverUnreadable(
    File dbFile,
    File tmp,
    File backup,
    String key,
    DateTime now,
  ) {
    final orphan = File('${dbFile.path}.orphan-${now.millisecondsSinceEpoch}');
    dbFile.renameSync(orphan.path);
    _moveSidecars(dbFile, orphan);

    if (backup.existsSync()) {
      _logger('recovering ${dbFile.path} from the plaintext backup '
          '${backup.path}; the previous encrypted copy is at ${orphan.path}');
      backup.renameSync(dbFile.path);
      _moveSidecars(backup, dbFile);
      return _encryptPlaintext(dbFile, tmp, backup, key);
    }

    _logger('moved the unreadable database to ${orphan.path}; creating a '
        'fresh one. Notes in that file were never synced to the server and '
        'cannot be decrypted without their key — synced notes return on the '
        'next sign-in.');
    return DbFilePlan(DbFileOutcome.keyMismatch, key);
  }

  void _expireBackup(File backup, Duration retention, DateTime now) {
    if (!backup.existsSync()) return;
    final age = now.difference(backup.lastModifiedSync());
    if (age < retention) return;
    _deleteWithSidecars(backup);
    _logger('removed the expired plaintext backup ${backup.path}');
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static const _sidecarSuffixes = ['-wal', '-shm', '-journal'];

  /// Row counts of every ordinary table. Virtual tables are excluded: their
  /// shadow tables carry no SQL and are not copied by `sqlcipher_export`,
  /// so after the export the virtual table reads as empty by design (the
  /// caller rebuilds it, see [kIndexRebuildPending]).
  static Map<String, int> _tableCounts(Database db) {
    final tables = db
        .select("SELECT name FROM sqlite_master "
            "WHERE type = 'table' AND sql IS NOT NULL "
            "AND name NOT LIKE 'sqlite_%' "
            "AND lower(sql) NOT LIKE 'create virtual table%'")
        .map((row) => row['name'] as String)
        .toList()
      ..sort();
    return {
      for (final name in tables)
        name: db.select('SELECT count(*) FROM "$name"').first.values[0] as int,
    };
  }

  /// Renames the SQLite sidecars of [from] (`-wal`, `-shm`, `-journal`) so
  /// they follow their database file.
  static void _moveSidecars(File from, File to) {
    for (final suffix in _sidecarSuffixes) {
      final sidecar = File('${from.path}$suffix');
      if (sidecar.existsSync()) sidecar.renameSync('${to.path}$suffix');
    }
  }

  void _removeQuietly(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException catch (e) {
      _logger('could not remove ${file.path}: $e');
    }
  }

  static void _deleteWithSidecars(File file) {
    if (file.existsSync()) file.deleteSync();
    for (final suffix in _sidecarSuffixes) {
      final sidecar = File('${file.path}$suffix');
      if (sidecar.existsSync()) sidecar.deleteSync();
    }
  }

  /// The first 16 bytes of [file] as a string, shorter when the file is.
  static String _readHeader(File file) {
    final raf = file.openSync(mode: FileMode.read);
    try {
      final bytes = raf.readSync(_sqliteHeader.length);
      return String.fromCharCodes(bytes);
    } finally {
      raf.closeSync();
    }
  }
}

/// What the plaintext database contained when the export started.
class _Snapshot {
  const _Snapshot({required this.userVersion, required this.tableCounts});

  final int userVersion;
  final Map<String, int> tableCounts;
}
