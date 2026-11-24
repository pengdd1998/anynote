import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/theme/app_theme.dart';
import 'package:anynote/core/theme/theme_provider.dart';

/// The system status bar's icons have to be readable above every app bar.
///
/// An [AppBar] with a transparent background — which most pages use so that
/// it melts into the paper — is judged "dark" by Material on its own, and
/// asks for white icons. On a Note 9 the clock and the battery were invisible
/// on every screen but the home tab.
void main() {
  final themes = <String, ThemeData Function()>{
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
    'high-contrast light': AppTheme.highContrastLightTheme,
    'high-contrast dark': AppTheme.highContrastDarkTheme,
  };
  // And each setting the owner can pick, under each system appearance.
  for (final option in ThemeOption.values) {
    for (final system in Brightness.values) {
      themes['${option.name}, system ${system.name}'] =
          () => selectEffectiveTheme(option, system);
    }
  }

  for (final MapEntry(key: name, value: build) in themes.entries) {
    testWidgets('$name: readable status-bar icons over a transparent bar',
        (tester) async {
      final theme = build();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              title: const Text('Page'),
            ),
            body: const SizedBox.expand(),
          ),
        ),
      );

      final style = tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.byType(
                AnnotatedRegion<SystemUiOverlayStyle>,
              ),
            ),
          )
          .value;
      expect(
        style.statusBarIconBrightness,
        theme.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      );
    });
  }
}
