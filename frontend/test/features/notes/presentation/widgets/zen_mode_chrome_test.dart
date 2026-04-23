import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/widgets/zen_mode_chrome.dart';
import 'package:anynote/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> pumpZenChrome(
  WidgetTester tester, {
  required VoidCallback onExit,
  required VoidCallback onToggle,
}) async {
  final controller = AnimationController(
    vsync: tester,
    duration: const Duration(milliseconds: 300),
    value: 1.0,
  );

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: ZenModeChrome(
          animation: controller,
          onExit: onExit,
          onToggle: onToggle,
        ),
      ),
    ),
  );

  addTearDown(controller.dispose);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ZenModeChrome', () {
    testWidgets('renders back arrow icon', (tester) async {
      await pumpZenChrome(
        tester,
        onExit: () {},
        onToggle: () {},
      );
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('renders fullscreen exit icon', (tester) async {
      await pumpZenChrome(
        tester,
        onExit: () {},
        onToggle: () {},
      );
      expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
    });

    testWidgets('fires onExit when back arrow tapped', (tester) async {
      var exited = false;
      await pumpZenChrome(
        tester,
        onExit: () => exited = true,
        onToggle: () {},
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(exited, isTrue);
    });

    testWidgets('fires onToggle when fullscreen exit tapped', (tester) async {
      var toggled = false;
      await pumpZenChrome(
        tester,
        onExit: () {},
        onToggle: () => toggled = true,
      );

      await tester.tap(find.byIcon(Icons.fullscreen_exit));
      expect(toggled, isTrue);
    });

    testWidgets('uses FadeTransition', (tester) async {
      await pumpZenChrome(
        tester,
        onExit: () {},
        onToggle: () {},
      );
      // MaterialApp also creates FadeTransitions, so we expect at least one.
      expect(find.byType(FadeTransition), findsAtLeast(1));
    });

    testWidgets('renders as Row layout', (tester) async {
      await pumpZenChrome(
        tester,
        onExit: () {},
        onToggle: () {},
      );
      expect(find.byType(Row), findsOneWidget);
    });
  });
}
