import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/compose/data/compose_providers.dart';
import 'package:anynote/features/compose/presentation/cluster_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('ClusterScreen', () {
    List<Override> clusterOverrides() => [
          ...defaultProviderOverrides(),
          composeSessionProvider.overrideWith((ref) {
            return _FakeComposeSessionNotifier('test-session');
          }),
        ];

    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ClusterScreen(sessionId: 'test-session'),
        overrides: clusterOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows Note Clusters title in app bar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ClusterScreen(sessionId: 'test-session'),
        overrides: clusterOverrides(),
      );

      expect(find.text('Note Clusters'), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows back button', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ClusterScreen(sessionId: 'test-session'),
        overrides: clusterOverrides(),
      );

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      await handle.dispose();
    });
  });
}

/// Fake compose session notifier that returns a default empty state.
class _FakeComposeSessionNotifier extends ComposeSessionNotifier {
  _FakeComposeSessionNotifier(String sessionId) : super(_FakeRef(), sessionId);

  @override
  ComposeSessionState get state => ComposeSessionState(
        sessionId: 'test-session',
        selectedNoteIds: ['note-1'],
        noteContents: {'note-1': 'Some content'},
        topic: 'Test Topic',
      );
}

/// Minimal fake Ref for wiring the notifier.
class _FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
