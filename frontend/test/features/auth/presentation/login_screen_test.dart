import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/auth/presentation/login_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('LoginScreen', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const LoginScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
