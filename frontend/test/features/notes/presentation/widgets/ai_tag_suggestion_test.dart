import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/features/compose/data/ai_repository.dart';
import 'package:anynote/features/notes/presentation/widgets/ai_tag_suggestion.dart';

import '../../../../helpers/test_app_helper.dart';

// ---------------------------------------------------------------------------
// Fake AIRepository
// ---------------------------------------------------------------------------

/// A fake AIRepository that hangs forever on chat() so loading state persists.
class _FakeAIRepository extends AIRepository {
  final Completer<String> _completer = Completer<String>();

  _FakeAIRepository() : super(ApiClient(baseUrl: 'http://localhost:8080'));

  @override
  Future<String> chat(
    List<ChatMessage> messages, {
    String? model,
    CancelToken? cancelToken,
  }) {
    return _completer.future;
  }
}

void main() {
  group('AiTagSuggestionSheet', () {
    testWidgets('renders with initial empty state', (tester) async {
      final handle = await pumpScreen(
        tester,
        AiTagSuggestionSheet(
          content: 'Test content',
          onApply: (_) {},
        ),
        overrides: defaultProviderOverrides(),
      );

      expect(find.text('AI Tag Suggestion'), findsOneWidget);
      expect(
        find.text(
          'Tap "Suggest" to let AI analyze your note and recommend tags.',
        ),
        findsOneWidget,
      );

      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows suggest button when no tags loaded', (tester) async {
      final handle = await pumpScreen(
        tester,
        AiTagSuggestionSheet(
          content: 'Test content',
          onApply: (_) {},
        ),
        overrides: defaultProviderOverrides(),
      );

      expect(find.text('Suggest'), findsOneWidget);

      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows loading state when suggesting', (tester) async {
      final handle = await pumpScreen(
        tester,
        AiTagSuggestionSheet(
          content: 'Test content for tag suggestion',
          onApply: (_) {},
        ),
        overrides: [
          ...defaultProviderOverrides(),
          aiRepositoryProvider.overrideWithValue(_FakeAIRepository()),
        ],
      );

      // Tap suggest button
      await tester.tap(find.text('Suggest'));
      await tester.pump();

      // Show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Analyzing content...'), findsOneWidget);

      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('can dismiss via close button', (tester) async {
      final handle = await pumpScreen(
        tester,
        AiTagSuggestionSheet(
          content: 'Test content',
          onApply: (_) {},
        ),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Sheet should be dismissed
      expect(find.text('AI Tag Suggestion'), findsNothing);

      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('JSON Array Parser', () {
    /// Test helper function that mirrors the private _parseSimpleJsonArray.
    List<String> parseSimpleJsonArray(String json) {
      final inner = json.substring(1, json.length - 1);
      if (inner.trim().isEmpty) return [];

      final tags = <String>[];
      final buffer = StringBuffer();
      bool inString = false;

      for (int i = 0; i < inner.length; i++) {
        final ch = inner[i];
        if (ch == '"' && (i == 0 || inner[i - 1] != '\\')) {
          inString = !inString;
          if (!inString && buffer.isNotEmpty) {
            tags.add(buffer.toString().trim());
            buffer.clear();
          }
        } else if (inString) {
          buffer.write(ch);
        }
      }

      return tags;
    }

    test('parses valid JSON array', () {
      final result = parseSimpleJsonArray('["tag1", "tag2", "tag3"]');
      expect(result, ['tag1', 'tag2', 'tag3']);
    });

    test('handles empty array', () {
      final result = parseSimpleJsonArray('[]');
      expect(result, isEmpty);
    });

    test('handles single tag', () {
      final result = parseSimpleJsonArray('["single-tag"]');
      expect(result, ['single-tag']);
    });

    test('handles tags with spaces', () {
      final result = parseSimpleJsonArray('["tag one", "tag two"]');
      expect(result, ['tag one', 'tag two']);
    });

    test('handles mixed case tags', () {
      final result = parseSimpleJsonArray('["Productivity", "meeting-notes"]');
      expect(result, ['Productivity', 'meeting-notes']);
    });
  });
}
