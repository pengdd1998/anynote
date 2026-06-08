import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/features/compose/data/ai_repository.dart';
import 'package:anynote/features/notes/presentation/widgets/translation_sheet.dart';
import 'package:anynote/l10n/app_localizations.dart';
import 'package:anynote/main.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A minimal fake ApiClient for testing (avoids network calls).
final _fakeApiClient = ApiClient(baseUrl: 'http://localhost:8080');

/// Fake AI repository that immediately yields translated text.
class _ImmediateAIRepository extends AIRepository {
  final String _translatedText;

  _ImmediateAIRepository(this._translatedText) : super(_fakeApiClient);

  @override
  Future<String> chat(
    List<ChatMessage> messages, {
    String? model,
    CancelToken? cancelToken,
  }) async {
    return _translatedText;
  }

  @override
  Stream<String> chatStream(
    List<ChatMessage> messages, {
    String? model,
    CancelToken? cancelToken,
  }) {
    // Use Stream.value so the stream completes synchronously after yielding
    // one element, avoiding the need for microtask resolution in tests.
    return Stream.value(_translatedText);
  }

  @override
  Future<Map<String, dynamic>> getQuota() async => {};
}

/// Fake AI repository that throws an error.
class _ErrorAIRepository extends AIRepository {
  final String _errorMessage;

  _ErrorAIRepository(this._errorMessage) : super(_fakeApiClient);

  @override
  Future<String> chat(
    List<ChatMessage> messages, {
    String? model,
    CancelToken? cancelToken,
  }) async {
    throw Exception(_errorMessage);
  }

  @override
  Stream<String> chatStream(
    List<ChatMessage> messages, {
    String? model,
    CancelToken? cancelToken,
  }) {
    // Use Stream.error so the error is delivered and the stream closes,
    // allowing the await-for loop to exit promptly in tests.
    return Stream.error(Exception(_errorMessage));
  }

  @override
  Future<Map<String, dynamic>> getQuota() async => {};
}

/// Fake AI repository that yields after a delay (simulates loading state).
/// Exposes a [StreamController] that must be closed via [dispose] in
/// test teardown so that the production `.timeout()` timer is cleaned up.
class _LoadingAIRepository extends AIRepository {
  final StreamController<String> _controller = StreamController<String>();

  _LoadingAIRepository() : super(_fakeApiClient);

  /// Close the stream to allow pending timers to resolve.
  Future<void> dispose() => _controller.close();

  @override
  Future<String> chat(
    List<ChatMessage> messages, {
    String? model,
    CancelToken? cancelToken,
  }) async {
    await _controller.stream.drain();
    return '';
  }

  @override
  Stream<String> chatStream(
    List<ChatMessage> messages, {
    String? model,
    CancelToken? cancelToken,
  }) {
    return _controller.stream;
  }

  @override
  Future<Map<String, dynamic>> getQuota() async => {};
}

/// Pump the [TranslationSheet] inside a localized [MaterialApp] with the
/// sheet shown via showModalBottomSheet.
Future<void> pumpTranslationSheet(
  WidgetTester tester, {
  String text = 'Hello world',
  void Function(String)? onReplace,
  void Function(String)? onInsertBelow,
  AIRepository? aiRepo,
}) async {
  final repo = aiRepo ?? _ImmediateAIRepository('Translated');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(_fakeApiClient),
        aiRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => TranslationSheet(
                      text: text,
                      onReplace: onReplace ?? (_) {},
                      onInsertBelow: onInsertBelow ?? (_) {},
                    ),
                  );
                },
                child: const Text('Open Sheet'),
              );
            },
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open Sheet'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TranslationSheet', () {
    testWidgets('renders AI Translation header', (tester) async {
      await pumpTranslationSheet(tester);
      expect(find.text('AI Translation'), findsOneWidget);
    });

    testWidgets('renders language selector dropdown', (tester) async {
      await pumpTranslationSheet(tester);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets('shows Translate button', (tester) async {
      await pumpTranslationSheet(tester);
      expect(find.text('Translate'), findsOneWidget);
    });

    testWidgets('shows close button', (tester) async {
      await pumpTranslationSheet(tester);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('shows source text placeholder before translation',
        (tester) async {
      await pumpTranslationSheet(tester);
      expect(
        find.text('Translation will appear here...'),
        findsOneWidget,
      );
    });

    testWidgets('shows translate icon in header', (tester) async {
      await pumpTranslationSheet(tester);
      expect(find.byIcon(Icons.translate), findsOneWidget);
    });

    testWidgets('renders "Translate to:" label', (tester) async {
      await pumpTranslationSheet(tester);
      expect(find.text('Translate to:'), findsOneWidget);
    });

    testWidgets('language selector shows English by default', (tester) async {
      await pumpTranslationSheet(tester);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('Translate button is enabled in initial state', (tester) async {
      await pumpTranslationSheet(tester);
      final translateButton = find.widgetWithText(FilledButton, 'Translate');
      expect(translateButton, findsOneWidget);
      final buttonWidget = tester.widget<FilledButton>(translateButton);
      expect(buttonWidget.onPressed, isNotNull);
    });

    testWidgets('shows translated text after clicking Translate',
        (tester) async {
      await pumpTranslationSheet(
        tester,
        aiRepo: _ImmediateAIRepository('Bonjour le monde'),
      );

      // Tap the Translate button to trigger the translation.
      await tester.tap(find.text('Translate'));
      // The production code uses `await for` on a streaming response.
      // runAsync lets the microtask queue flush so the stream completes,
      // then pump rebuilds the widget tree with the updated state.
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();

      expect(find.text('Bonjour le monde'), findsOneWidget);
      // Action buttons should appear when translation is done.
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Replace'), findsOneWidget);
      expect(find.text('Insert Below'), findsOneWidget);
    });

    testWidgets('shows loading indicator during translation', (tester) async {
      final loadingRepo = _LoadingAIRepository();

      await pumpTranslationSheet(
        tester,
        aiRepo: loadingRepo,
      );

      // Tap the Translate button to trigger translation.
      await tester.tap(find.text('Translate'));
      await tester.pump(const Duration(milliseconds: 100));

      // A CircularProgressIndicator should be visible while loading.
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Close the stream to exit the await-for loop cleanly.
      await loadingRepo.dispose();
      // Pump to let the stream completion propagate through the notifier.
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }
    });

    testWidgets('shows error state on translation failure', (tester) async {
      await pumpTranslationSheet(
        tester,
        aiRepo: _ErrorAIRepository('Network error: connection refused'),
      );

      // Tap the Translate button to trigger the error.
      await tester.tap(find.text('Translate'));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();

      expect(
        find.textContaining('Network error: connection refused'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('Replace button calls onReplace callback', (tester) async {
      String? replacedText;
      await pumpTranslationSheet(
        tester,
        aiRepo: _ImmediateAIRepository('Translated text here'),
        onReplace: (t) => replacedText = t,
      );

      // Trigger translation.
      await tester.tap(find.text('Translate'));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();

      await tester.tap(find.text('Replace'));
      await tester.pump();

      expect(replacedText, 'Translated text here');
    });

    testWidgets('Insert Below button calls onInsertBelow callback',
        (tester) async {
      String? insertedText;
      await pumpTranslationSheet(
        tester,
        aiRepo: _ImmediateAIRepository('Inserted translation'),
        onInsertBelow: (t) => insertedText = t,
      );

      // Trigger translation.
      await tester.tap(find.text('Translate'));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();

      await tester.tap(find.text('Insert Below'));
      await tester.pump();

      expect(insertedText, 'Inserted translation');
    });
  });
}
