import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/settings/data/api_models.dart';
import 'package:anynote/features/settings/data/settings_providers.dart';
import 'package:anynote/features/settings/presentation/llm_config_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('LLMConfigScreen', () {
    List<Override> llmOverrides() => [
          ...defaultProviderOverrides(),
          llmConfigsProvider.overrideWith(() => _FakeLLMConfigsNotifier()),
        ];

    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const LLMConfigScreen(),
        overrides: llmOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}

/// Fake LLM configs notifier that returns an empty list.
class _FakeLLMConfigsNotifier extends LlmConfigsNotifier {
  @override
  Future<List<LlmConfig>> build() async => [];
}
