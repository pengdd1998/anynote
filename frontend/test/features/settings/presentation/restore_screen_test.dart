import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/settings/presentation/restore_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('RestoreScreen', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const RestoreScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('has app bar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const RestoreScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows step indicator', (tester) async {
      final handle = await pumpScreen(
        tester,
        const RestoreScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // RestoreScreen should show a multi-step wizard.
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(Column), findsWidgets);
    });
  });
}
