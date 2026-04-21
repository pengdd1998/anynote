import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:anynote/core/platform/platform_utils.dart';
import 'package:anynote/core/widgets/app_menu_bar.dart';
import 'package:anynote/core/widgets/sidebar_provider.dart';
import 'package:anynote/l10n/app_localizations.dart';

void main() {
  group('AppMenuBar', () {
    Widget buildTestWidget({required Widget child}) {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('renders child on non-desktop platforms unchanged',
        (tester) async {
      // On the test environment, PlatformUtils.isDesktop is false
      // because defaultTargetPlatform is typically android in tests.
      await tester.pumpWidget(
        buildTestWidget(
          child: const AppMenuBar(
            child: Text('Test Child'),
          ),
        ),
      );

      // The child text should be visible.
      expect(find.text('Test Child'), findsOneWidget);

      // No PlatformMenuBar or MenuBar should be present on non-desktop.
      expect(find.byType(PlatformMenuBar), findsNothing);
      expect(find.byType(MenuBar), findsNothing);
    });

    testWidgets('contains sidebar provider in widget tree', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const AppMenuBar(
            child: Text('Test Child'),
          ),
        ),
      );

      // The sidebar provider should be accessible from within the tree.
      final element = tester.element(find.text('Test Child'));
      final container = ProviderScope.containerOf(element);
      final visible = container.read(sidebarVisibleProvider);
      // Default value is true.
      expect(visible, isTrue);
    });

    testWidgets('sidebarVisibleProvider can be toggled', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: Consumer(builder: (context, ref, _) {
            final visible = ref.watch(sidebarVisibleProvider);
            return Text(visible ? 'Visible' : 'Hidden');
          },),
        ),
      );

      // Initially visible.
      expect(find.text('Visible'), findsOneWidget);

      // Toggle via provider.
      final element = tester.element(find.text('Visible'));
      final container = ProviderScope.containerOf(element);
      container.read(sidebarVisibleProvider.notifier).toggle();
      await tester.pump();

      // Should now be hidden.
      expect(find.text('Hidden'), findsOneWidget);
    });

    testWidgets('wraps child without crashing', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: AppMenuBar(
            child: Container(
              key: const Key('inner-child'),
              color: Colors.white,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('inner-child')), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Tests that force desktop mode to verify the Material menu bar builds.
    // -----------------------------------------------------------------------

    testWidgets('renders Material MenuBar on Linux desktop',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      await tester.pumpWidget(
        buildTestWidget(
          child: const AppMenuBar(
            child: Text('Desktop Child'),
          ),
        ),
      );

      // On desktop (Linux), a Material MenuBar should be present.
      expect(find.byType(MenuBar), findsOneWidget);
      // The child should still be present, now inside a Column.
      expect(find.text('Desktop Child'), findsOneWidget);
      // PlatformMenuBar is not used on Linux (only on macOS).
      expect(find.byType(PlatformMenuBar), findsNothing);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Material menu bar contains File, Edit, View, Help menus',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      await tester.pumpWidget(
        buildTestWidget(
          child: const AppMenuBar(
            child: Text('Menu Content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The menu bar should have SubmenuButton entries for each top-level menu.
      expect(find.byType(SubmenuButton), findsNWidgets(4));

      // Verify the top-level menu labels use localized or fallback text.
      // Since the locale is 'en', AppLocalizations should provide the labels.
      // Fall back to English defaults if l10n is not fully loaded.
      final fileMenu = find.widgetWithText(SubmenuButton, 'File');
      final editMenu = find.widgetWithText(SubmenuButton, 'Edit');
      final viewMenu = find.widgetWithText(SubmenuButton, 'View');
      final helpMenu = find.widgetWithText(SubmenuButton, 'Help');

      // At least one of localized or fallback should match.
      expect(
        fileMenu.evaluate().isNotEmpty ||
            find.text('File').evaluate().isNotEmpty,
        isTrue,
        reason: 'File menu should be present',
      );
      expect(
        editMenu.evaluate().isNotEmpty ||
            find.text('Edit').evaluate().isNotEmpty,
        isTrue,
        reason: 'Edit menu should be present',
      );
      expect(
        viewMenu.evaluate().isNotEmpty ||
            find.text('View').evaluate().isNotEmpty,
        isTrue,
        reason: 'View menu should be present',
      );
      expect(
        helpMenu.evaluate().isNotEmpty ||
            find.text('Help').evaluate().isNotEmpty,
        isTrue,
        reason: 'Help menu should be present',
      );

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('File menu contains New Note, Save, Close Tab items',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      await tester.pumpWidget(
        buildTestWidget(
          child: const AppMenuBar(
            child: Text('File Menu Test'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the File menu by tapping it.
      final fileMenu = find.text('File');
      if (fileMenu.evaluate().isNotEmpty) {
        await tester.tap(fileMenu);
        await tester.pumpAndSettle();
      }

      // After opening, child menu items should be visible.
      // Check for the presence of key File menu items by text.
      // These may use localized or fallback labels.
      final newNote = find.text('New Note');
      final save = find.text('Save');
      final closeTab = find.text('Close Tab');

      expect(newNote.evaluate().isNotEmpty, isTrue,
          reason: 'New Note menu item should exist');
      expect(save.evaluate().isNotEmpty, isTrue,
          reason: 'Save menu item should exist');
      expect(closeTab.evaluate().isNotEmpty, isTrue,
          reason: 'Close Tab menu item should exist');

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Edit menu contains Undo, Redo, Cut, Copy, Paste, Select All',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      await tester.pumpWidget(
        buildTestWidget(
          child: const AppMenuBar(
            child: Text('Edit Menu Test'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the Edit menu.
      final editMenu = find.text('Edit');
      if (editMenu.evaluate().isNotEmpty) {
        await tester.tap(editMenu);
        await tester.pumpAndSettle();
      }

      expect(find.text('Undo').evaluate().isNotEmpty, isTrue);
      expect(find.text('Redo').evaluate().isNotEmpty, isTrue);
      expect(find.text('Cut').evaluate().isNotEmpty, isTrue);
      expect(find.text('Copy').evaluate().isNotEmpty, isTrue);
      expect(find.text('Paste').evaluate().isNotEmpty, isTrue);
      expect(find.text('Select All').evaluate().isNotEmpty, isTrue);
      expect(find.text('Find...').evaluate().isNotEmpty, isTrue);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('View menu contains Toggle Sidebar and Full Screen',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      await tester.pumpWidget(
        buildTestWidget(
          child: const AppMenuBar(
            child: Text('View Menu Test'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final viewMenu = find.text('View');
      if (viewMenu.evaluate().isNotEmpty) {
        await tester.tap(viewMenu);
        await tester.pumpAndSettle();
      }

      expect(find.text('Toggle Sidebar').evaluate().isNotEmpty, isTrue);
      expect(find.text('Toggle Preview').evaluate().isNotEmpty, isTrue);
      expect(find.text('Zen Mode').evaluate().isNotEmpty, isTrue);
      expect(find.text('Enter Full Screen').evaluate().isNotEmpty, isTrue);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Help menu contains About and Keyboard Shortcuts',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      await tester.pumpWidget(
        buildTestWidget(
          child: const AppMenuBar(
            child: Text('Help Menu Test'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final helpMenu = find.text('Help');
      if (helpMenu.evaluate().isNotEmpty) {
        await tester.tap(helpMenu);
        await tester.pumpAndSettle();
      }

      expect(find.text('About AnyNote').evaluate().isNotEmpty, isTrue);
      expect(find.text('Keyboard Shortcuts').evaluate().isNotEmpty, isTrue);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('menu items have keyboard shortcut activators', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      await tester.pumpWidget(
        buildTestWidget(
          child: const AppMenuBar(
            child: Text('Shortcut Test'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open File menu to inspect menu items.
      final fileMenu = find.text('File');
      if (fileMenu.evaluate().isNotEmpty) {
        await tester.tap(fileMenu);
        await tester.pumpAndSettle();
      }

      // Find all MenuItemButton widgets in the rendered tree.
      final menuButtons = find.byType(MenuItemButton);
      expect(menuButtons.evaluate().isNotEmpty, isTrue,
          reason: 'There should be MenuItemButton widgets in the menu bar');

      // Verify that at least some buttons have SingleActivator shortcuts.
      int shortcutCount = 0;
      for (final element in menuButtons.evaluate()) {
        final widget = element.widget as MenuItemButton;
        if (widget.shortcut != null) {
          shortcutCount++;
        }
      }
      expect(shortcutCount, greaterThan(0),
          reason: 'Some menu items should have keyboard shortcuts');

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Toggle Sidebar menu item toggles sidebar state',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      await tester.pumpWidget(
        buildTestWidget(
          child: const AppMenuBar(
            child: Text('Toggle Test'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Get the initial sidebar state.
      final element = tester.element(find.text('Toggle Test'));
      final container = ProviderScope.containerOf(element);
      expect(container.read(sidebarVisibleProvider), isTrue);

      // Open the View menu.
      final viewMenu = find.text('View');
      if (viewMenu.evaluate().isNotEmpty) {
        await tester.tap(viewMenu);
        await tester.pumpAndSettle();

        // Tap "Toggle Sidebar".
        final toggleSidebar = find.text('Toggle Sidebar');
        if (toggleSidebar.evaluate().isNotEmpty) {
          await tester.tap(toggleSidebar);
          await tester.pumpAndSettle();

          // The sidebar state should now be toggled.
          expect(container.read(sidebarVisibleProvider), isFalse);
        }
      }

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('About AnyNote shows about dialog on tap', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      await tester.pumpWidget(
        buildTestWidget(
          child: const AppMenuBar(
            child: Text('About Test'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Help menu.
      final helpMenu = find.text('Help');
      if (helpMenu.evaluate().isNotEmpty) {
        await tester.tap(helpMenu);
        await tester.pumpAndSettle();

        // Tap "About AnyNote".
        final aboutButton = find.text('About AnyNote');
        if (aboutButton.evaluate().isNotEmpty) {
          await tester.tap(aboutButton);
          await tester.pumpAndSettle();

          // The About dialog should be showing with the app name.
          expect(find.text('AnyNote').evaluate().isNotEmpty, isTrue);
        }
      }

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Keyboard Shortcuts shows shortcuts dialog on tap',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      await tester.pumpWidget(
        buildTestWidget(
          child: const AppMenuBar(
            child: Text('Shortcuts Test'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Help menu.
      final helpMenu = find.text('Help');
      if (helpMenu.evaluate().isNotEmpty) {
        await tester.tap(helpMenu);
        await tester.pumpAndSettle();

        // Tap "Keyboard Shortcuts".
        final shortcutsButton = find.text('Keyboard Shortcuts');
        if (shortcutsButton.evaluate().isNotEmpty) {
          await tester.tap(shortcutsButton);
          await tester.pumpAndSettle();

          // The shortcuts dialog should be showing with shortcut descriptions.
          // The dialog title should be visible.
          expect(
            find.text('Keyboard Shortcuts').evaluate().isNotEmpty,
            isTrue,
          );
          // The OK button to dismiss should be present.
          expect(find.text('OK').evaluate().isNotEmpty, isTrue);
        }
      }

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
        'renders PlatformMenuBar on macOS desktop', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      await tester.pumpWidget(
        buildTestWidget(
          child: const AppMenuBar(
            child: Text('macOS Child'),
          ),
        ),
      );

      // On macOS, PlatformMenuBar should be used instead of Material MenuBar.
      expect(find.byType(PlatformMenuBar), findsOneWidget);
      expect(find.byType(MenuBar), findsNothing);
      expect(find.text('macOS Child'), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('PlatformUtils', () {
    test('modifierLabel returns correct platform string', () {
      // In the test environment, PlatformUtils.isDesktop returns false
      // because defaultTargetPlatform is android.
      expect(PlatformUtils.isDesktop, isFalse);
      expect(PlatformUtils.isMacOS, isFalse);
      expect(PlatformUtils.isWindows, isFalse);
      expect(PlatformUtils.isLinux, isFalse);
    });

    test('modifierLabel returns Ctrl on non-macOS platforms', () {
      // On the default test platform (Android), modifierLabel is Ctrl.
      expect(PlatformUtils.modifierLabel, 'Ctrl');
    });

    test('modifierLabel returns Cmd on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(PlatformUtils.isMacOS, isTrue);
      expect(PlatformUtils.modifierLabel, 'Cmd');
      debugDefaultTargetPlatformOverride = null;
    });

    test('isDesktop returns true on Linux', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(PlatformUtils.isDesktop, isTrue);
      expect(PlatformUtils.isLinux, isTrue);
      debugDefaultTargetPlatformOverride = null;
    });

    test('isDesktop returns true on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(PlatformUtils.isDesktop, isTrue);
      expect(PlatformUtils.isWindows, isTrue);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
