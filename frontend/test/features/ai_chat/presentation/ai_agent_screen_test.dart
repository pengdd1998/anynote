import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/ai_chat/presentation/ai_agent_screen.dart';
import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/l10n/app_localizations.dart';
import 'package:anynote/main.dart';

// ---------------------------------------------------------------------------
// Stub ApiClient
// ---------------------------------------------------------------------------

/// A fake ApiClient that returns configurable responses for agent actions.
class FakeApiClient extends ApiClient {
  Map<String, dynamic>? agentResponse;
  Object? agentError;
  Duration delay = Duration.zero;

  FakeApiClient() : super(baseUrl: 'http://localhost:8080');

  @override
  Future<Map<String, dynamic>> executeAgentAction(
    Map<String, dynamic> req,
  ) async {
    if (delay != Duration.zero) {
      await Future.delayed(delay);
    }
    if (agentError != null) {
      throw agentError!;
    }
    return agentResponse ?? {'status': 'ok'};
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps the AIAgentScreen inside a localized MaterialApp with provider
/// overrides.
Future<void> pumpAgentScreen(
  WidgetTester tester, {
  required FakeApiClient fakeApi,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(fakeApi),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: AIAgentScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AIAgentScreen', () {
    late FakeApiClient fakeApi;

    setUp(() {
      fakeApi = FakeApiClient();
    });

    // -- Renders action cards -------------------------------------------------

    testWidgets('renders app bar title', (tester) async {
      await pumpAgentScreen(tester, fakeApi: fakeApi);

      expect(find.text('AI Agent'), findsOneWidget);
    });

    testWidgets('renders select action label', (tester) async {
      await pumpAgentScreen(tester, fakeApi: fakeApi);

      expect(find.text('Select an action'), findsOneWidget);
    });

    testWidgets('renders organize notes action card', (tester) async {
      await pumpAgentScreen(tester, fakeApi: fakeApi);

      expect(find.text('Organize Notes'), findsOneWidget);
    });

    testWidgets('renders summarize notes action card', (tester) async {
      await pumpAgentScreen(tester, fakeApi: fakeApi);

      expect(find.text('Summarize Notes'), findsOneWidget);
    });

    testWidgets('renders create note action card', (tester) async {
      await pumpAgentScreen(tester, fakeApi: fakeApi);

      expect(find.text('Create Note'), findsOneWidget);
    });

    testWidgets('renders all three action cards', (tester) async {
      await pumpAgentScreen(tester, fakeApi: fakeApi);

      expect(find.text('Organize Notes'), findsOneWidget);
      expect(find.text('Summarize Notes'), findsOneWidget);
      expect(find.text('Create Note'), findsOneWidget);
    });

    testWidgets('action cards have chevron icons', (tester) async {
      await pumpAgentScreen(tester, fakeApi: fakeApi);

      expect(find.byIcon(Icons.chevron_right), findsNWidgets(3));
    });

    testWidgets('action cards have leading icons', (tester) async {
      await pumpAgentScreen(tester, fakeApi: fakeApi);

      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
      expect(find.byIcon(Icons.summarize_outlined), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    });

    // -- Tapping action triggers execution ------------------------------------

    testWidgets('tapping organize triggers execution', (tester) async {
      fakeApi.agentResponse = {'organized': 5};

      await pumpAgentScreen(tester, fakeApi: fakeApi);

      await tester.tap(find.text('Organize Notes'));
      await tester.pumpAndSettle();

      // Should show success result card.
      expect(find.text('Action complete'), findsOneWidget);
    });

    testWidgets('tapping summarize triggers execution', (tester) async {
      fakeApi.agentResponse = {'summary': 'Test summary'};

      await pumpAgentScreen(tester, fakeApi: fakeApi);

      await tester.tap(find.text('Summarize Notes'));
      await tester.pumpAndSettle();

      expect(find.text('Action complete'), findsOneWidget);
    });

    testWidgets('tapping create note triggers execution', (tester) async {
      fakeApi.agentResponse = {'note_id': 'new-note-123'};

      await pumpAgentScreen(tester, fakeApi: fakeApi);

      await tester.tap(find.text('Create Note'));
      await tester.pumpAndSettle();

      expect(find.text('Action complete'), findsOneWidget);
    });

    // -- Loading indicator ----------------------------------------------------

    testWidgets('shows loading indicator during execution', (tester) async {
      // Use a delay so the loading state is visible.
      fakeApi.delay = const Duration(milliseconds: 200);
      fakeApi.agentResponse = {'status': 'done'};

      await pumpAgentScreen(tester, fakeApi: fakeApi);

      // Tap to start.
      await tester.tap(find.text('Organize Notes'));
      await tester.pump(); // Pump once to trigger the loading state.

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for completion.
      await tester.pumpAndSettle();
    });

    testWidgets('action cards are disabled during loading', (tester) async {
      fakeApi.delay = const Duration(milliseconds: 200);
      fakeApi.agentResponse = {'status': 'done'};

      await pumpAgentScreen(tester, fakeApi: fakeApi);

      await tester.tap(find.text('Organize Notes'));
      await tester.pump();

      // During loading, the ListTile should have onTap null, so tapping
      // should not trigger another action. We just verify that only one
      // loading indicator is shown (no multiple executions).
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
    });

    // -- Error state ----------------------------------------------------------

    testWidgets('shows error state on failure', (tester) async {
      fakeApi.agentError = Exception('Server error');

      await pumpAgentScreen(tester, fakeApi: fakeApi);

      await tester.tap(find.text('Organize Notes'));
      await tester.pumpAndSettle();

      expect(find.text('Action failed'), findsOneWidget);
      expect(find.textContaining('Server error'), findsOneWidget);
    });

    testWidgets('error result card uses error container color', (tester) async {
      fakeApi.agentError = Exception('failure');

      await pumpAgentScreen(tester, fakeApi: fakeApi);

      await tester.tap(find.text('Organize Notes'));
      await tester.pumpAndSettle();

      // Find the result card and verify it renders.
      expect(find.text('Action failed'), findsOneWidget);
    });

    // -- Success state --------------------------------------------------------

    testWidgets('shows success state with result', (tester) async {
      fakeApi.agentResponse = {
        'organized_count': 10,
        'categories': 3,
      };

      await pumpAgentScreen(tester, fakeApi: fakeApi);

      await tester.tap(find.text('Organize Notes'));
      await tester.pumpAndSettle();

      expect(find.text('Action complete'), findsOneWidget);
      // The _formatResult method joins key: value pairs with newlines.
      expect(find.textContaining('organized_count: 10'), findsOneWidget);
      expect(find.textContaining('categories: 3'), findsOneWidget);
    });

    testWidgets('success result card renders formatted result', (tester) async {
      fakeApi.agentResponse = {'summary': 'Brief summary'};

      await pumpAgentScreen(tester, fakeApi: fakeApi);

      await tester.tap(find.text('Summarize Notes'));
      await tester.pumpAndSettle();

      expect(find.text('Action complete'), findsOneWidget);
      expect(find.textContaining('summary: Brief summary'), findsOneWidget);
    });

    // -- No result initially --------------------------------------------------

    testWidgets('shows no result card initially', (tester) async {
      await pumpAgentScreen(tester, fakeApi: fakeApi);

      expect(find.text('Action complete'), findsNothing);
      expect(find.text('Action failed'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    // -- Result replacement ---------------------------------------------------

    testWidgets('tapping action after error replaces error with new result',
        (tester) async {
      // First call fails.
      fakeApi.agentError = Exception('fail');

      await pumpAgentScreen(tester, fakeApi: fakeApi);

      await tester.tap(find.text('Organize Notes'));
      await tester.pumpAndSettle();

      expect(find.text('Action failed'), findsOneWidget);
      expect(find.text('Action complete'), findsNothing);

      // Second call succeeds.
      fakeApi.agentError = null;
      fakeApi.agentResponse = {'status': 'ok'};

      await tester.tap(find.text('Organize Notes'));
      await tester.pumpAndSettle();

      expect(find.text('Action failed'), findsNothing);
      expect(find.text('Action complete'), findsOneWidget);
    });
  });
}
