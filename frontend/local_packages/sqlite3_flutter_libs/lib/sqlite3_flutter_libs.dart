/// Local stand-in for the real sqlite3_flutter_libs API (drift_flutter's
/// expected surface). See pubspec.yaml for why this stub exists.
library;

import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart' as cipher;

/// Satisfies drift_flutter's call site (same signature, SQLCipher flavor).
Future<void> applyWorkaroundToOpenSqlite3OnOldAndroidVersions() {
  return cipher.applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
}
