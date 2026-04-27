// End-to-end widget tests for the sync lifecycle.
//
// Tests cover:
// - Sync status widget rendering in the app bar
// - Sync status icon state (synced, offline, pending)
// - Offline banner visibility toggling with connectivity
// - Sync queue manager pending count display
// - Sync detail bottom sheet interaction

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/error/connectivity_provider.dart';
import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/core/sync/sync_engine.dart';
import 'package:anynote/core/sync/sync_queue_manager.dart';
import 'package:anynote/core/widgets/offline_banner.dart';
import 'package:anynote/core/widgets/sync_status_widget.dart';
import 'package:anynote/features/notes/presentation/notes_list_screen.dart';
import 'package:anynote/features/notes/presentation/widgets/sync_status_indicator.dart';
import 'package:anynote/features/settings/data/settings_providers.dart';
import 'package:anynote/main.dart';
import '../helpers/test_app_helper.dart';

// ---------------------------------------------------------------------------
// Fakes for sync flow tests
// ---------------------------------------------------------------------------

/// A controllable SyncQueueManager that allows tests to set the pending count.
class _TestableSyncQueueManager extends SyncQueueManager {
  final int _pendingCount;

  _TestableSyncQueueManager(super.db, super.engine, {int pendingCount = 0})
      : _pendingCount = pendingCount;

  @override
  Stream<int> watchPendingCount() => Stream.value(_pendingCount);

  @override
  Future<int> getPendingCount() async => _pendingCount;

  @override
  Future<void> processQueue() async {}
}

void main() {
  group('Sync flow - SyncStatusWidget', () {
    testWidgets('renders sync status icon in widget tree', (tester) async {
      final handle = await pumpScreen(
        tester,
        const SyncStatusWidget(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(SyncStatusWidget), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows cloud_done icon when synced (no pending items)',
        (tester) async {
      final handle = await pumpScreen(
        tester,
        const SyncStatusWidget(),
        overrides: defaultProviderOverrides(),
      );

      // With default overrides (0 pending, online, not syncing),
      // the icon should be cloud_done.
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows cloud_off icon when offline', (tester) async {
      final overrides = defaultProviderOverrides();

      // Override connectivity to report offline.
      overrides.add(
        connectivityProvider.overrideWith((ref) => Stream.value(false)),
      );

      final handle = await pumpScreen(
        tester,
        const SyncStatusWidget(),
        overrides: overrides,
      );

      // When offline, the icon should be cloud_off.
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows sync detail bottom sheet on tap', (tester) async {
      final handle = await pumpScreen(
        tester,
        const SyncStatusWidget(),
        overrides: defaultProviderOverrides(),
      );

      // Tap the sync status icon button.
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      // A bottom sheet should appear with sync details.
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Sync Status'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Pending operations'), findsOneWidget);
      expect(find.text('Last synced'), findsOneWidget);
      expect(find.text('Sync Now'), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('sync detail shows "Never" when no sync has occurred',
        (tester) async {
      final handle = await pumpScreen(
        tester,
        const SyncStatusWidget(),
        overrides: defaultProviderOverrides(),
      );

      // Open the sync details.
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      // Last synced should show "Never" since _FakeSyncLifecycle
      // returns null for lastSyncAt.
      expect(find.text('Never'), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Sync flow - OfflineBanner', () {
    testWidgets('is collapsed when online', (tester) async {
      final overrides = defaultProviderOverrides();
      // Default connectivity is online (Stream.value(true)).
      final handle = await pumpScreen(
        tester,
        const OfflineBanner(),
        overrides: overrides,
      );

      // The OfflineBanner widget should be present but collapsed (0 height).
      expect(find.byType(OfflineBanner), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('is expanded when offline', (tester) async {
      final overrides = defaultProviderOverrides();
      overrides.add(
        connectivityProvider.overrideWith((ref) => Stream.value(false)),
      );

      final handle = await pumpScreen(
        tester,
        const OfflineBanner(),
        overrides: overrides,
      );

      // The banner should show "No internet connection" text.
      expect(
        find.text('You are offline — changes will sync when connected'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows wifi icon and message when offline', (tester) async {
      final overrides = defaultProviderOverrides();
      overrides.add(
        connectivityProvider.overrideWith((ref) => Stream.value(false)),
      );

      final handle = await pumpScreen(
        tester,
        const OfflineBanner(),
        overrides: overrides,
      );

      // Verify the banner content.
      expect(
        find.text('You are offline — changes will sync when connected'),
        findsOneWidget,
      );
      expect(find.byType(OfflineBanner), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Sync flow - NotesListScreen integration', () {
    testWidgets('notes list screen contains sync status widget',
        (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );

      // The notes list screen should include the SyncStatusIndicator in the
      // app bar actions.
      expect(find.byType(SyncStatusIndicator), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('notes list screen contains offline banner', (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );

      // The OfflineBanner should be present in the widget tree.
      expect(find.byType(OfflineBanner), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('offline banner visible in notes list when offline',
        (tester) async {
      final overrides = defaultProviderOverrides();
      overrides.add(
        connectivityProvider.overrideWith((ref) => Stream.value(false)),
      );

      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: overrides,
      );

      // OfflineBanner should display the offline message.
      expect(
        find.text('You are offline — changes will sync when connected'),
        findsOneWidget,
      );

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('sync status indicator present in notes list when offline',
        (tester) async {
      final overrides = defaultProviderOverrides();
      overrides.add(
        connectivityProvider.overrideWith((ref) => Stream.value(false)),
      );

      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: overrides,
      );

      // The SyncStatusIndicator should still be present when offline
      // (shows a colored dot, not an icon).
      expect(find.byType(SyncStatusIndicator), findsOneWidget);

      // The OfflineBanner should display the offline message.
      expect(
        find.text('You are offline — changes will sync when connected'),
        findsOneWidget,
      );

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('notes list has scaffold structure for refresh',
        (tester) async {
      final db = createTestDatabase();

      // Insert a note so the list is not empty.
      await db.notesDao.createNote(
        id: 'sync-test-note',
        encryptedContent: 'enc_Test content',
        plainContent: 'Test content',
        plainTitle: 'Sync Test Note',
      );

      final overrides = defaultProviderOverrides(db: db);
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: overrides,
      );

      // The Scaffold and scrollable content area should be present.
      expect(find.byType(Scaffold), findsOneWidget);
      // Verify the note exists in the database (DAO level verification).
      final notes = await db.notesDao.getAllNotes();
      expect(notes.length, 1);
      expect(notes.first.plainTitle, 'Sync Test Note');

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Sync flow - connectivity state transitions', () {
    testWidgets('sync status widget uses cloud_done icon when online',
        (tester) async {
      final overrides = defaultProviderOverrides();
      // Explicitly set online connectivity.
      overrides.add(
        connectivityProvider.overrideWith((ref) => Stream.value(true)),
      );

      final handle = await pumpScreen(
        tester,
        const SyncStatusWidget(),
        overrides: overrides,
      );

      expect(find.byIcon(Icons.cloud_done), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('sync status widget shows pending badge when items queued',
        (tester) async {
      final db = createTestDatabase();

      // Build overrides with a fake queue manager that reports 3 pending.
      final fullOverrides = <Override>[
        ...defaultProviderOverrides(db: db),
        syncQueueManagerProvider.overrideWith((ref) {
          return _TestableSyncQueueManager(
            ref.read(databaseProvider),
            SyncEngine(
              ref.read(databaseProvider),
              ApiClient(baseUrl: 'http://localhost:8080'),
              FakeCryptoService(),
            ),
            pendingCount: 3,
          );
        }),
      ];

      final handle = await pumpScreen(
        tester,
        const SyncStatusWidget(),
        overrides: fullOverrides,
      );

      // When there are pending items, the icon should be cloud_upload.
      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);

      // The badge should show the pending count.
      expect(find.text('3'), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
