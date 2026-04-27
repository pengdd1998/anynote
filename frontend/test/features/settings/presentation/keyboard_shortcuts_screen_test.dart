import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/settings/presentation/keyboard_shortcuts_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('KeyboardShortcutsScreen', () {
    testWidgets('renders without errors', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const KeyboardShortcutsScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows app bar with keyboard shortcuts title', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const KeyboardShortcutsScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      expect(find.text('Keyboard Shortcuts'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows General and Editor category headers', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const KeyboardShortcutsScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // General and Editor headers should be visible in the viewport.
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Editor'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows Ctrl+N shortcut for new note', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const KeyboardShortcutsScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // On Linux (test environment), modifier is Ctrl.
      // Use exact text match to avoid substring matching Ctrl+Shift+N etc.
      expect(find.text('Ctrl+N'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows shortcut descriptions visible in viewport',
        (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const KeyboardShortcutsScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // Verify some shortcut descriptions are present (those in the viewport).
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows Ctrl+S and Ctrl+F as exact shortcut texts',
        (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const KeyboardShortcutsScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // Use exact text matching to avoid substring issues.
      expect(find.text('Ctrl+S'), findsOneWidget);
      expect(find.text('Ctrl+F'), findsOneWidget);
      expect(find.text('Ctrl+K'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows Escape shortcut', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const KeyboardShortcutsScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      expect(find.text('Esc'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('renders shortcuts in a scrollable list', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const KeyboardShortcutsScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // The entire body should be a ListView.
      expect(find.byType(ListView), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('Navigation shortcuts visible after scrolling', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const KeyboardShortcutsScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // Scroll down to find the Navigation category header and shortcuts.
      await tester.scrollUntilVisible(
        find.text('Navigation'),
        200,
        scrollable: find.byType(Scrollable),
      );

      expect(find.text('Navigation'), findsOneWidget);
      expect(find.text('Alt+Left'), findsOneWidget);
      expect(find.text('Alt+Right'), findsOneWidget);

      await handle.dispose();
    });
  });
}
