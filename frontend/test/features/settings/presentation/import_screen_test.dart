import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/settings/presentation/import_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('ImportScreen', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ImportScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('has app bar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ImportScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(AppBar), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows import format options', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ImportScreen(),
        overrides: defaultProviderOverrides(),
      );

      // Should show the list view with format options.
      expect(find.byType(ListView), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
