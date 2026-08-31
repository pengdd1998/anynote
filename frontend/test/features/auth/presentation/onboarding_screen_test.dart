import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/theme/app_icons.dart';
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

    testWidgets('shows circular next button on first page', (tester) async {
      final handle = await pumpScreen(
        tester,
        const OnboardingScreen(),
        overrides: defaultProviderOverrides(),
      );

      // The mockup replaces the text button with a circular arrow button.
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows sticky-note mascot with pencil on first page',
        (tester) async {
      final handle = await pumpScreen(
        tester,
        const OnboardingScreen(),
        overrides: defaultProviderOverrides(),
      );

      // Page 1 shows the sticky-note mascot with an overlapping pencil.
      expect(find.byIcon(AppIcons.edit), findsOneWidget);
      await handle.dispose();
    });
  });
}
