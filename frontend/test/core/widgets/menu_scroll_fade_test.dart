import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/theme/app_colors.dart';
import 'package:anynote/core/theme/app_icons.dart';
import 'package:anynote/core/theme/app_theme.dart';
import 'package:anynote/core/widgets/menu_scroll_fade.dart';

/// A menu longer than the screen says so at its bottom edge, in the menu's
/// own colour, and stops saying it at the end of the list.
void main() {
  const fadeKey = Key('menu-scroll-fade');

  Future<void> openMenu(WidgetTester tester, {int rows = 60}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: PopupMenuButton<String>(
              icon: const Icon(AppIcons.moreVertical),
              itemBuilder: (context) => [
                const MenuScrollFade(),
                for (var i = 0; i < rows; i++)
                  PopupMenuItem(value: '$i', child: Text('Row $i')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
  }

  Finder fadePart<T>() =>
      find.descendant(of: find.byKey(fadeKey), matching: find.byType(T));

  double opacityOf(WidgetTester tester) =>
      tester.widget<AnimatedOpacity>(fadePart<AnimatedOpacity>()).opacity;

  testWidgets('the entry takes no height, and a menu that fits gets no fade', (
    tester,
  ) async {
    await openMenu(tester, rows: 3);

    expect(tester.getSize(find.byType(MenuScrollFade)).height, 0);
    expect(opacityOf(tester), 0);
  });

  testWidgets('a menu longer than the screen fades at its bottom edge', (
    tester,
  ) async {
    await openMenu(tester);

    expect(opacityOf(tester), 1);
    final menu = tester.getRect(find.byType(SingleChildScrollView).last);
    final fade = tester.getRect(find.byKey(fadeKey));
    expect(fade.left, closeTo(menu.left, 0.5));
    expect(fade.right, closeTo(menu.right, 0.5));
    expect(fade.bottom, closeTo(menu.bottom, 0.5));
    expect(fade.height, 36);

    // The menu's own colour, so the sliced row sinks into the menu.
    final box = tester.widget<DecoratedBox>(fadePart<DecoratedBox>());
    final gradient = (box.decoration as BoxDecoration).gradient!;
    expect(gradient.colors.last, AppColors.lightCardBg);
    expect(gradient.colors.first.a, 0);

    // And it stands aside for a finger: the row under it still takes taps.
    expect(fadePart<IgnorePointer>(), findsOneWidget);
  });

  testWidgets('at the end of the list the fade is gone', (tester) async {
    await openMenu(tester);
    await tester.drag(find.text('Row 0'), const Offset(0, -4000));
    await tester.pumpAndSettle();

    expect(opacityOf(tester), 0);
  });

  testWidgets('closing the menu takes the fade with it', (tester) async {
    await openMenu(tester);
    await tester.tapAt(const Offset(20, 300));
    await tester.pumpAndSettle();

    expect(find.byKey(fadeKey), findsNothing);
  });
}
