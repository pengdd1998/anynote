import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/theme/app_icons.dart';
import 'package:anynote/features/settings/data/api_models.dart';
import 'package:anynote/features/settings/data/settings_providers.dart';
import 'package:anynote/features/settings/presentation/llm_config_screen.dart';
import '../../../helpers/test_app_helper.dart';

LlmConfig _seededConfig({
  String id = 'cfg-1',
  String name = 'My GPT',
  bool isDefault = false,
}) =>
    LlmConfig(
      id: id,
      name: name,
      provider: 'openai',
      baseUrl: 'https://api.openai.com/v1',
      model: 'gpt-4o',
      isDefault: isDefault,
      maxTokens: 4096,
      temperature: 0.7,
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );

void main() {
  group('LLMConfigScreen', () {
    List<Override> llmOverrides({
      List<LlmConfig> seeded = const [],
      _FakeLLMConfigsNotifier? notifier,
    }) {
      final fake = notifier ?? _FakeLLMConfigsNotifier(seeded);
      return [
        ...defaultProviderOverrides(),
        llmConfigsProvider.overrideWith(() => fake),
      ];
    }

    testWidgets('renders without errors (empty state with privacy note)',
        (tester) async {
      final handle = await pumpScreen(
        tester,
        const LLMConfigScreen(),
        overrides: llmOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      // Privacy note is visible in the empty state.
      expect(find.textContaining('never uploaded'), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('renders a seeded local config with the privacy note',
        (tester) async {
      final handle = await pumpScreen(
        tester,
        const LLMConfigScreen(),
        overrides: llmOverrides(seeded: [_seededConfig()]),
      );

      expect(find.text('My GPT'), findsOneWidget);
      expect(find.text('openai - gpt-4o'), findsOneWidget);
      expect(find.textContaining('never uploaded'), findsOneWidget);
      // Non-default config offers the "set as default" action.
      expect(find.byIcon(AppIcons.starOutline), findsOneWidget);

      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('tapping set-as-default hits the local notifier',
        (tester) async {
      final fake = _FakeLLMConfigsNotifier([_seededConfig()]);
      final handle = await pumpScreen(
        tester,
        const LLMConfigScreen(),
        overrides: llmOverrides(notifier: fake),
      );

      await tester.tap(find.byIcon(AppIcons.starOutline));
      await tester.pump();

      expect(fake.setDefaultCalls, ['cfg-1']);
      expect(find.byType(SnackBar), findsOneWidget);

      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('tapping test connection calls the client-direct test',
        (tester) async {
      final fake = _FakeLLMConfigsNotifier([_seededConfig()]);
      final handle = await pumpScreen(
        tester,
        const LLMConfigScreen(),
        overrides: llmOverrides(notifier: fake),
      );

      await tester.tap(find.byIcon(AppIcons.wifiTethering));
      // The "Testing connection..." snackbar (3s) queues ahead of the
      // result snackbar; advance far enough for both to cycle.
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));

      expect(fake.testCalls, ['cfg-1']);
      expect(find.textContaining('Connection successful'), findsOneWidget);

      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('default config shows the default badge and no star action',
        (tester) async {
      final handle = await pumpScreen(
        tester,
        const LLMConfigScreen(),
        overrides: llmOverrides(seeded: [_seededConfig(isDefault: true)]),
      );

      expect(find.text('Default'), findsOneWidget);
      expect(find.byIcon(AppIcons.starOutline), findsNothing);

      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}

/// Fake LLM configs notifier backed by seeded local configs, recording
/// local actions instead of touching secure storage.
class _FakeLLMConfigsNotifier extends LlmConfigsNotifier {
  _FakeLLMConfigsNotifier(this.seeded);

  final List<LlmConfig> seeded;
  final List<String> setDefaultCalls = [];
  final List<String> testCalls = [];

  @override
  Future<List<LlmConfig>> build() async => seeded;

  @override
  Future<void> setDefault(String id) async {
    setDefaultCalls.add(id);
  }

  @override
  Future<void> test(String id) async {
    testCalls.add(id);
  }
}
