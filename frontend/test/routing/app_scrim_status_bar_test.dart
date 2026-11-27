import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/main.dart';

import '../helpers/boot_app.dart';

/// The region at the root is the one that reaches the status bar.
Finder _rootRegion() => find
    .descendant(
      of: find.byType(AnyNoteApp),
      matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    )
    .first;

/// The status bar while a sheet is open. A scrim dims the strip behind the
/// status bar and used to leave its icons as the theme had them: in the light
/// theme, dark grey on mid grey, 2.83:1, under every bottom sheet.
void main() {
  testWidgets('light under a sheet, dark again when it closes', (tester) async {
    // The app is set to light while the phone itself is dark, so that the
    // theme the app shows is not the phone's.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await bootApp(
      tester,
      (tester) async {
        SystemUiOverlayStyle style() => tester
            .widget<AnnotatedRegion<SystemUiOverlayStyle>>(_rootRegion())
            .value;

        // A light app: dark icons, whatever the phone is.
        expect(style().statusBarIconBrightness, Brightness.dark);

        // Holding the floating button opens the ways to start a note.
        await tester.longPress(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(style().statusBarIconBrightness, Brightness.light);

        // The scrim is tapped where the sheet does not cover it.
        final scrim = tester.getRect(find.byType(ModalBarrier).last);
        await tester.tapAt(Offset(scrim.left + 20, scrim.top + 20));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(style().statusBarIconBrightness, Brightness.dark);
      },
      prefs: const {'theme_option': 'light'},
    );
  });
}
