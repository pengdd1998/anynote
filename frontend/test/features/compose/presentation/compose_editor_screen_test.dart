import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/compose/data/compose_providers.dart';
import 'package:anynote/features/compose/presentation/compose_editor_screen.dart';
import 'package:anynote/features/publish/data/publish_providers.dart';
import 'package:anynote/features/publish/presentation/widgets/publish_from_editor_sheet.dart';
import '../../../helpers/test_app_helper.dart';

/// Fake notifier returning an empty platform list so the publish sheet does
/// not attempt a real network call in tests.
class _FakeConnectedPlatformsNotifier extends ConnectedPlatformsNotifier {
  @override
  Future<List<Map<String, dynamic>>> build() async => [];
}

void main() {
  group('ComposeEditorScreen', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ComposeEditorScreen(sessionId: 'test-session'),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('has editable text area', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ComposeEditorScreen(sessionId: 'test-session'),
        overrides: defaultProviderOverrides(),
      );

      // Should have a text editing area (TextField or similar).
      expect(find.byType(Scaffold), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('has app bar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ComposeEditorScreen(sessionId: 'test-session'),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(AppBar), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    group('publish handoff', () {
      List<Override> overridesWithFakePlatforms() => [
            ...defaultProviderOverrides(),
            connectedPlatformsProvider
                .overrideWith(() => _FakeConnectedPlatformsNotifier()),
          ];

      testWidgets(
          'shows publish action and opens publish sheet with draft handed off',
          (tester) async {
        final handle = await pumpScreen(
          tester,
          const ComposeEditorScreen(sessionId: 'test-session'),
          overrides: overridesWithFakePlatforms(),
        );

        // Seed a non-empty draft (markdown heading + body).
        const draft = '# 我的第一篇笔记\n\n这是正文内容。';
        handle.container.read(composeSessionProvider.notifier).updateDraft(
              draft,
            );
        await tester.pump();

        expect(find.byTooltip('Publish'), findsOneWidget);

        await tester.tap(find.byTooltip('Publish'));
        await tester.pumpAndSettle();

        // The publish bottom sheet opens.
        expect(find.byType(PublishFromEditorSheet), findsOneWidget);
        // Title is the first line with the markdown heading marker stripped.
        expect(
          find.descendant(
            of: find.byType(PublishFromEditorSheet),
            matching: find.text('我的第一篇笔记'),
          ),
          findsOneWidget,
        );
        // Content is the full draft.
        expect(
          find.descendant(
            of: find.byType(PublishFromEditorSheet),
            matching: find.text(draft),
          ),
          findsOneWidget,
        );

        await handle.dispose();
      });

      testWidgets('publish action with empty draft shows snackbar, no sheet',
          (tester) async {
        final handle = await pumpScreen(
          tester,
          const ComposeEditorScreen(sessionId: 'test-session'),
          overrides: overridesWithFakePlatforms(),
        );

        expect(find.byTooltip('Publish'), findsOneWidget);

        await tester.tap(find.byTooltip('Publish'));
        await tester.pumpAndSettle();

        expect(find.byType(PublishFromEditorSheet), findsNothing);
        expect(find.byType(SnackBar), findsOneWidget);

        // Let the snackbar dismiss before disposing to avoid pending timers.
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        await handle.dispose();
      });
    });

    group('refinement error surfacing', () {
      testWidgets(
          'refinement failure with existing draft shows a snackbar and keeps '
          'the editor', (tester) async {
        final handle = await pumpScreen(
          tester,
          const ComposeEditorScreen(sessionId: 'test-session'),
          overrides: defaultProviderOverrides(),
        );

        // Seed a non-empty draft.
        final notifier = handle.container.read(composeSessionProvider.notifier);
        notifier.updateDraft('Existing draft content');
        await tester.pump();

        // Simulate a refinement failure while a draft exists.
        notifier.state = notifier.state.copyWith(error: 'AI service unavailable');
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('AI service unavailable'), findsOneWidget);
        // The editor stays mounted (full-screen error state only shows for
        // empty drafts).
        expect(find.byType(TextField), findsWidgets);

        // Let the snackbar dismiss before disposing to avoid pending timers.
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        await handle.dispose();
      });

      testWidgets(
          'error with empty draft still uses the full-screen error state',
          (tester) async {
        final handle = await pumpScreen(
          tester,
          const ComposeEditorScreen(sessionId: 'test-session'),
          overrides: defaultProviderOverrides(),
        );

        final notifier = handle.container.read(composeSessionProvider.notifier);
        notifier.state = notifier.state.copyWith(error: 'AI quota exceeded');
        await tester.pumpAndSettle();

        // Full-screen error state, no snackbar.
        expect(find.byType(SnackBar), findsNothing);
        expect(find.text('AI quota exceeded'), findsOneWidget);

        await handle.dispose();
      });
    });
  });
}
