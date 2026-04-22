import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/widgets/keyboard_shortcuts.dart';

void main() {
  group('Intents', () {
    test('NewNoteIntent is an Intent', () {
      expect(const NewNoteIntent(), isA<Intent>());
    });

    test('SaveIntent is an Intent', () {
      expect(const SaveIntent(), isA<Intent>());
    });

    test('SearchIntent is an Intent', () {
      expect(const SearchIntent(), isA<Intent>());
    });

    test('ToggleSidebarIntent is an Intent', () {
      expect(const ToggleSidebarIntent(), isA<Intent>());
    });

    test('ExportPdfIntent is an Intent', () {
      expect(const ExportPdfIntent(), isA<Intent>());
    });

    test('OpenSettingsIntent is an Intent', () {
      expect(const OpenSettingsIntent(), isA<Intent>());
    });

    test('CloseNoteIntent is an Intent', () {
      expect(const CloseNoteIntent(), isA<Intent>());
    });

    test('NextNoteIntent is an Intent', () {
      expect(const NextNoteIntent(), isA<Intent>());
    });

    test('ToggleFullScreenIntent is an Intent', () {
      expect(const ToggleFullScreenIntent(), isA<Intent>());
    });

    test('ExitZenOrDialogIntent is an Intent', () {
      expect(const ExitZenOrDialogIntent(), isA<Intent>());
    });
  });

  group('AppShortcuts', () {
    Future<void> pumpAppShortcuts(
      WidgetTester tester, {
      Widget? child,
      List<Override> overrides = const [],
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            home: Scaffold(
              body: AppShortcuts(
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders child widget', (tester) async {
      await pumpAppShortcuts(
        tester,
        child: const Text('Child Content'),
      );

      expect(find.text('Child Content'), findsOneWidget);
    });

    testWidgets('wraps child with Shortcuts widget', (tester) async {
      await pumpAppShortcuts(tester);

      expect(
        find.byWidgetPredicate((w) {
          if (w is! Shortcuts) return false;
          return w.shortcuts.values.any((i) => i is NewNoteIntent);
        }),
        findsOneWidget,
      );
    });

    testWidgets('wraps child with Actions widget', (tester) async {
      await pumpAppShortcuts(tester);

      expect(
        find.byWidgetPredicate((w) {
          if (w is! Actions) return false;
          return w.actions.containsKey(NewNoteIntent);
        }),
        findsOneWidget,
      );
    });

    testWidgets('Shortcuts and Actions are in correct order', (tester) async {
      // AppShortcuts builds Shortcuts > Actions > child.
      await pumpAppShortcuts(
        tester,
        child: const Text('Nested'),
      );

      // Find the Shortcuts widget
      final shortcutsFinder = find.byWidgetPredicate((w) {
        if (w is! Shortcuts) return false;
        return w.shortcuts.values.any((i) => i is NewNoteIntent);
      });
      expect(shortcutsFinder, findsOneWidget);

      // The Actions widget should be a descendant of Shortcuts.
      final actionsFinder = find.descendant(
        of: shortcutsFinder,
        matching: find.byType(Actions),
      );
      expect(actionsFinder, findsOneWidget);

      // The child text should be a descendant of Actions.
      expect(
        find.descendant(
          of: actionsFinder,
          matching: find.text('Nested'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('registers NewNoteIntent shortcut on non-macOS',
        (tester) async {
      await pumpAppShortcuts(tester);

      final shortcutsWidget = tester.widget<Shortcuts>(
        find.byWidgetPredicate((w) {
          if (w is! Shortcuts) return false;
          return w.shortcuts.values.any((i) => i is NewNoteIntent);
        }),
      );
      final shortcuts = shortcutsWidget.shortcuts;

      // On Linux test environment, modifier is Ctrl.
      final keySet = LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyN,
      );
      expect(shortcuts[keySet], isA<NewNoteIntent>());
    });

    testWidgets('registers SaveIntent shortcut', (tester) async {
      await pumpAppShortcuts(tester);

      final shortcutsWidget = tester.widget<Shortcuts>(
        find.byWidgetPredicate((w) {
          if (w is! Shortcuts) return false;
          return w.shortcuts.values.any((i) => i is NewNoteIntent);
        }),
      );
      final shortcuts = shortcutsWidget.shortcuts;

      final keySet = LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyS,
      );
      expect(shortcuts[keySet], isA<SaveIntent>());
    });

    testWidgets('registers SearchIntent shortcut', (tester) async {
      await pumpAppShortcuts(tester);

      final shortcutsWidget = tester.widget<Shortcuts>(
        find.byWidgetPredicate((w) {
          if (w is! Shortcuts) return false;
          return w.shortcuts.values.any((i) => i is NewNoteIntent);
        }),
      );
      final shortcuts = shortcutsWidget.shortcuts;

      final keySet = LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyF,
      );
      expect(shortcuts[keySet], isA<SearchIntent>());
    });

    testWidgets('registers ToggleSidebarIntent shortcut', (tester) async {
      await pumpAppShortcuts(tester);

      final shortcutsWidget = tester.widget<Shortcuts>(
        find.byWidgetPredicate((w) {
          if (w is! Shortcuts) return false;
          return w.shortcuts.values.any((i) => i is NewNoteIntent);
        }),
      );
      final shortcuts = shortcutsWidget.shortcuts;

      final keySet = LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyB,
      );
      expect(shortcuts[keySet], isA<ToggleSidebarIntent>());
    });

    testWidgets('registers ExportPdfIntent shortcut', (tester) async {
      await pumpAppShortcuts(tester);

      final shortcutsWidget = tester.widget<Shortcuts>(
        find.byWidgetPredicate((w) {
          if (w is! Shortcuts) return false;
          return w.shortcuts.values.any((i) => i is NewNoteIntent);
        }),
      );
      final shortcuts = shortcutsWidget.shortcuts;

      final keySet = LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyP,
      );
      expect(shortcuts[keySet], isA<ExportPdfIntent>());
    });

    testWidgets('registers OpenSettingsIntent shortcut', (tester) async {
      await pumpAppShortcuts(tester);

      final shortcutsWidget = tester.widget<Shortcuts>(
        find.byWidgetPredicate((w) {
          if (w is! Shortcuts) return false;
          return w.shortcuts.values.any((i) => i is NewNoteIntent);
        }),
      );
      final shortcuts = shortcutsWidget.shortcuts;

      final keySet = LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.comma,
      );
      expect(shortcuts[keySet], isA<OpenSettingsIntent>());
    });

    testWidgets('registers CloseNoteIntent shortcut', (tester) async {
      await pumpAppShortcuts(tester);

      final shortcutsWidget = tester.widget<Shortcuts>(
        find.byWidgetPredicate((w) {
          if (w is! Shortcuts) return false;
          return w.shortcuts.values.any((i) => i is NewNoteIntent);
        }),
      );
      final shortcuts = shortcutsWidget.shortcuts;

      final keySet = LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyW,
      );
      expect(shortcuts[keySet], isA<CloseNoteIntent>());
    });

    testWidgets('registers NextNoteIntent shortcut', (tester) async {
      await pumpAppShortcuts(tester);

      final shortcutsWidget = tester.widget<Shortcuts>(
        find.byWidgetPredicate((w) {
          if (w is! Shortcuts) return false;
          return w.shortcuts.values.any((i) => i is NewNoteIntent);
        }),
      );
      final shortcuts = shortcutsWidget.shortcuts;

      final keySet = LogicalKeySet(
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.tab,
      );
      expect(shortcuts[keySet], isA<NextNoteIntent>());
    });

    testWidgets('registers ToggleFullScreenIntent via F11', (tester) async {
      await pumpAppShortcuts(tester);

      final shortcutsWidget = tester.widget<Shortcuts>(
        find.byWidgetPredicate((w) {
          if (w is! Shortcuts) return false;
          return w.shortcuts.values.any((i) => i is NewNoteIntent);
        }),
      );
      final shortcuts = shortcutsWidget.shortcuts;

      final keySet = LogicalKeySet(LogicalKeyboardKey.f11);
      expect(shortcuts[keySet], isA<ToggleFullScreenIntent>());
    });

    testWidgets('registers ExitZenOrDialogIntent via Escape', (tester) async {
      await pumpAppShortcuts(tester);

      final shortcutsWidget = tester.widget<Shortcuts>(
        find.byWidgetPredicate((w) {
          if (w is! Shortcuts) return false;
          return w.shortcuts.values.any((i) => i is NewNoteIntent);
        }),
      );
      final shortcuts = shortcutsWidget.shortcuts;

      final keySet = LogicalKeySet(LogicalKeyboardKey.escape);
      expect(shortcuts[keySet], isA<ExitZenOrDialogIntent>());
    });

    testWidgets('all ten shortcuts are registered', (tester) async {
      await pumpAppShortcuts(tester);

      final shortcutsWidget = tester.widget<Shortcuts>(
        find.byWidgetPredicate((w) {
          if (w is! Shortcuts) return false;
          return w.shortcuts.values.any((i) => i is NewNoteIntent);
        }),
      );
      final shortcuts = shortcutsWidget.shortcuts;

      // 10 shortcuts: N, S, F, B, P, comma, W, Tab, F11, Escape.
      expect(shortcuts.length, 10);
    });
  });
}
