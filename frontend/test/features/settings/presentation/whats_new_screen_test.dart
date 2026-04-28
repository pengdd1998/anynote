import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/constants/changelog.dart';
import 'package:anynote/features/settings/presentation/whats_new_screen.dart';

void main() {
  // ===========================================================================
  // WhatsNewDialog
  // ===========================================================================

  group('WhatsNewDialog', () {
    testWidgets('show() displays dialog with "What\'s New" title',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _TestHost(),
          ),
        ),
      );

      // Tap the button to show the dialog.
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text("What's New"), findsOneWidget);
    });

    testWidgets('shows version number from Changelog.kCurrentVersion',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _TestHost(),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(
        find.text('Version ${Changelog.kCurrentVersion}'),
        findsOneWidget,
      );
    });

    testWidgets('shows changelog entries with checkmark icons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _TestHost(),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      final entries = Changelog.entries[Changelog.kCurrentVersion] ?? [];
      if (entries.isNotEmpty) {
        // Each entry should be displayed as text.
        for (final entry in entries) {
          expect(find.text(entry), findsOneWidget);
        }

        // Each entry row has a check_circle icon.
        expect(
          find.byIcon(Icons.check_circle),
          findsNWidgets(entries.length),
        );
      }
    });

    testWidgets('"Got it!" button dismisses the dialog', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _TestHost(),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Dialog should be visible.
      expect(find.text("What's New"), findsOneWidget);
      expect(find.text('Got it!'), findsOneWidget);

      // Tap dismiss button.
      await tester.tap(find.text('Got it!'));
      await tester.pumpAndSettle();

      // Dialog should be gone.
      expect(find.text("What's New"), findsNothing);
      expect(find.text('Got it!'), findsNothing);
    });

    testWidgets('shows auto_awesome icon in header', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _TestHost(),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('dialog is not dismissible by tapping outside', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _TestHost(),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Tap outside the dialog (on the barrier).
      // barrierDismissible is false, so the dialog should remain.
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      // Dialog should still be present.
      expect(find.text("What's New"), findsOneWidget);
    });

    testWidgets('handles empty changelog entries gracefully', (tester) async {
      // This test verifies the current version has entries and the dialog
      // handles them correctly. If entries were empty, no check_circle icons
      // would appear and the dialog would still render the header and button.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _TestHost(),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // The dialog should always show the header and dismiss button regardless
      // of whether there are entries.
      expect(find.text("What's New"), findsOneWidget);
      expect(find.text('Got it!'), findsOneWidget);

      // If the current version has no entries, there should be no check_circle
      // icons (other than the header's auto_awesome).
      final entries = Changelog.entries[Changelog.kCurrentVersion] ?? [];
      if (entries.isEmpty) {
        expect(find.byIcon(Icons.check_circle), findsNothing);
      }
    });

    testWidgets('showIfNew returns false (current stub)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _TestHostShowIfNew(),
          ),
        ),
      );

      // The result text should indicate false was returned.
      await tester.pumpAndSettle();
      expect(find.text('result: false'), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

/// A button that triggers [WhatsNewDialog.show] when tapped.
class _TestHost extends StatelessWidget {
  const _TestHost();

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => WhatsNewDialog.show(context),
      child: const Text('Show Dialog'),
    );
  }
}

/// A widget that calls [WhatsNewDialog.showIfNew] and displays the result.
class _TestHostShowIfNew extends StatefulWidget {
  const _TestHostShowIfNew();

  @override
  State<_TestHostShowIfNew> createState() => _TestHostShowIfNewState();
}

class _TestHostShowIfNewState extends State<_TestHostShowIfNew> {
  String _result = 'pending';

  @override
  void initState() {
    super.initState();
    _callShowIfNew();
  }

  Future<void> _callShowIfNew() async {
    final shown = await WhatsNewDialog.showIfNew(context);
    if (mounted) {
      setState(() {
        _result = 'result: $shown';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(_result);
  }
}
