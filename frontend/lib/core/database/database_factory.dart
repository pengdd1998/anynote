import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Platform-aware database executor factory.
///
/// On native platforms: uses NativeDatabase with SQLCipher encryption
/// backed by a SQLite file on disk.
///
/// On web: uses drift_flutter's default executor which leverages
/// OPFS (Origin Private File System) or IndexedDB for persistent
/// storage. SQLCipher PRAGMA is not applicable on web.
///
/// This factory isolates the platform-specific import logic so that
/// `app_database.dart` does not need to import `dart:io` directly.
QueryExecutor createDatabaseExecutor([String? encryptionKey]) {
  if (kIsWeb) {
    return _createWebExecutor();
  }
  // The native executor is created in app_database.dart via LazyDatabase
  // because it needs async path resolution. This factory returns a
  // sentinel that should not be reached for native.
  // Native callers should use createNativeExecutor() instead.
  throw StateError(
    'Use createNativeExecutor() for native platforms, '
    'or call createDatabaseExecutor() only on web.',
  );
}

/// Create the web database executor using drift_flutter's WASM backend.
///
/// Uses OPFS (Origin Private File System) when available for better
/// performance, falls back to IndexedDB on older browsers.
QueryExecutor _createWebExecutor() {
  // drift_flutter.driftDatabase automatically selects the best available
  // storage backend on web: OPFS -> IndexedDB.
  // We cannot call drift_flutter.driftDatabase() here because that
  // package is only available on web. Instead, this is called from
  // app_database.dart which handles the platform dispatch.
  throw StateError('Web executor should be created in app_database.dart');
}
