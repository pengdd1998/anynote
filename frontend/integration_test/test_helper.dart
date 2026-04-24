import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'package:anynote/core/crypto/crypto_service.dart';
import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/error/connectivity_provider.dart';
import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/core/sync/sync_engine.dart';
import 'package:anynote/core/sync/sync_lifecycle.dart';
import 'package:anynote/core/sync/sync_queue_manager.dart';
import 'package:anynote/features/settings/data/settings_providers.dart';
import 'package:anynote/l10n/app_localizations.dart';
import 'package:anynote/main.dart';
import 'package:anynote/features/notes/presentation/note_editor_screen.dart';
import 'package:anynote/routing/app_router.dart';

// ---------------------------------------------------------------------------
// Integration test binding initialization
// ---------------------------------------------------------------------------

/// Call once at the top of `main()` in every integration test file.
void initIntegrationTest() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
}

// ---------------------------------------------------------------------------
// Fake implementations for integration tests
// ---------------------------------------------------------------------------

/// A fake [CryptoService] that simulates unlocked state with deterministic
/// encrypt/decrypt behaviour suitable for assertions.
///
/// Encryption wraps plaintext with an `enc_` prefix. Decryption strips it.
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

/// A fake [ApiClient] that simulates auth responses without network calls.
class FakeApiClient extends ApiClient {
  /// When true, the next login/register call throws a [DioException] with 401.
  bool shouldFailAuth = false;

  /// When true, the next register call throws a [DioException] with 409
  /// (conflict / email taken).
  bool shouldFailRegister = false;

  FakeApiClient() : super(baseUrl: 'http://localhost:0');

  @override
  Future<AuthResponse> register(RegisterRequest req) async {
    if (shouldFailRegister) {
      throw Exception('email already taken');
    }
    return _fakeAuthResponse();
  }

  @override
  Future<AuthResponse> login(LoginRequest req) async {
    if (shouldFailAuth) {
      throw Exception('invalid credentials');
    }
    return _fakeAuthResponse();
  }

  AuthResponse _fakeAuthResponse() {
    return AuthResponse(
      accessToken: 'test_access_token_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'test_refresh_token',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      user: {'id': 'test_user_id', 'email': 'test@example.com'},
    );
  }
}

// ---------------------------------------------------------------------------
// Test database creation
// ---------------------------------------------------------------------------

/// Creates a file-based [AppDatabase] for integration testing.
///
/// Uses the system SQLite library and writes to a temp file that should be
/// cleaned up via [TestAppHandle.dispose] at the end of each test.
AppDatabase createTestDatabase() {
  open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open('libsqlite3.so'),
  );
  sqlite3.tempDirectory = Directory.systemTemp.path;
  final file = File(
    '${Directory.systemTemp.path}/'
    'integration_test_${DateTime.now().millisecondsSinceEpoch}.sqlite',
  );
  return AppDatabase.forTesting(NativeDatabase(file));
}

// ---------------------------------------------------------------------------
// Fake sync lifecycle and queue manager
// ---------------------------------------------------------------------------

class _FakeSyncQueueManager extends SyncQueueManager {
  _FakeSyncQueueManager(AppDatabase db)
      : super(
          db,
          SyncEngine(
            db,
            ApiClient(baseUrl: 'http://localhost:0'),
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

class _FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Provider overrides
// ---------------------------------------------------------------------------

/// Returns the standard list of provider overrides used by all integration
/// tests. Every dependency that requires external services (network, crypto
/// hardware, secure storage) is replaced with a fake.
List<Override> defaultIntegrationOverrides({
  FakeCryptoService? cryptoService,
  FakeApiClient? apiClient,
  AppDatabase? db,
}) {
  final crypto = cryptoService ?? FakeCryptoService();
  final database = db ?? createTestDatabase();
  final api = apiClient ?? FakeApiClient();

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
// Test app harness
// ---------------------------------------------------------------------------

/// Pumps the full AnyNote app (with go_router) inside a [ProviderScope] with
/// the given [overrides].
///
/// Returns a [TestAppHandle] that must be disposed before the test ends.
/// Use [addTearDown] with [TestAppHandle.dispose] to ensure cleanup.
///
/// Unlike the widget-test helper which pumps a single screen, this pumps the
/// entire [AnyNoteApp] so that go_router redirects, shell routes, and bottom
/// navigation all work as they do in production.
Future<TestAppHandle> pumpTestApp(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  late ProviderContainer container;

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: Builder(
        builder: (context) {
          container = ProviderScope.containerOf(context);
          // Make the global container available to go_router redirects.
          globalContainer = container;
          return MaterialApp.router(
            routerConfig: appRouter,
            localizationsDelegates: const [
              ...AppLocalizations.localizationsDelegates,
              quill.FlutterQuillLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
          );
        },
      ),
    ),
  );

  // Allow several frames for streams, futures, and router redirects.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));

  return TestAppHandle._(container, tester);
}

/// Handle for a pumped integration test app. Call [dispose] to clean up
/// resources (database, provider container) before the test ends.
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

  /// Clean up resources: close the database, unmount the widget tree, and
  /// dispose the provider container.
  ///
  /// MUST be called before the test body returns. Use [addTearDown]:
  ///
  /// ```dart
  /// final handle = await pumpTestApp(tester, overrides: ...);
  /// addTearDown(() => handle.dispose());
  /// ```
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    try {
      final db = _container.read(databaseProvider);
      await db.close();
    } catch (_) {
      // Container may already be disposed.
    }

    await _tester.pumpWidget(Container());
    await _tester.pumpAndSettle(const Duration(seconds: 1));

    try {
      _container.dispose();
    } catch (_) {
      // Already disposed.
    }
  }
}

// ---------------------------------------------------------------------------
// Common finders
// ---------------------------------------------------------------------------

/// Finder for the bottom [NavigationBar] in phone layout.
final Finder bottomNavigationBar = find.byType(NavigationBar);

/// Finder for the [FloatingActionButton] on the notes list screen.
final Finder fabFinder = find.byType(FloatingActionButton);

/// Finder for the search toggle icon button (Icons.search).
final Finder searchToggleFinder = find.byIcon(Icons.search);

/// Finder for the close-search icon button (Icons.close).
final Finder closeSearchFinder = find.byIcon(Icons.close);

/// Finder for the note editor screen (any instance).
final Finder noteEditorFinder = find.byType(NoteEditorScreen);

// ---------------------------------------------------------------------------
// Common gestures
// ---------------------------------------------------------------------------

/// Tap the Notes tab (index 0) in the bottom navigation bar.
Future<void> tapNotesTab(WidgetTester tester) async {
  await tester.tap(
    find.byWidgetPredicate(
      (widget) =>
          widget is NavigationDestination &&
          widget.icon is Icon &&
          (widget.icon as Icon).icon == Icons.note_outlined,
    ),
  );
  await tester.pumpAndSettle();
}

/// Tap the Compose tab (index 1) in the bottom navigation bar.
Future<void> tapComposeTab(WidgetTester tester) async {
  await tester.tap(
    find.byWidgetPredicate(
      (widget) =>
          widget is NavigationDestination &&
          widget.icon is Icon &&
          (widget.icon as Icon).icon == Icons.auto_awesome_outlined,
    ),
  );
  await tester.pumpAndSettle();
}

/// Tap the Settings tab (index 3) in the bottom navigation bar.
Future<void> tapSettingsTab(WidgetTester tester) async {
  await tester.tap(
    find.byWidgetPredicate(
      (widget) =>
          widget is NavigationDestination &&
          widget.icon is Icon &&
          (widget.icon as Icon).icon == Icons.settings_outlined,
    ),
  );
  await tester.pumpAndSettle();
}

/// Create a note directly in the database with the given title and content.
/// Returns the generated note ID.
Future<String> createTestNote(
  AppDatabase db,
  CryptoService crypto,
  String title,
  String content,
) async {
  final uuid = 'test_note_${DateTime.now().millisecondsSinceEpoch}';
  final encryptedContent = await crypto.encryptForItem(uuid, content);
  final encryptedTitle = await crypto.encryptForItem(uuid, title);

  await db.notesDao.createNote(
    id: uuid,
    encryptedContent: encryptedContent,
    encryptedTitle: encryptedTitle,
    plainContent: content,
    plainTitle: title,
  );

  return uuid;
}

/// Wait for all animations and async operations to settle, with a generous
/// timeout suitable for integration tests.
Future<void> settleAndWait(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(seconds: 2));
}
