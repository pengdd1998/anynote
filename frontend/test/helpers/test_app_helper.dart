import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:anynote/core/crypto/crypto_service.dart';
import 'package:anynote/core/error/connectivity_provider.dart';
import 'package:anynote/core/sync/sync_engine.dart';
import 'package:anynote/core/sync/sync_lifecycle.dart';
import 'package:anynote/core/sync/sync_queue_manager.dart';
import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/features/settings/data/settings_providers.dart';
import 'package:anynote/l10n/app_localizations.dart';
import 'package:anynote/main.dart';

// ---------------------------------------------------------------------------
// Fake implementations
// ---------------------------------------------------------------------------

/// A fake CryptoService that returns plausible values without real crypto.
class FakeCryptoService extends CryptoService {
  @override
  bool get isUnlocked => true;

  @override
  Future<bool> isInitialized() async => true;

  @override
  Future<String> encryptForItem(String itemId, String plaintext) async =>
      'enc_$plaintext';

  @override
  Future<String?> decryptForItem(String itemId, String encrypted) async =>
      encrypted.replaceFirst('enc_', '');

  @override
  Future<void> lock() async {}
}

// ---------------------------------------------------------------------------
// Test database management
// ---------------------------------------------------------------------------

/// Creates a synchronous file-based AppDatabase for testing.
AppDatabase createTestDatabase() {
  open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open('libsqlite3.so'),
  );
  sqlite3.tempDirectory = Directory.systemTemp.path;
  final file = File(
    '${Directory.systemTemp.path}/test_${DateTime.now().millisecondsSinceEpoch}.sqlite',
  );
  return AppDatabase.forTesting(NativeDatabase(file));
}

// ---------------------------------------------------------------------------
// Common overrides
// ---------------------------------------------------------------------------

/// Returns the standard list of provider overrides used by all widget tests.
List<Override> defaultProviderOverrides({
  CryptoService? cryptoService,
  AppDatabase? db,
}) {
  final crypto = cryptoService ?? FakeCryptoService();
  final database = db ?? createTestDatabase();
  final api = ApiClient(baseUrl: 'http://localhost:8080');

  return [
    databaseProvider.overrideWithValue(database),
    apiClientProvider.overrideWithValue(api),
    cryptoServiceProvider.overrideWithValue(crypto),
    syncQueueManagerProvider.overrideWith((ref) {
      return _FakeSyncQueueManager(ref.read(databaseProvider));
    }),
    connectivityProvider.overrideWith((ref) => Stream.value(true)),
    syncLifecycleProvider.overrideWith((ref) => _FakeSyncLifecycle()),
  ];
}

// ---------------------------------------------------------------------------
// Minimal fakes
// ---------------------------------------------------------------------------

/// A fake SyncQueueManager that returns an empty pending count stream.
class _FakeSyncQueueManager extends SyncQueueManager {
  _FakeSyncQueueManager(AppDatabase db)
      : super(
          db,
          SyncEngine(
            db,
            ApiClient(baseUrl: 'http://localhost:8080'),
            FakeCryptoService(),
          ),
        );

  @override
  Stream<int> watchPendingCount() => Stream.value(0);

  @override
  Future<int> getPendingCount() async => 0;

  @override
  Future<void> processQueue() async {}
}

/// A fake SyncLifecycle that does nothing.
class _FakeSyncLifecycle extends SyncLifecycle {
  _FakeSyncLifecycle() : super(_FakeRef());

  @override
  bool get isActive => false;

  @override
  DateTime? get lastSyncAt => null;

  @override
  void start() {}

  @override
  void stop() {}

  @override
  Future<SyncResult?> syncNow() async => null;
}

/// Minimal fake Ref for wiring SyncLifecycle.
class _FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

/// Pumps a screen widget inside a localized MaterialApp wrapped in a
/// ProviderScope with [overrides].
///
/// Returns a [TestAppHandle] that must be disposed before the test ends.
/// Use [addTearDown] with [TestAppHandle.dispose] to ensure cleanup.
Future<TestAppHandle> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
}) async {
  late ProviderContainer container;

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: Builder(
        builder: (context) {
          container = ProviderScope.containerOf(context);
          return MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: screen,
          );
        },
      ),
    ),
  );

  // Pump a few frames to let streams and futures resolve.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));

  return TestAppHandle._(container, tester);
}

/// Handle for a pumped test screen. Call [dispose] to clean up resources
/// (database, provider container) before the test ends.
class TestAppHandle {
  final ProviderContainer _container;
  final WidgetTester _tester;
  bool _disposed = false;

  TestAppHandle._(this._container, this._tester);

  /// The active provider container.
  ProviderContainer get container {
    if (_disposed) throw StateError('TestAppHandle already disposed');
    return _container;
  }

  /// Clean up resources: unmount widgets, close the database, and dispose
  /// the provider container.
  ///
  /// This MUST be called before the test body returns to avoid timer leaks
  /// from Drift's stream query system. Use [addTearDown] in each test:
  ///
  /// ```dart
  /// final handle = await pumpScreen(tester, MyScreen(), overrides: ...);
  /// addTearDown(() => handle.dispose());
  /// // ... assertions ...
  /// ```
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    // 1. Close the database to clean up Drift internal timers.
    try {
      final db = _container.read(databaseProvider);
      await db.close();
    } catch (_) {
      // Container may already be disposed.
    }

    // 2. Unmount the widget tree.
    await _tester.pumpWidget(Container());
    await _tester.pumpAndSettle(const Duration(seconds: 1));

    // 3. Dispose the provider container.
    try {
      _container.dispose();
    } catch (_) {
      // Already disposed.
    }
  }
}
