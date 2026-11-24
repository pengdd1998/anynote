import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/theme/app_icons.dart';
import 'package:anynote/features/notes/presentation/notes_list_screen.dart';
import 'package:anynote/l10n/app_localizations.dart';

import '../../../helpers/test_app_helper.dart';

/// The ⋮ menu on the home screen.
void main() {
  late AppLocalizations l10n;

  Finder row(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byType(PopupMenuItem<String>),
      );

  /// What the row with [label] shows before its text.
  IconData? leadingIcon(WidgetTester tester, String label) {
    final icon = find.descendant(
      of: row(label),
      matching: find.byType(Icon),
    );
    return tester.widget<Icon>(icon.first).icon;
  }

  /// The check that marks the row with [label] as the current one.
  Finder markOn(String label) =>
      find.descendant(of: row(label), matching: find.byIcon(AppIcons.check));

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip(l10n.moreActions));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Pumps the home screen and runs [body], then takes it down inside the
  /// test: the list's database leaves timers behind otherwise.
  Future<void> onHome(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    final handle = await pumpScreen(
      tester,
      const NotesListScreen(autoLoad: false),
      overrides: defaultProviderOverrides(),
    );
    l10n = AppLocalizations.of(tester.element(find.byType(NotesListScreen)))!;
    try {
      await body();
    } finally {
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('the sort rows are told apart by what they sort by', (
    tester,
  ) async {
    await onHome(tester, () async {
      await openMenu(tester);

      expect(leadingIcon(tester, l10n.updatedNewest), AppIcons.schedule);
      expect(leadingIcon(tester, l10n.updatedOldest), AppIcons.schedule);
      expect(leadingIcon(tester, l10n.createdNewest), AppIcons.calendarToday);
      expect(leadingIcon(tester, l10n.createdOldest), AppIcons.calendarToday);
      expect(leadingIcon(tester, l10n.titleAZ), AppIcons.sort);
      expect(leadingIcon(tester, l10n.sortCustom), AppIcons.tune);
    });
  });

  testWidgets('the current sort is the one row that is marked', (
    tester,
  ) async {
    await onHome(tester, () async {
      await openMenu(tester);

      // The default, and nothing else.
      final marks = find.descendant(
        of: find.byType(PopupMenuItem<String>),
        matching: find.byIcon(AppIcons.check),
      );
      expect(marks, findsOneWidget);
      expect(markOn(l10n.updatedNewest), findsOneWidget);

      // Choosing another one moves the mark to it.
      await tester.tap(find.text(l10n.titleAZ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await openMenu(tester);

      expect(marks, findsOneWidget);
      expect(markOn(l10n.titleAZ), findsOneWidget);
      expect(markOn(l10n.updatedNewest), findsNothing);
    });
  });

  testWidgets("the wordmark's sparkle is one of the family's icons", (
    tester,
  ) async {
    await onHome(tester, () async {
      expect(find.byIcon(AppIcons.sparkles), findsOneWidget);
    });
  });
}
