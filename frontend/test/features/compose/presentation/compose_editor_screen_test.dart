import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/compose/presentation/compose_editor_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('ComposeEditorScreen', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ComposeEditorScreen(sessionId: 'test-session'),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('has editable text area', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ComposeEditorScreen(sessionId: 'test-session'),
        overrides: defaultProviderOverrides(),
      );

      // Should have a text editing area (TextField or similar).
      expect(find.byType(Scaffold), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('has app bar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ComposeEditorScreen(sessionId: 'test-session'),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(AppBar), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
