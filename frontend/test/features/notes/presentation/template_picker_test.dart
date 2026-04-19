import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/template_picker.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('TemplatePicker', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        TemplatePicker(onSelected: (_) {}),
        overrides: defaultProviderOverrides(),
      );

      // TemplatePicker renders a Column, not a Scaffold.
      expect(find.byType(Column), findsWidgets);
      await handle.dispose();
    });

    testWidgets('shows tab labels', (tester) async {
      final handle = await pumpScreen(
        tester,
        TemplatePicker(onSelected: (_) {}),
        overrides: defaultProviderOverrides(),
      );

      expect(find.text('Built-in'), findsOneWidget);
      expect(find.text('My Templates'), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows close button', (tester) async {
      final handle = await pumpScreen(
        tester,
        TemplatePicker(onSelected: (_) {}),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
      await handle.dispose();
    });
  });
}
