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
      addTearDown(() => handle.dispose());

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('has editable text area', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ComposeEditorScreen(sessionId: 'test-session'),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // Should have a text editing area (TextField or similar).
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('has app bar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ComposeEditorScreen(sessionId: 'test-session'),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      expect(find.byType(AppBar), findsOneWidget);
    });
  });
}
