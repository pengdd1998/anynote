import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/compose/presentation/compose_screen.dart';
import '../../../helpers/test_app_helper.dart';

/// Regression: opening the compose note-selector sheet must not throw
/// "No GoRouter found in context". The sheet's initState registers a router
/// listener and pre-selects the general template in a post-frame callback;
/// those paths must tolerate contexts that are not (or are no longer) below
/// the Router (GoRouter.maybeOf), matching the on-device red-screen ANR.
void main() {
  testWidgets('compose sheet opens without router errors', (tester) async {
    final handle = await pumpScreen(
      tester,
      const ComposeScreen(),
      overrides: defaultProviderOverrides(),
    );

    // Tap the hero card exactly like the device flow does.
    final heroTexts = tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .toList();
    // ignore: avoid_print
    print('DEBUG-HERO: ' + heroTexts.join(' | '));
    await tester.tap(find.text('Start Composing'));
    await tester.pump(); // start modal route
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // The sheet should be showing (新创作 title) without any exception.
    // The sheet opens cleanly: no router exceptions during its first frames
    // (listener registration + template preselect).
    expect(tester.takeException(), isNull);
    expect(find.text('New Composition'), findsOneWidget);


    await handle.dispose();
  });
}
