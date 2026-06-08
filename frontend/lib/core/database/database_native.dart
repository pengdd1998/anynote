import 'dart:io' show File;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3_lib;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../platform/platform_utils.dart';

/// Open a native database connection with optional SQLCipher encryption.
///
/// This file is conditionally imported only on native platforms. On web,
/// [database_native_stub.dart] is used instead.
QueryExecutor openNativeDatabase(String? encryptionKey) {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'anynote.db.sqlite'));

    if (PlatformUtils.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    final cacheBase = (await getTemporaryDirectory()).path;
    sqlite3_lib.sqlite3.tempDirectory = cacheBase;

    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        if (encryptionKey != null) {
          db.execute('PRAGMA key = "$encryptionKey"');
        }
      },
    );
  });
}
