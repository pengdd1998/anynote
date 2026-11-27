import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/theme/app_colors.dart';
import 'package:anynote/core/theme/app_icons.dart';
import 'package:anynote/core/theme/app_theme.dart';
import 'package:anynote/core/widgets/menu_scroll_fade.dart';

/// A menu longer than the screen says so at its bottom edge, in the menu's
/// own colour, from its first frame — and stops saying it at the end of the
/// list.
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
              clipBehavior: Clip.antiAlias,
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
  }

  /// Opens the menu and lets it finish opening.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pumpAndSettle();
  }

  MenuScrollFadePainter fadeOf(WidgetTester tester) =>
      tester.widget<CustomPaint>(find.byKey(fadeKey)).painter!
          as MenuScrollFadePainter;

  /// The menu's scroll view on the screen, as it is right now: the full
  /// height of its rows from the menu's first frame.
  Rect menuRect(WidgetTester tester) =>
      tester.getRect(find.byType(SingleChildScrollView).last);

  /// The menu's own box: what can be seen of it, which grows while it opens.
  Finder menuBox() => find
      .ancestor(
        of: find.byType(SingleChildScrollView).last,
        matching: find.byType(Material),
      )
      .first;

  testWidgets('the entry takes no height, and a menu that fits gets no fade', (
    tester,
  ) async {
    await openMenu(tester, rows: 3);
    await settle(tester);

    expect(tester.getSize(find.byType(MenuScrollFade)).height, 0);
    expect(fadeOf(tester).opacity, 0);
  });

  testWidgets('a menu longer than the screen fades at its bottom edge', (
    tester,
  ) async {
    await openMenu(tester);
    await settle(tester);

    final painter = fadeOf(tester);
    expect(painter.opacity, 1);
    final menu = menuRect(tester);
    final fade = painter.rect;
    expect(fade.left, closeTo(menu.left, 0.5));
    expect(fade.right, closeTo(menu.right, 0.5));
    expect(fade.bottom, closeTo(menu.bottom, 0.5));
    expect(fade.height, 36);

    // At rest the menu is as tall as its rows, and the fade spans its width.
    expect(tester.getRect(menuBox()), menu);
    expect(fadeOf(tester).rect.bottom, closeTo(menu.bottom, 0.5));
    // The menu's own colour, so the sliced row sinks into the menu.
    expect(painter.color, AppColors.lightCardBg);
    // And it stands aside for a finger: the row under it still takes taps.
    expect(
      find.ancestor(
        of: find.byKey(fadeKey),
        matching: find.byType(IgnorePointer),
      ),
      findsOneWidget,
    );
  });

  testWidgets("the fade is on the menu's edge while the menu is still opening",
      (tester) async {
    // A menu grows to its height while it opens. Held back until the menu
    // was at rest, the fade left the last row sliced for as long as that
    // took — over a second on a slow phone.
    await openMenu(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final painter = fadeOf(tester);
    expect(painter.opacity, 1);
    final box = tester.getRect(menuBox());
    // Still growing: the menu is not yet as tall as its rows.
    expect(box.height, lessThan(menuRect(tester).height));
    // On the edge that can be seen, not on the bottom of the rows.
    expect(painter.rect.bottom, closeTo(box.bottom, 1));
  });

  testWidgets('the fade follows the menu when the room under it changes', (
    tester,
  ) async {
    // A keyboard closing under an open menu makes the menu taller; nothing
    // scrolls it and its animation is over.
    await openMenu(tester);
    await settle(tester);
    final before = menuRect(tester).bottom;
    expect(fadeOf(tester).rect.bottom, closeTo(before, 0.5));

    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pump();
    await tester.pump();

    final after = menuRect(tester).bottom;
    expect(after, greaterThan(before));
    expect(fadeOf(tester).rect.bottom, closeTo(after, 0.5));
  });

  testWidgets('at the end of the list the fade is gone', (tester) async {
    await openMenu(tester);
    await settle(tester);
    await tester.drag(find.text('Row 0'), const Offset(0, -4000));
    await tester.pumpAndSettle();

    expect(fadeOf(tester).opacity, 0);
  });

  testWidgets('closing the menu takes the fade with it', (tester) async {
    await openMenu(tester);
    await settle(tester);
    await tester.tapAt(const Offset(20, 300));
    await tester.pumpAndSettle();

    expect(find.byKey(fadeKey), findsNothing);
  });
}
