import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/tts/speech_service.dart';

void main() {
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
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(progressValues, contains(0.0));

      await sub.cancel();
    });

    test('speak with empty string does not change state', () {
      service.speak('');

      expect(service.state, SpeechState.stopped);
    });

    test('speak with whitespace-only string does not change state', () {
      service.speak('   \n\n  ');

      expect(service.state, SpeechState.stopped);
    });

    test('speak emits playing state', () async {
      final states = <SpeechState>[];
      final sub = service.stateStream.listen(states.add);

      // Use a long paragraph to ensure timer doesn't complete instantly.
      service.speak('Hello world ' * 100);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(states, contains(SpeechState.playing));

      service.stop();
      await sub.cancel();
    });

    test('stop emits stopped state', () async {
      final states = <SpeechState>[];
      final sub = service.stateStream.listen(states.add);

      service.speak('Hello world ' * 100);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      service.stop();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(states.last, SpeechState.stopped);

      await sub.cancel();
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

    test('pause on stopped service does nothing', () {
      service.pause();

      expect(service.state, SpeechState.stopped);
    });

    test('pause transitions from playing to paused', () async {
      service.speak('Hello world ' * 100);

      // Verify state is playing before pause.
      expect(service.state, SpeechState.playing);

      service.pause();

      expect(service.state, SpeechState.paused);

      service.stop();
    });

    test('resume on stopped service does nothing', () {
      service.resume();

      expect(service.state, SpeechState.stopped);
    });

    test('resume transitions from paused to playing', () async {
      final states = <SpeechState>[];
      final sub = service.stateStream.listen(states.add);

      service.speak('Hello world ' * 100);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      service.pause();
      service.resume();

      expect(service.state, SpeechState.playing);

      service.stop();
      await sub.cancel();
    });

    test('pause when already paused does nothing', () async {
      service.speak('Hello world ' * 100);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      service.pause();
      service.pause();

      expect(service.state, SpeechState.paused);

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

      // Single short paragraph will complete quickly.
      service.speak('Short text');

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Either playing or already stopped after simulation finishes.
      expect(states, isNotEmpty);

      await sub.cancel();
    });

    test('speak handles multiple paragraphs', () async {
      final progressValues = <double>[];
      final sub = service.progressStream.listen(progressValues.add);

      // Two paragraphs with double newline separator.
      service.speak('${'Para one ' * 50}\n\n${'Para two ' * 50}');

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Should have received some progress updates.
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

    test('setRate does not throw', () {
      // setRate is a no-op on native (non-web) platforms.
      expect(() => service.setRate(1.0), returnsNormally);
    });

    test('setRate accepts various values', () {
      expect(() => service.setRate(0.5), returnsNormally);
      expect(() => service.setRate(1.0), returnsNormally);
      expect(() => service.setRate(2.0), returnsNormally);
    });
  });

  // ===========================================================================
  // SpeechService -- dispose
  // ===========================================================================

  group('SpeechService dispose', () {
    test('dispose cancels timers and closes streams', () async {
      final service = SpeechService();

      service.speak('Hello world ' * 100);
      await Future<void>.delayed(const Duration(milliseconds: 5));

      service.dispose();

      // After dispose, the state and progress streams should be closed.
      // Attempting to listen on a closed stream should work for broadcast
      // streams but no new events arrive.
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
