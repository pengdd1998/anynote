import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

/// Names under which a SQLCipher shared library is usually installed.
///
/// AnyNote's local database is SQLCipher-encrypted, but `flutter test` would
/// otherwise load the plain SQLite that ships with the OS — so every test
/// passed while the real app could not open its database (2026-11). When a
/// SQLCipher build is present (Ubuntu 24.04: `libsqlcipher1`, newer Debian:
/// `libsqlcipher0`, macOS: `brew install sqlcipher`) the whole suite runs
/// against it; the differing behaviours (no double-quoted string literals,
/// `sqlcipher_export`, key handling) are then exercised as on devices.
const _sqlCipherLibraries = <String>[
  'libsqlcipher.so.1',
  'libsqlcipher.so.0',
  'libsqlcipher.so',
  'libsqlcipher.dylib',
  'sqlcipher.dll',
];

/// Returns the loader for the host's SQLCipher, or null when none is installed.
DynamicLibrary Function()? sqlCipherLoader() {
  for (final name in _sqlCipherLibraries) {
    try {
      final lib = DynamicLibrary.open(name);
      return () => lib;
    } on ArgumentError {
      // Not installed under this name — try the next.
    }
  }
  return null;
}

/// The [OperatingSystem] value matching the current host.
OperatingSystem get hostOperatingSystem => OperatingSystem.values.firstWhere(
      (os) => os.name == Platform.operatingSystem,
      orElse: () => OperatingSystem.linux,
    );

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final loader = sqlCipherLoader();
  if (loader != null) {
    open.overrideFor(hostOperatingSystem, loader);
  } else if (Platform.environment['ANYNOTE_REQUIRE_SQLCIPHER'] == '1') {
    // Set by CI's "Database on SQLCipher" job: without the library the
    // SQLCipher-only tests would all be skipped and the run look green.
    throw StateError('A SQLCipher library is required for this test run '
        '(ANYNOTE_REQUIRE_SQLCIPHER=1) but none was found.');
  }
  await testMain();
}
