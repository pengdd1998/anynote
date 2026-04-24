import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

      // Tap the submit button without filling the form.
      final submitButton = find.byType(ElevatedButton);
      if (submitButton.evaluate().isNotEmpty) {
        await tester.tap(submitButton.first);
        await tester.pumpAndSettle();

        // Validation messages should appear.
        expect(find.textContaining('required'), findsWidgets);
      }

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('has text fields for email and mnemonic', (tester) async {
      final handle = await pumpScreen(
        tester,
        const RecoveryScreen(),
        overrides: defaultProviderOverrides(),
      );

      // Should find at least 2 text fields (email + mnemonic).
      final textFields = find.byType(TextFormField);
      expect(textFields, findsAtLeast(2));

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
