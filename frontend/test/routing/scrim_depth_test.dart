import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/theme/app_colors.dart';
import 'package:anynote/core/theme/system_bars.dart';
import 'package:anynote/routing/scrim_depth.dart';

/// While a scrim is up — the dimming under a bottom sheet or a dialog — the
/// status bar takes light icons. In the light theme its icons were dark grey
/// on the dimmed strip, 2.83:1, under every sheet.
void main() {
  group('systemBarsStyle', () {
    test('the status bar follows the theme, and turns light under a scrim', () {
      final light = systemBarsStyle(
        brightness: Brightness.light,
        scrimUp: false,
      );
      expect(light.statusBarIconBrightness, Brightness.dark);
      expect(light.statusBarBrightness, Brightness.light);
      expect(light.statusBarColor, Colors.transparent);

      final underScrim = systemBarsStyle(
        brightness: Brightness.light,
        scrimUp: true,
      );
      expect(underScrim.statusBarIconBrightness, Brightness.light);
      expect(underScrim.statusBarBrightness, Brightness.dark);
      // Nothing else of the bars moves with a sheet.
      expect(
        underScrim.systemNavigationBarColor,
        light.systemNavigationBarColor,
      );

      for (final scrimUp in [false, true]) {
        final dark = systemBarsStyle(
          brightness: Brightness.dark,
          scrimUp: scrimUp,
        );
        expect(dark.statusBarIconBrightness, Brightness.light);
      }
    });

    test('the strip behind the icons is shaded only under a light scrim', () {
      // A dark theme's strip is dark already; light icons read on it.
      for (final scrimUp in [false, true]) {
        expect(
          statusBarShaded(brightness: Brightness.dark, scrimUp: scrimUp),
          isFalse,
        );
      }
      expect(
        statusBarShaded(brightness: Brightness.light, scrimUp: false),
        isFalse,
      );
      expect(
        statusBarShaded(brightness: Brightness.light, scrimUp: true),
        isTrue,
      );
    });

    test('the navigation bar follows the theme, scrim or no scrim', () {
      for (final scrimUp in [false, true]) {
        expect(
          systemBarsStyle(brightness: Brightness.light, scrimUp: scrimUp)
              .systemNavigationBarColor,
          AppColors.lightSurface,
        );
        expect(
          systemBarsStyle(brightness: Brightness.dark, scrimUp: scrimUp)
              .systemNavigationBarColor,
          AppColors.darkSurface,
        );
      }
    });
  });

  group('ScrimDepth', () {
    /// The app's context, for its dialog and sheet.
    late BuildContext navContext;

    /// An app with a dialog, a sheet and a menu on its root navigator, and
    /// another navigator inside with a sheet of its own.
    Widget app(ScrimDepth depth) => MaterialApp(
          navigatorObservers: [depth.observer()],
          home: Scaffold(
            body: Builder(
              // The app's own context, for its dialog and its sheet.
              builder: (context) {
                navContext = context;
                return Column(
                  children: [
                    TextButton(
                      onPressed: () => showDialog<void>(
                        context: navContext,
                        builder: (_) =>
                            const AlertDialog(title: Text('A dialog')),
                      ),
                      child: const Text('dialog'),
                    ),
                    TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: navContext,
                        builder: (_) => const SizedBox(
                          height: 200,
                          child: Text('A sheet'),
                        ),
                      ),
                      child: const Text('sheet'),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'menu',
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'one', child: Text('One')),
                      ],
                    ),
                    SizedBox(
                      height: 300,
                      child: Navigator(
                        observers: [depth.observer()],
                        onGenerateRoute: (_) => MaterialPageRoute<void>(
                          builder: (context) => Scaffold(
                            body: TextButton(
                              onPressed: () => showModalBottomSheet<void>(
                                context: context,
                                builder: (_) => const SizedBox(
                                  height: 100,
                                  child: Text('A nested sheet'),
                                ),
                              ),
                              child: const Text('nested sheet'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
    Future<void> show(WidgetTester tester, ScrimDepth depth) async {
      await tester.pumpWidget(app(depth));
      await tester.pumpAndSettle();
    }

    testWidgets('a dialog is a scrim, and leaving it is not', (tester) async {
      final depth = ScrimDepth();
      await show(tester, depth);
      expect(depth.count, 0);

      await tester.tap(find.text('dialog'));
      await tester.pumpAndSettle();
      expect(depth.count, 1);

      // The barrier is tapped, the way a dialog is left.
      await tester.tapAt(const Offset(20, 40));
      await tester.pumpAndSettle();
      expect(find.text('A dialog'), findsNothing);
      expect(depth.count, 0);
    });

    testWidgets('a bottom sheet is a scrim', (tester) async {
      final depth = ScrimDepth();
      await show(tester, depth);

      await tester.tap(find.text('sheet'));
      await tester.pumpAndSettle();
      expect(depth.up, isTrue);

      await tester.tapAt(const Offset(20, 40));
      await tester.pumpAndSettle();
      expect(depth.up, isFalse);
    });

    testWidgets("a popup menu's barrier is transparent and is not a scrim", (
      tester,
    ) async {
      final depth = ScrimDepth();
      await show(tester, depth);

      await tester.tap(find.byTooltip('menu'));
      await tester.pumpAndSettle();

      expect(depth.count, 0);
    });

    testWidgets('two navigators count together', (tester) async {
      final depth = ScrimDepth();
      await show(tester, depth);

      await tester.tap(find.text('nested sheet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('dialog'));
      await tester.pumpAndSettle();
      expect(depth.count, 2);

      await tester.tapAt(const Offset(20, 40));
      await tester.pumpAndSettle();
      expect(depth.count, 1);

      // The nested sheet's scrim covers only its own navigator's box.
      final nested = tester.getRect(find.byType(Navigator).last);
      await tester.tapAt(nested.topLeft + const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(find.text('A nested sheet'), findsNothing);
      expect(depth.count, 0);
    });

    testWidgets(
      'a navigator taken down with its sheet open does not hold the bar',
      (tester) async {
        // Nothing reports that sheet. It is dropped at the next change,
        // or the status bar would stay light for the rest of the session.
        final depth = ScrimDepth();
        await show(tester, depth);
        await tester.tap(find.text('dialog'));
        await tester.pumpAndSettle();
        expect(depth.up, isTrue);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        // Still counted: nothing has told the depth anything.
        expect(depth.up, isTrue);

        // A new app comes up, and its first route is a change.
        await show(tester, depth);
        expect(depth.count, 0);

        await tester.tap(find.text('sheet'));
        await tester.pumpAndSettle();
        expect(depth.count, 1);

        await tester.tapAt(const Offset(20, 40));
        await tester.pumpAndSettle();
        expect(depth.count, 0);
      },
    );
  });
}
