import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/auth/presentation/register_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('RegisterScreen', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const RegisterScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
