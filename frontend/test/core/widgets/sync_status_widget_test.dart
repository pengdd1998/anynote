import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/error/connectivity_provider.dart';
import 'package:anynote/core/sync/sync_lifecycle.dart';
import 'package:anynote/core/sync/sync_queue_manager.dart';
import 'package:anynote/core/widgets/sync_status_widget.dart';
import 'package:anynote/features/settings/data/settings_providers.dart';
import 'package:anynote/main.dart';

import '../../helpers/test_app_helper.dart';

// ---------------------------------------------------------------------------
// Fakes for SyncStatusWidget tests
// ---------------------------------------------------------------------------

/// A fake SyncQueueManager that emits a configurable pending count stream.
class FakeSyncQueueManager extends SyncQueueManager {
  final int _pendingCount;

  FakeSyncQueueManager(this._pendingCount)
      : super(
          createTestDatabase(),
          SyncEngine(
            createTestDatabase(),
            ApiClient(baseUrl: 'http://localhost:8080'),
            FakeCryptoService(),
          ),
        );

  @override
  Stream<int> watchPendingCount() => Stream.value(_pendingCount);

  @override
  Future<int> getPendingCount() async => _pendingCount;

  @override
  Future<void> processQueue() async {}
}

/// A fake SyncLifecycle with configurable active state and last sync time.
class FakeSyncLifecycle extends SyncLifecycle {
  final bool _isActive;
  final DateTime? _lastSyncAt;

  FakeSyncLifecycle({
    bool isActive = false,
    DateTime? lastSyncAt,
  })  : _isActive = isActive,
        _lastSyncAt = lastSyncAt,
        super(_FakeRefForLifecycle());

  @override
  bool get isActive => _isActive;

  @override
  DateTime? get lastSyncAt => _lastSyncAt;

  @override
  void start() {}

  @override
  void stop() {}

  @override
  Future<SyncResult?> syncNow() async => null;
}

/// Minimal fake Ref for SyncLifecycle constructor.
class _FakeRefForLifecycle implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

/// Builds the provider overrides for a given test scenario.
List<Override> _buildOverrides({
  required int pendingCount,
  required bool isOnline,
  required bool isSyncing,
  DateTime? lastSyncAt,
}) {
  return [
    ...defaultProviderOverrides(),
    connectivityProvider.overrideWith(
      (ref) => Stream.value(isOnline),
    ),
    syncQueueManagerProvider.overrideWith(
      (ref) => FakeSyncQueueManager(pendingCount),
    ),
    syncLifecycleProvider.overrideWith(
      (ref) => FakeSyncLifecycle(
        isActive: isSyncing,
        lastSyncAt: lastSyncAt,
      ),
    ),
  ];
}

/// Pumps the SyncStatusWidget inside a ProviderScope with the given overrides.
Future<void> _pumpWidget(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        home: Scaffold(
          body: SyncStatusWidget(),
        ),
      ),
    ),
  );

  // Let streams and animations settle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SyncStatusWidget', () {
    // -- Idle / synced state ------------------------------------------

    testWidgets('shows cloud_done icon when idle and synced', (tester) async {
      await _pumpWidget(
        tester,
        overrides: _buildOverrides(
          pendingCount: 0,
          isOnline: true,
          isSyncing: false,
        ),
      );

      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
    });

    testWidgets('shows All changes synced tooltip when idle', (tester) async {
      await _pumpWidget(
        tester,
        overrides: _buildOverrides(
          pendingCount: 0,
          isOnline: true,
          isSyncing: false,
        ),
      );

      // IconButton has a tooltip parameter.
      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.tooltip, 'All changes synced');
    });

    // -- Syncing state ------------------------------------------------

    testWidgets('shows sync icon when syncing', (tester) async {
      await _pumpWidget(
        tester,
        overrides: _buildOverrides(
          pendingCount: 0,
          isOnline: true,
          isSyncing: true,
        ),
      );

      expect(find.byIcon(Icons.sync), findsOneWidget);
    });

    testWidgets('shows Syncing... tooltip when syncing', (tester) async {
      await _pumpWidget(
        tester,
        overrides: _buildOverrides(
          pendingCount: 0,
          isOnline: true,
          isSyncing: true,
        ),
      );

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.tooltip, 'Syncing...');
    });

    // -- Offline state ------------------------------------------------

    testWidgets('shows cloud_off icon when offline', (tester) async {
      await _pumpWidget(
        tester,
        overrides: _buildOverrides(
          pendingCount: 0,
          isOnline: false,
          isSyncing: false,
        ),
      );

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('shows Offline tooltip when offline', (tester) async {
      await _pumpWidget(
        tester,
        overrides: _buildOverrides(
          pendingCount: 0,
          isOnline: false,
          isSyncing: false,
        ),
      );

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.tooltip, 'Offline -- changes will sync when connected');
    });

    testWidgets('offline state takes priority over syncing', (tester) async {
      // Even if syncing is true, offline should win for the icon.
      await _pumpWidget(
        tester,
        overrides: _buildOverrides(
          pendingCount: 0,
          isOnline: false,
          isSyncing: true,
        ),
      );

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    // -- Pending operations -------------------------------------------

    testWidgets('shows cloud_upload icon when there are pending operations',
        (tester) async {
      await _pumpWidget(
        tester,
        overrides: _buildOverrides(
          pendingCount: 3,
          isOnline: true,
          isSyncing: false,
        ),
      );

      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
    });

    testWidgets('shows pending count tooltip with singular form for 1',
        (tester) async {
      await _pumpWidget(
        tester,
        overrides: _buildOverrides(
          pendingCount: 1,
          isOnline: true,
          isSyncing: false,
        ),
      );

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.tooltip, '1 pending operation');
    });

    testWidgets('shows pending count tooltip with plural form for >1',
        (tester) async {
      await _pumpWidget(
        tester,
        overrides: _buildOverrides(
          pendingCount: 5,
          isOnline: true,
          isSyncing: false,
        ),
      );

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.tooltip, '5 pending operations');
    });

    // -- Pending badge ------------------------------------------------

    testWidgets('shows badge with count when pending > 0', (tester) async {
      await _pumpWidget(
        tester,
        overrides: _buildOverrides(
          pendingCount: 3,
          isOnline: true,
          isSyncing: false,
        ),
      );

      // The badge displays the count as text.
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows 9+ when pending count exceeds 9', (tester) async {
      await _pumpWidget(
        tester,
        overrides: _buildOverrides(
          pendingCount: 15,
          isOnline: true,
          isSyncing: false,
        ),
      );

      expect(find.text('9+'), findsOneWidget);
    });

    testWidgets('does not show badge when pending count is 0', (tester) async {
      await _pumpWidget(
        tester,
        overrides: _buildOverrides(
          pendingCount: 0,
          isOnline: true,
          isSyncing: false,
        ),
      );

      // No badge text should be present (only the icon-related widgets).
      expect(find.text('0'), findsNothing);
      expect(find.text('9+'), findsNothing);
    });

    // -- Bottom sheet interaction -------------------------------------

    testWidgets('tapping opens bottom sheet with sync details',
        (tester) async {
      await _pumpWidget(
        tester,
        overrides: _buildOverrides(
          pendingCount: 2,
          isOnline: true,
          isSyncing: false,
          lastSyncAt: DateTime(2025, 6, 15, 14, 30),
        ),
      );

      // Tap the IconButton to open the bottom sheet.
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      // The bottom sheet should show the "Sync Status" title.
      expect(find.text('Sync Status'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Pending operations'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Last synced'), findsOneWidget);
      expect(find.text('14:30'), findsOneWidget);
      expect(find.text('Sync now'), findsOneWidget);
    });

    testWidgets('bottom sheet shows Offline when offline', (tester) async {
      await _pumpWidget(
        tester,
        overrides: _buildOverrides(
          pendingCount: 0,
          isOnline: false,
          isSyncing: false,
        ),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('bottom sheet shows Never when lastSyncAt is null',
        (tester) async {
      await _pumpWidget(
        tester,
        overrides: _buildOverrides(
          pendingCount: 0,
          isOnline: true,
          isSyncing: false,
          lastSyncAt: null,
        ),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(find.text('Never'), findsOneWidget);
    });

    // -- Rotation animation -------------------------------------------

    testWidgets('contains RotationTransition for sync animation',
        (tester) async {
      await _pumpWidget(
        tester,
        overrides: _buildOverrides(
          pendingCount: 0,
          isOnline: true,
          isSyncing: false,
        ),
      );

      expect(find.byType(RotationTransition), findsOneWidget);
    });

    // -- Smoke test ---------------------------------------------------

    testWidgets('renders without errors in all states', (tester) async {
      // Quick smoke test across the three main visual states.
      for (final scenario in [
        (pending: 0, online: true, syncing: false),
        (pending: 5, online: true, syncing: true),
        (pending: 0, online: false, syncing: false),
      ]) {
        await _pumpWidget(
          tester,
          overrides: _buildOverrides(
            pendingCount: scenario.pending,
            isOnline: scenario.online,
            isSyncing: scenario.syncing,
          ),
        );

        expect(find.byType(SyncStatusWidget), findsOneWidget);
        expect(find.byType(IconButton), findsOneWidget);
      }
    });
  });
}
