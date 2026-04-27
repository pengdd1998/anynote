import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/tts/speech_service.dart';
import 'package:anynote/features/notes/presentation/widgets/tts_player_bar.dart';
import 'package:anynote/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pump the [TtsPlayerBar] inside a localized [MaterialApp].
///
/// The [speechService] is injected via the provider override. The bar is
/// only visible when the speech state is not [SpeechState.stopped], so tests
/// must set the state before pumping or after an initial pump.
Future<void> pumpTtsPlayerBar(
  WidgetTester tester, {
  required SpeechService speechService,
  List<Override> extraOverrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        speechServiceProvider.overrideWithValue(speechService),
        ...extraOverrides,
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: Scaffold(
          body: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [TtsPlayerBar()],
          ),
        ),
      ),
    ),
  );

  // Let the stream providers resolve.
  await tester.pump(const Duration(milliseconds: 100));
}

/// Start speech and pump so the bar becomes visible.
Future<void> startSpeech(
  WidgetTester tester,
  SpeechService speechService,
) async {
  speechService.speak('Hello world this is a test paragraph.');
  await tester.pump(const Duration(milliseconds: 100));
}

/// Stop speech, dispose the widget tree, and pump to flush pending timers.
/// Must be called at the end of every test that started speech.
Future<void> cleanupSpeech(
  WidgetTester tester,
  SpeechService speechService,
) async {
  speechService.stop();
  await tester.pumpWidget(Container());
  await tester.pump(const Duration(milliseconds: 100));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TtsPlayerBar', () {
    late SpeechService speechService;

    setUp(() {
      speechService = SpeechService();
    });

    tearDown(() {
      speechService.dispose();
    });

    testWidgets('is hidden when speech state is stopped', (tester) async {
      await pumpTtsPlayerBar(tester, speechService: speechService);

      // When stopped, the TtsPlayerBar returns SizedBox.shrink().
      expect(find.byIcon(Icons.stop), findsNothing);
      expect(find.byIcon(Icons.play_circle_filled), findsNothing);
    });

    testWidgets('shows stop button when playing', (tester) async {
      await pumpTtsPlayerBar(tester, speechService: speechService);
      await startSpeech(tester, speechService);

      expect(find.byIcon(Icons.stop), findsOneWidget);

      await cleanupSpeech(tester, speechService);
    });

    testWidgets('shows pause icon when playing', (tester) async {
      await pumpTtsPlayerBar(tester, speechService: speechService);
      await startSpeech(tester, speechService);

      expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget);

      await cleanupSpeech(tester, speechService);
    });

    testWidgets('shows play icon when paused', (tester) async {
      await pumpTtsPlayerBar(tester, speechService: speechService);
      await startSpeech(tester, speechService);

      speechService.pause();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);

      await cleanupSpeech(tester, speechService);
    });

    testWidgets('tapping stop calls speechService.stop', (tester) async {
      await pumpTtsPlayerBar(tester, speechService: speechService);
      await startSpeech(tester, speechService);

      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump(const Duration(milliseconds: 100));

      expect(speechService.state, equals(SpeechState.stopped));
      // After stop the bar hides, so stop icon is gone.
      expect(find.byIcon(Icons.stop), findsNothing);

      // No need for cleanupSpeech since stop was already called.
      await tester.pumpWidget(Container());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('tapping pause calls speechService.pause', (tester) async {
      await pumpTtsPlayerBar(tester, speechService: speechService);
      await startSpeech(tester, speechService);

      expect(speechService.state, equals(SpeechState.playing));

      await tester.tap(find.byIcon(Icons.pause_circle_filled));
      await tester.pump(const Duration(milliseconds: 100));

      expect(speechService.state, equals(SpeechState.paused));

      await cleanupSpeech(tester, speechService);
    });

    testWidgets('tapping play icon when paused calls speechService.resume',
        (tester) async {
      await pumpTtsPlayerBar(tester, speechService: speechService);
      await startSpeech(tester, speechService);

      speechService.pause();
      await tester.pump(const Duration(milliseconds: 100));
      expect(speechService.state, equals(SpeechState.paused));

      await tester.tap(find.byIcon(Icons.play_circle_filled));
      await tester.pump(const Duration(milliseconds: 100));
      expect(speechService.state, equals(SpeechState.playing));

      await cleanupSpeech(tester, speechService);
    });

    testWidgets('renders speed chip with default rate', (tester) async {
      await pumpTtsPlayerBar(tester, speechService: speechService);
      await startSpeech(tester, speechService);

      // The chip label and the rate display text both show "1.0x".
      expect(find.text('1.0x'), findsWidgets);

      await cleanupSpeech(tester, speechService);
    });

    testWidgets('renders progress bar when playing', (tester) async {
      await pumpTtsPlayerBar(tester, speechService: speechService);
      await startSpeech(tester, speechService);

      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await cleanupSpeech(tester, speechService);
    });

    testWidgets('speed selector popup shows rate options', (tester) async {
      await pumpTtsPlayerBar(tester, speechService: speechService);
      await startSpeech(tester, speechService);

      await tester.tap(find.byType(Chip));
      await tester.pumpAndSettle();

      expect(find.text('0.5x'), findsOneWidget);
      expect(find.text('0.75x'), findsOneWidget);
      expect(find.text('1.0x'), findsWidgets);
      expect(find.text('1.25x'), findsOneWidget);
      expect(find.text('1.5x'), findsOneWidget);
      expect(find.text('2.0x'), findsOneWidget);

      await cleanupSpeech(tester, speechService);
    });

    testWidgets('stop button has correct tooltip', (tester) async {
      await pumpTtsPlayerBar(tester, speechService: speechService);
      await startSpeech(tester, speechService);

      expect(find.byTooltip('Stop Reading'), findsOneWidget);

      await cleanupSpeech(tester, speechService);
    });

    testWidgets('play/pause button has correct tooltip when playing',
        (tester) async {
      await pumpTtsPlayerBar(tester, speechService: speechService);
      await startSpeech(tester, speechService);

      expect(find.byTooltip('Pause'), findsOneWidget);

      await cleanupSpeech(tester, speechService);
    });

    testWidgets('play/pause button has correct tooltip when paused',
        (tester) async {
      await pumpTtsPlayerBar(tester, speechService: speechService);
      await startSpeech(tester, speechService);

      speechService.pause();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byTooltip('Resume'), findsOneWidget);

      await cleanupSpeech(tester, speechService);
    });
  });
}
