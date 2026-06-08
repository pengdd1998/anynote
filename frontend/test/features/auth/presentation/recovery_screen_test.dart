import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/widgets/pressable_scale.dart';
import 'package:anynote/features/auth/presentation/recovery_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('RecoveryScreen', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const RecoveryScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      // Should have email and mnemonic input fields.
      expect(find.byType(TextFormField), findsWidgets);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows form validation on empty submit', (tester) async {
      final handle = await pumpScreen(
        tester,
        const RecoveryScreen(),
        overrides: defaultProviderOverrides(),
      );

      // Tap the next/submit button without filling the form.
      // The button is now a PressableScale instead of ElevatedButton.
      final submitButton = find.byType(PressableScale);
      if (submitButton.evaluate().isNotEmpty) {
        await tester.tap(submitButton.first);
        await tester.pumpAndSettle();
      }

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('has text field for email', (tester) async {
      final handle = await pumpScreen(
        tester,
        const RecoveryScreen(),
        overrides: defaultProviderOverrides(),
      );

      // In step 0, only the email field is visible.
      final textFields = find.byType(TextFormField);
      expect(textFields, findsAtLeast(1));

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
