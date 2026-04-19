import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/compose/data/compose_providers.dart';
import 'package:anynote/features/compose/presentation/outline_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('OutlineScreen', () {
    List<Override> outlineOverrides() => [
          ...defaultProviderOverrides(),
          composeSessionProvider.overrideWith((ref) {
            return _FakeOutlineSessionNotifier('test-session');
          }),
        ];

    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const OutlineScreen(sessionId: 'test-session'),
        overrides: outlineOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows Outline title in app bar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const OutlineScreen(sessionId: 'test-session'),
        overrides: outlineOverrides(),
      );

      expect(find.text('Outline'), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows back button', (tester) async {
      final handle = await pumpScreen(
        tester,
        const OutlineScreen(sessionId: 'test-session'),
        overrides: outlineOverrides(),
      );

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      await handle.dispose();
    });
  });
}

/// Fake compose session notifier that returns a default state with no outline.
class _FakeOutlineSessionNotifier extends ComposeSessionNotifier {
  _FakeOutlineSessionNotifier(String sessionId) : super(_FakeRef(), sessionId);

  @override
  ComposeSessionState get state => const ComposeSessionState(
        sessionId: 'test-session',
      );
}

/// Minimal fake Ref for wiring the notifier.
class _FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
