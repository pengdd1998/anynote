import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/auth/presentation/onboarding_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('OnboardingScreen', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const OnboardingScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows Skip button', (tester) async {
      final handle = await pumpScreen(
        tester,
        const OnboardingScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.text('Skip'), findsWidgets);
      await handle.dispose();
    });

    testWidgets('shows Next button on first page', (tester) async {
      final handle = await pumpScreen(
        tester,
        const OnboardingScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.text('Next'), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows shield icon on first page', (tester) async {
      final handle = await pumpScreen(
        tester,
        const OnboardingScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      await handle.dispose();
    });
  });
}
