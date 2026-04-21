import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/widgets/sync_status_badge.dart';

void main() {
  group('SyncStatusBadge', () {
    /// Helper to pump the badge inside a minimal MaterialApp so that
    /// theme, tooltip, and semantics are available.
    Future<void> pumpBadge(
      WidgetTester tester, {
      required bool isSynced,
      bool hasConflict = false,
      String? semanticLabel,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SyncStatusBadge(
              isSynced: isSynced,
              hasConflict: hasConflict,
              semanticLabel: semanticLabel,
            ),
          ),
        ),
      );
    }

    // -- Synced state -------------------------------------------------

    testWidgets('shows cloud_done icon when isSynced is true', (tester) async {
      await pumpBadge(tester, isSynced: true);

      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload), findsNothing);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
    });

    testWidgets('synced state has green color', (tester) async {
      await pumpBadge(tester, isSynced: true);

      final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_done));
      expect(icon.color, Colors.green);
    });

    testWidgets('synced state has correct tooltip', (tester) async {
      await pumpBadge(tester, isSynced: true);

      final tooltip = tester.widget<Tooltip>(
        find.byWidgetPredicate((w) => w is Tooltip && w.message != null),
      );
      expect(tooltip.message, 'Synced');
    });

    testWidgets('synced state has icon size 16', (tester) async {
      await pumpBadge(tester, isSynced: true);

      final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_done));
      expect(icon.size, 16);
    });

    // -- Pending (not synced) state -----------------------------------

    testWidgets('shows cloud_upload icon when isSynced is false', (tester) async {
      await pumpBadge(tester, isSynced: false);

      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
      expect(find.byIcon(Icons.cloud_done), findsNothing);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
    });

    testWidgets('pending state has orange color', (tester) async {
      await pumpBadge(tester, isSynced: false);

      final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_upload));
      expect(icon.color, Colors.orange);
    });

    testWidgets('pending state has correct tooltip', (tester) async {
      await pumpBadge(tester, isSynced: false);

      final tooltip = tester.widget<Tooltip>(
        find.byWidgetPredicate((w) => w is Tooltip && w.message != null),
      );
      expect(tooltip.message, 'Pending sync');
    });

    // -- Conflict state -----------------------------------------------

    testWidgets('shows cloud_off icon when hasConflict is true', (tester) async {
      await pumpBadge(tester, isSynced: false, hasConflict: true);

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.byIcon(Icons.cloud_done), findsNothing);
      expect(find.byIcon(Icons.cloud_upload), findsNothing);
    });

    testWidgets('conflict state has red color', (tester) async {
      await pumpBadge(tester, isSynced: false, hasConflict: true);

      final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
      expect(icon.color, Colors.red);
    });

    testWidgets('conflict state has correct tooltip', (tester) async {
      await pumpBadge(tester, isSynced: false, hasConflict: true);

      final tooltip = tester.widget<Tooltip>(
        find.byWidgetPredicate((w) => w is Tooltip && w.message != null),
      );
      expect(tooltip.message, 'Sync conflict');
    });

    // -- Conflict overrides synced ------------------------------------

    testWidgets('conflict takes priority over isSynced true', (tester) async {
      await pumpBadge(tester, isSynced: true, hasConflict: true);

      // Even though isSynced is true, conflict should win.
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.byIcon(Icons.cloud_done), findsNothing);

      final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
      expect(icon.color, Colors.red);
    });

    // -- Semantics ----------------------------------------------------

    testWidgets('uses tooltip as default semantic label', (tester) async {
      await pumpBadge(tester, isSynced: true);

      final semantics = tester.widget<Semantics>(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.label != null &&
            w.properties.label!.isNotEmpty),
      );
      expect(semantics.properties.label, 'Synced');
    });

    testWidgets('uses custom semantic label when provided', (tester) async {
      await pumpBadge(
        tester,
        isSynced: true,
        semanticLabel: 'Note is synced to server',
      );

      final semantics = tester.widget<Semantics>(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.label != null &&
            w.properties.label!.isNotEmpty),
      );
      expect(semantics.properties.label, 'Note is synced to server');
    });

    // -- Widget structure ---------------------------------------------

    testWidgets('renders a Tooltip wrapping Semantics wrapping Icon',
        (tester) async {
      await pumpBadge(tester, isSynced: true);

      expect(
        find.byWidgetPredicate((w) => w is Tooltip && w.message != null),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.label != null &&
            w.properties.label!.isNotEmpty),
        findsOneWidget,
      );
      expect(find.byType(Icon), findsOneWidget);
    });
  });
}
