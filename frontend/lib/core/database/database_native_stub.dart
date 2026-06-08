import 'package:drift/drift.dart';

/// Stub for [openNativeDatabase] on web.
///
/// Never called at runtime because app_database.dart returns early via the
/// kIsWeb check in _openConnection() before invoking this function.
QueryExecutor openNativeDatabase(String? encryptionKey) {
  throw UnsupportedError('Native database is not available on web');
}
