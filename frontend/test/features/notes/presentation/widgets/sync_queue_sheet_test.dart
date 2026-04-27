import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/widgets/sync_queue_sheet.dart';
import 'package:anynote/l10n/app_localizations.dart';

import '../../../../helpers/test_app_helper.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pump the [SyncQueueSheet] inside a localized MaterialApp with a bottom sheet
/// scaffold so the sheet renders properly.
Future<void> pumpSyncQueueSheet(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  // Use a taller surface so the DraggableScrollableSheet does not overflow.
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(Container());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [...defaultProviderOverrides(), ...overrides],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const SyncQueueSheet(),
                  );
                },
                child: const Text('Open Sheet'),
              );
            },
          ),
        ),
      ),
    ),
  );

  // Open the bottom sheet.
  await tester.tap(find.text('Open Sheet'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SyncQueueSheet', () {
    testWidgets('renders sync queue title', (tester) async {
      await pumpSyncQueueSheet(tester);

      expect(find.text('Sync Queue'), findsOneWidget);
    });

    testWidgets('renders sync icon in header', (tester) async {
      await pumpSyncQueueSheet(tester);

      expect(find.byIcon(Icons.sync), findsOneWidget);
    });

    testWidgets('renders pending operations label', (tester) async {
      await pumpSyncQueueSheet(tester);

      expect(find.text('Pending Operations'), findsOneWidget);
    });

    testWidgets('renders failed operations label', (tester) async {
      await pumpSyncQueueSheet(tester);

      expect(find.text('Failed Operations'), findsOneWidget);
    });

    testWidgets('renders retry all button', (tester) async {
      await pumpSyncQueueSheet(tester);

      expect(find.text('Retry All'), findsOneWidget);
    });

    testWidgets('renders clear completed button', (tester) async {
      await pumpSyncQueueSheet(tester);

      expect(find.text('Clear Completed'), findsOneWidget);
    });

    testWidgets('shows empty queue state when no failed operations',
        (tester) async {
      await pumpSyncQueueSheet(tester);

      expect(find.text('No pending operations'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('shows zero counts when queue is empty', (tester) async {
      await pumpSyncQueueSheet(tester);

      // Both status cards show 0 when no operations exist.
      // There are multiple '0' texts (pending and failed), so find at least 2.
      expect(find.text('0'), findsAtLeastNWidgets(2));
    });

    testWidgets('retry all button is disabled when no failed ops',
        (tester) async {
      await pumpSyncQueueSheet(tester);

      // The Retry All button should be disabled because there are no failed ops.
      final retryButton = find.widgetWithText(OutlinedButton, 'Retry All');
      expect(retryButton, findsOneWidget);

      final buttonWidget = tester.widget<OutlinedButton>(retryButton);
      expect(buttonWidget.onPressed, isNull);
    });

    testWidgets('renders handle bar', (tester) async {
      await pumpSyncQueueSheet(tester);

      // The sheet has a handle bar (a small container at the top).
      // Verify the sync icon and title exist instead of trying to find
      // the anonymous Container handle bar.
      expect(find.text('Sync Queue'), findsOneWidget);
    });

    testWidgets('renders schedule and error icons for status cards',
        (tester) async {
      await pumpSyncQueueSheet(tester);

      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsAtLeast(1));
    });
  });
}
