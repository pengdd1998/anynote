import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/compose/data/compose_providers.dart';
import 'package:anynote/features/compose/presentation/compose_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('ComposeScreen', () {
    List<Override> composeOverrides() => [
          ...defaultProviderOverrides(),
          notesForSelectionProvider
              .overrideWith((ref) => Stream.value([])),
          generatedContentsProvider
              .overrideWith((ref) => Stream.value([])),
        ];

    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ComposeScreen(),
        overrides: composeOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows AI Compose title', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ComposeScreen(),
        overrides: composeOverrides(),
      );

      expect(find.text('AI Compose'), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows AI-Powered Writing hero card', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ComposeScreen(),
        overrides: composeOverrides(),
      );

      expect(find.text('AI-Powered Writing'), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows Start Composing button', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ComposeScreen(),
        overrides: composeOverrides(),
      );

      expect(find.text('Start Composing'), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows No compositions yet when history is empty',
        (tester) async {
      final handle = await pumpScreen(
        tester,
        const ComposeScreen(),
        overrides: composeOverrides(),
      );

      expect(find.text('No compositions yet'), findsOneWidget);
      await handle.dispose();
    });
  });
}
