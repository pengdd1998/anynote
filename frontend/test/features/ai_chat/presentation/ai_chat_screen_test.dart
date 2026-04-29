import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/features/ai_chat/data/ai_chat_repository.dart';
import 'package:anynote/features/ai_chat/presentation/ai_chat_screen.dart';
import 'package:anynote/features/ai_chat/providers/ai_chat_providers.dart';
import 'package:anynote/features/compose/data/ai_repository.dart' as compose;
import '../../../helpers/test_app_helper.dart';

void main() {
  group('AiChatScreen', () {
    List<Override> chatOverrides() => [
          ...defaultProviderOverrides(),
          // Pre-set the session ID so initState does not modify a provider
          // during the build cycle.
          chatSessionIdProvider.overrideWith((ref) => 'test-session-id'),
          // Override startChatSessionProvider to return a no-op function that
          // does not write to chatSessionIdProvider (avoids the Riverpod
          // "modify during build" error).
          startChatSessionProvider
              .overrideWith((ref) => () => 'test-session-id'),
          // Provide a fake AI repository that returns empty responses.
          compose.aiRepositoryProvider
              .overrideWith((ref) => _FakeAIRepository()),
          aiChatRepositoryProvider.overrideWith((ref) =>
              AIChatRepository(ref.read(compose.aiRepositoryProvider)),),
        ];

    /// Pump the AiChatScreen with all required overrides.
    ///
    /// The AiChatScreen's dispose() calls ref.read(chatSessionProvider.notifier)
    /// which fails after the widget is unmounted. To avoid this, we pre-cancel
    /// the notifier in a tearDown step before the handle disposes.
    Future<TestAppHandle> pumpChatScreen(WidgetTester tester) async {
      final handle = await pumpScreen(
        tester,
        const AiChatScreen(),
        overrides: chatOverrides(),
      );
      addTearDown(() async {
        // Cancel the notifier while the widget is still mounted to prevent
        // the dispose() method from reading a disposed ref.
        try {
          handle.container.read(chatSessionProvider.notifier).cancel();
        } catch (_) {
          // Notifier may already be cancelled.
        }
        await handle.dispose();
      });
      return handle;
    }

    testWidgets('renders without errors', (tester) async {
      await pumpChatScreen(tester);

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows AI Chat Assistant title in app bar', (tester) async {
      await pumpChatScreen(tester);

      expect(find.text('AI Chat Assistant'), findsOneWidget);
    });

    testWidgets('shows empty state when no messages', (tester) async {
      await pumpChatScreen(tester);

      // Should show the welcome empty state.
      expect(find.text('Ask me anything about your notes'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    });

    testWidgets('shows message input field', (tester) async {
      await pumpChatScreen(tester);

      // Should show the input field with hint text.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Type your message...'), findsOneWidget);
    });

    testWidgets('shows send button', (tester) async {
      await pumpChatScreen(tester);

      // The send icon button should be present.
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('shows new chat button in app bar', (tester) async {
      await pumpChatScreen(tester);

      expect(find.byIcon(Icons.add_comment_outlined), findsOneWidget);
    });

    testWidgets('shows context notes button in app bar', (tester) async {
      await pumpChatScreen(tester);

      expect(find.byIcon(Icons.note_add_outlined), findsOneWidget);
    });

    testWidgets('entering text and tapping send triggers message',
        (tester) async {
      await pumpChatScreen(tester);

      // Enter text in the input field.
      await tester.enterText(
        find.byType(TextField),
        'What are my notes about?',
      );
      await tester.pump();

      // Tap the send button.
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      // After sending, the input field should be cleared.
      // The user's message text should appear in a message bubble.
      expect(find.text('What are my notes about?'), findsWidgets);
    });

    testWidgets('tapping new chat does not crash', (tester) async {
      await pumpChatScreen(tester);

      // Tap the new chat button -- should not throw.
      await tester.tap(find.byIcon(Icons.add_comment_outlined));
      await tester.pumpAndSettle();

      // The screen should still be rendered.
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// Fake AI repository
// ---------------------------------------------------------------------------

/// A fake AIRepository that returns empty responses without network calls.
class _FakeAIRepository extends compose.AIRepository {
  _FakeAIRepository() : super(ApiClient(baseUrl: 'http://localhost:8080'));

  @override
  Future<String> chat(
    List<compose.ChatMessage> messages, {
    String? model,
    CancelToken? cancelToken,
  }) async {
    return 'This is a fake AI response.';
  }

  @override
  Stream<String> chatStream(
    List<compose.ChatMessage> messages, {
    String? model,
    CancelToken? cancelToken,
  }) async* {
    yield 'This is a fake AI response.';
  }
}
