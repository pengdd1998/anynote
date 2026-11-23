import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/tts/speech_service.dart';

import '../../helpers/fake_tts_engine.dart';

/// Completes when [service] next reports [state]. Subscribe it before the
/// call that causes the change: a broadcast stream keeps nothing for late
/// listeners.
Future<void> nextState(SpeechService service, SpeechState state) =>
    service.stateStream
        .firstWhere((s) => s == state)
        .timeout(const Duration(seconds: 5));

/// Starts [service] on [text] and waits until it is actually speaking. The
/// engine is initialised first, so the playing state is not there the
/// moment `speak` returns — and `speak` itself only returns when speech
/// ends.
Future<void> speakUntilPlaying(SpeechService service, String text) async {
  final playing = nextState(service, SpeechState.playing);
  service.speak(text);
  await playing;
}

void main() {
  // The service talks to the flutter_tts plugin over a platform channel,
  // which needs the test binding to exist.
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTtsEngine engine;

  setUp(() {
    engine = FakeTtsEngine()..install();
  });

  tearDown(() {
    engine.uninstall();
  });

  // ===========================================================================
  // SpeechState
  // ===========================================================================

  group('SpeechState', () {
    test('has three enum values', () {
      expect(SpeechState.values.length, 3);
    });

    test('contains stopped, playing, paused', () {
      expect(SpeechState.values, contains(SpeechState.stopped));
      expect(SpeechState.values, contains(SpeechState.playing));
      expect(SpeechState.values, contains(SpeechState.paused));
    });
  });

  // ===========================================================================
  // SpeechService -- basic state
  // ===========================================================================

  group('SpeechService initial state', () {
    late SpeechService service;

    setUp(() {
      service = SpeechService();
    });

    tearDown(() {
      service.dispose();
    });

    test('initial state is stopped', () {
      expect(service.state, SpeechState.stopped);
    });

    test('isAvailable returns a bool', () {
      // kIsWeb is false in test environment.
      expect(service.isAvailable, isA<bool>());
    });

    test('stateStream is a broadcast stream', () {
      // Should be able to listen multiple times on broadcast stream.
      final sub1 = service.stateStream.listen((_) {});
      final sub2 = service.stateStream.listen((_) {});

      sub1.cancel();
      sub2.cancel();
    });

    test('progressStream is a broadcast stream', () {
      final sub1 = service.progressStream.listen((_) {});
      final sub2 = service.progressStream.listen((_) {});

      sub1.cancel();
      sub2.cancel();
    });
  });

  // ===========================================================================
  // SpeechService -- speak / stop lifecycle
  // ===========================================================================

  group('SpeechService speak and stop', () {
    late SpeechService service;

    setUp(() {
      service = SpeechService();
    });

    tearDown(() {
      service.dispose();
    });

    test('stop on fresh service sets state to stopped', () {
      service.stop();

      expect(service.state, SpeechState.stopped);
    });

    test('stop resets progress to 0.0', () async {
      final progressValues = <double>[];
      final sub = service.progressStream.listen(progressValues.add);

      service.stop();
      await pumpEventQueue();

      expect(progressValues, contains(0.0));

      await sub.cancel();
    });

    test('speak with empty string does not change state', () async {
      await service.speak('');

      expect(service.state, SpeechState.stopped);
    });

    test('speak with whitespace-only string does not change state', () async {
      await service.speak('   \n\n  ');

      expect(service.state, SpeechState.stopped);
    });

    test('speak emits playing state', () async {
      final states = <SpeechState>[];
      final sub = service.stateStream.listen(states.add);

      await speakUntilPlaying(service, 'Hello world ' * 100);

      expect(states, contains(SpeechState.playing));

      service.stop();
      await sub.cancel();
    });

    test('speak asks the engine to read the text', () async {
      await speakUntilPlaying(service, 'Hello world');

      expect(engine.spokenTexts, ['Hello world']);

      service.stop();
    });

    test('stop emits stopped state', () async {
      final states = <SpeechState>[];
      final sub = service.stateStream.listen(states.add);

      await speakUntilPlaying(service, 'Hello world ' * 100);
      final stopped = nextState(service, SpeechState.stopped);
      service.stop();
      await stopped;

      expect(states.last, SpeechState.stopped);

      await sub.cancel();
    });

    test('stop ends the utterance without moving on to the next paragraph',
        () async {
      await speakUntilPlaying(service, 'First paragraph\n\nSecond paragraph');
      service.stop();
      await pumpEventQueue();

      // The loop that awaited the stopped utterance must not read on.
      expect(engine.spokenTexts, hasLength(1));
    });
  });

  // ===========================================================================
  // SpeechService -- pause / resume
  // ===========================================================================

  group('SpeechService pause and resume', () {
    late SpeechService service;

    setUp(() {
      service = SpeechService();
    });

    tearDown(() {
      service.dispose();
    });

    test('pause on stopped service does nothing', () async {
      await service.pause();

      expect(service.state, SpeechState.stopped);
    });

    test('pause transitions from playing to paused', () async {
      await speakUntilPlaying(service, 'Hello world ' * 100);
      await service.pause();

      expect(service.state, SpeechState.paused);

      service.stop();
    });

    test('resume on stopped service does nothing', () async {
      await service.resume();

      expect(service.state, SpeechState.stopped);
    });

    test('resume transitions from paused to playing', () async {
      final states = <SpeechState>[];
      final sub = service.stateStream.listen(states.add);

      await speakUntilPlaying(service, 'Hello world ' * 100);
      await service.pause();
      // Not awaited: resume only returns when the paragraph has been read.
      service.resume();
      await pumpEventQueue();

      expect(service.state, SpeechState.playing);
      expect(
          states,
          containsAllInOrder(
              [SpeechState.playing, SpeechState.paused, SpeechState.playing]));

      service.stop();
      await sub.cancel();
    });

    test('pause when already paused does nothing', () async {
      await speakUntilPlaying(service, 'Hello world ' * 100);
      await service.pause();
      await service.pause();

      expect(service.state, SpeechState.paused);

      service.stop();
    });

    test('resume replays the current paragraph', () async {
      await speakUntilPlaying(service, 'Read me once');
      await service.pause();
      service.resume();
      await pumpEventQueue();

      // flutter_tts has no imperative continue, so the paragraph is read
      // again from its start.
      expect(engine.spokenTexts, ['Read me once', 'Read me once']);

      service.stop();
    });
  });

  // ===========================================================================
  // SpeechService -- paragraph splitting
  // ===========================================================================

  group('SpeechService paragraph splitting', () {
    late SpeechService service;

    setUp(() {
      service = SpeechService();
    });

    tearDown(() {
      service.dispose();
    });

    test('speak handles single-line text', () async {
      final states = <SpeechState>[];
      final sub = service.stateStream.listen(states.add);

      await speakUntilPlaying(service, 'Short text');

      // Starting to speak first stops whatever was before, so "stopped"
      // comes before "playing".
      expect(states.last, SpeechState.playing);

      service.stop();
      await sub.cancel();
    });

    test('reading a single paragraph to its end stops by itself', () async {
      final stopped = service.stateStream
          .firstWhere((s) => s == SpeechState.stopped)
          .timeout(const Duration(seconds: 5));
      await speakUntilPlaying(service, 'Short text');

      engine.finishUtterance();
      await stopped;

      expect(service.state, SpeechState.stopped);
    });

    test(
        'speak reads the paragraphs in order and reports progress between them',
        () async {
      final progress = <double>[];
      final sub = service.progressStream.listen(progress.add);

      await speakUntilPlaying(
        service,
        '${'Para one ' * 50}\n\n${'Para two ' * 50}',
      );
      expect(engine.spokenTexts, hasLength(1));

      engine.finishUtterance();
      await pumpEventQueue();

      expect(progress, contains(0.5));
      expect(engine.spokenTexts, hasLength(2));
      expect(engine.spokenTexts.last, startsWith('Para two'));
      expect(service.state, SpeechState.playing);

      service.stop();
      await sub.cancel();
    });
  });

  // ===========================================================================
  // SpeechService -- setRate
  // ===========================================================================

  group('SpeechService setRate', () {
    late SpeechService service;

    setUp(() {
      service = SpeechService();
    });

    tearDown(() {
      service.dispose();
    });

    test('setRate does not throw', () async {
      await service.setRate(1.0);
    });

    test('setRate accepts various values', () async {
      await service.setRate(0.5);
      await service.setRate(1.0);
      await service.setRate(2.0);
    });

    test('setRate reaches the engine once there is one', () async {
      await speakUntilPlaying(service, 'Hello world');
      await service.setRate(1.5);

      final rates = engine.calls
          .where((c) => c.method == 'setSpeechRate')
          .map((c) => c.arguments as double)
          .toList();
      // The service maps its 0.5–2.0 scale onto the platform's: 1.0 is
      // normal speed on every platform.
      expect(rates.last, rates.first * 1.5);

      service.stop();
    });
  });

  // ===========================================================================
  // SpeechService -- dispose
  // ===========================================================================

  group('SpeechService dispose', () {
    test('dispose while speaking leaves nothing running', () async {
      final service = SpeechService();

      await speakUntilPlaying(service, 'Hello world ' * 100);

      service.dispose();

      // Stopping the engine makes the pending utterance return; the loop that
      // awaited it must exit instead of writing to the closed streams, which
      // would surface as an uncaught "Cannot add new events after calling
      // close".
      await pumpEventQueue();

      expect(service.stateStream, isA<Stream<SpeechState>>());
    });

    test('calling dispose twice does not throw', () {
      final service = SpeechService();
      service.dispose();

      // Second dispose should not crash.
      // StreamController.close on already-closed is a no-op.
      expect(() => service.dispose(), returnsNormally);
    });
  });

  // ===========================================================================
  // SpeechService providers
  // ===========================================================================

  group('SpeechService providers', () {
    test('speechServiceProvider creates a SpeechService', () {
      // Verify the provider exists and has the right type.
      expect(speechServiceProvider, isNotNull);
    });

    test('speechStateProvider exists', () {
      expect(speechStateProvider, isNotNull);
    });
  });
}
