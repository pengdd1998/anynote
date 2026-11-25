import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/theme/app_colors.dart';
import 'package:anynote/features/notes/presentation/notes_list_screen.dart';
import 'package:anynote/main.dart';

import '../helpers/boot_app.dart';

/// The phone's own bars — the navigation bar under the app — follow the
/// app's theme. They used to follow the phone's: with the app set to dark on
/// a light phone, a white strip stayed under every dark screen.
void main() {
  testWidgets("the system bars follow the app's theme, not the phone's", (
    tester,
  ) async {
    // The app is set to dark while the phone itself is light.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await bootApp(
      tester,
      (tester) async {
        // The region at the root is the one that reaches the navigation bar.
        final regions = find.descendant(
          of: find.byType(AnyNoteApp),
          matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        );
        final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          regions.first,
        );
        expect(region.value.systemNavigationBarColor, AppColors.darkSurface);
        expect(
          region.value.systemNavigationBarIconBrightness,
          Brightness.light,
        );
        // Because the app really is dark, whatever the phone says.
        expect(
          Theme.of(tester.element(find.byType(NotesListScreen))).brightness,
          Brightness.dark,
        );
      },
      prefs: const {'theme_option': 'dark'},
    );
  });
}
