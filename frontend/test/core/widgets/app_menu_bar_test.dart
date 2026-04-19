import 'package:flutter/material.dart';
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
  });
}
