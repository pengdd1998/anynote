import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/widgets/find_replace_bar.dart';
import 'package:anynote/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps a [FindReplaceBar] inside a localized [MaterialApp].
Future<void> pumpFindReplaceBar(
  WidgetTester tester, {
  bool isVisible = true,
  int matchIndex = -1,
  int matchCount = 0,
  ValueChanged<String>? onSearchChanged,
  VoidCallback? onPrevious,
  VoidCallback? onNext,
  VoidCallback? onReplace,
  VoidCallback? onReplaceAll,
  VoidCallback? onClose,
}) async {
  final searchController = TextEditingController();
  final replaceController = TextEditingController();
  addTearDown(() {
    searchController.dispose();
    replaceController.dispose();
  });

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: FindReplaceBar(
          isVisible: isVisible,
          searchTextController: searchController,
          replaceTextController: replaceController,
          matchIndex: matchIndex,
          matchCount: matchCount,
          onSearchChanged: onSearchChanged ?? (_) {},
          onPrevious: onPrevious ?? () {},
          onNext: onNext ?? () {},
          onReplace: onReplace ?? () {},
          onReplaceAll: onReplaceAll ?? () {},
          onClose: onClose ?? () {},
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// FindReplaceBar Widget Tests
// ---------------------------------------------------------------------------

void main() {
  group('FindReplaceBar visibility', () {
    testWidgets('renders nothing when isVisible is false', (tester) async {
      await pumpFindReplaceBar(tester, isVisible: false);
      expect(find.byType(FindReplaceBar), findsOneWidget);
      // The bar should render a SizedBox.shrink, so no text fields visible.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('shows search input when visible', (tester) async {
      await pumpFindReplaceBar(tester, isVisible: true);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows find hint text', (tester) async {
      await pumpFindReplaceBar(tester, isVisible: true);
      expect(find.text('Find in note'), findsOneWidget);
    });

    testWidgets('shows close button', (tester) async {
      await pumpFindReplaceBar(tester, isVisible: true);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('shows previous match button', (tester) async {
      await pumpFindReplaceBar(tester, isVisible: true);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
    });

    testWidgets('shows next match button', (tester) async {
      await pumpFindReplaceBar(tester, isVisible: true);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });

    testWidgets('shows expand/collapse button for replace', (tester) async {
      await pumpFindReplaceBar(tester, isVisible: true);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });
  });

  group('FindReplaceBar match count display', () {
    testWidgets('shows "No matches" when matchCount is 0', (tester) async {
      await pumpFindReplaceBar(tester, matchCount: 0, matchIndex: -1);
      expect(find.text('No matches'), findsOneWidget);
    });

    testWidgets('shows match count as "current of total"', (tester) async {
      await pumpFindReplaceBar(tester, matchCount: 5, matchIndex: 2);
      expect(find.text('3 of 5'), findsOneWidget);
    });

    testWidgets('shows "1 of 1" for single match', (tester) async {
      await pumpFindReplaceBar(tester, matchCount: 1, matchIndex: 0);
      expect(find.text('1 of 1'), findsOneWidget);
    });

    testWidgets('shows "1 of 15" for first of many matches', (tester) async {
      await pumpFindReplaceBar(tester, matchCount: 15, matchIndex: 0);
      expect(find.text('1 of 15'), findsOneWidget);
    });
  });

  group('FindReplaceBar replace row', () {
    testWidgets('replace row hidden by default', (tester) async {
      await pumpFindReplaceBar(tester, isVisible: true);
      // Only one TextField (find input). Replace input should not be visible.
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows replace button after tapping expand', (tester) async {
      await pumpFindReplaceBar(tester, isVisible: true);
      // Tap the expand toggle.
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();
      // Now two TextFields should be visible (find + replace).
      expect(find.byType(TextField), findsNWidgets(2));
      // Replace hint should be visible.
      expect(find.text('Replace with'), findsOneWidget);
    });

    testWidgets('shows replace icons after expanding', (tester) async {
      await pumpFindReplaceBar(tester, isVisible: true);
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.find_replace), findsOneWidget);
      expect(find.byIcon(Icons.find_replace_outlined), findsOneWidget);
    });

    testWidgets('toggle collapses replace row', (tester) async {
      await pumpFindReplaceBar(tester, isVisible: true);
      // Expand.
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
      // Collapse.
      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('FindReplaceBar callbacks', () {
    testWidgets('fires onClose when close button tapped', (tester) async {
      var closed = false;
      await pumpFindReplaceBar(tester, onClose: () => closed = true);
      await tester.tap(find.byIcon(Icons.close));
      expect(closed, isTrue);
    });

    testWidgets('fires onPrevious when previous button tapped', (tester) async {
      var prev = false;
      await pumpFindReplaceBar(tester, onPrevious: () => prev = true);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
      expect(prev, isTrue);
    });

    testWidgets('fires onNext when next button tapped', (tester) async {
      var next = false;
      await pumpFindReplaceBar(tester, onNext: () => next = true);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      expect(next, isTrue);
    });

    testWidgets('fires onReplace when replace button tapped', (tester) async {
      var replaced = false;
      await pumpFindReplaceBar(tester, onReplace: () => replaced = true);
      // First expand replace row.
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.find_replace));
      expect(replaced, isTrue);
    });

    testWidgets('fires onReplaceAll when replace all button tapped',
        (tester) async {
      var replacedAll = false;
      await pumpFindReplaceBar(tester, onReplaceAll: () => replacedAll = true);
      // First expand replace row.
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.find_replace_outlined));
      expect(replacedAll, isTrue);
    });

    testWidgets('fires onSearchChanged when text is entered', (tester) async {
      String? query;
      final controller = TextEditingController();
      addTearDown(() => controller.dispose());

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: FindReplaceBar(
              isVisible: true,
              searchTextController: controller,
              replaceTextController: TextEditingController(),
              matchIndex: -1,
              matchCount: 0,
              onSearchChanged: (q) => query = q,
              onPrevious: () {},
              onNext: () {},
              onReplace: () {},
              onReplaceAll: () {},
              onClose: () {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'hello');
      expect(query, 'hello');
    });
  });

  group('FindReplaceBar layout', () {
    testWidgets('uses Column layout', (tester) async {
      await pumpFindReplaceBar(tester, isVisible: true);
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('uses Row for find row', (tester) async {
      await pumpFindReplaceBar(tester, isVisible: true);
      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('uses compact visual density on buttons', (tester) async {
      await pumpFindReplaceBar(tester, isVisible: true);
      final iconButtons = tester.widgetList<IconButton>(
        find.byType(IconButton),
      );
      for (final button in iconButtons) {
        expect(button.visualDensity, VisualDensity.compact);
      }
    });
  });
}
