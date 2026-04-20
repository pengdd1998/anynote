import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/settings/presentation/import_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('ImportScreen', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ImportScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('has app bar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ImportScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows import format options', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ImportScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // Should show the list view with format options.
      expect(find.byType(ListView), findsOneWidget);
    });
  });
}
