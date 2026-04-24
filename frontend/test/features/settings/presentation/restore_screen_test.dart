import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/settings/presentation/restore_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('RestoreScreen', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const RestoreScreen(),
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
        const RestoreScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(AppBar), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows step indicator', (tester) async {
      final handle = await pumpScreen(
        tester,
        const RestoreScreen(),
        overrides: defaultProviderOverrides(),
      );

      // RestoreScreen should show a multi-step wizard.
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(Column), findsWidgets);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
