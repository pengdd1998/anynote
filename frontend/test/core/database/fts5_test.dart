import 'package:flutter_test/flutter_test.dart';

// FTS5 MATCH queries are not compatible with Drift's SQL parser (sqlparser)
// when running via NativeDatabase in flutter test. The sqlparser package
// interprets FTS5 table names as column references in MATCH clauses.
// Production code uses sqlite3_flutter_libs on mobile which handles this
// correctly. These tests should be run on a real device/emulator.
@Skip('FTS5 MATCH requires native mobile SQLite; skipped in flutter test env')
void main() {
  test('FTS5 placeholder', () {
    // Actual FTS5 tests are skipped in this environment.
    // Run on device/emulator to verify FTS5 Chinese/CJK search.
  });
}
