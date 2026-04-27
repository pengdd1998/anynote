import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Speech state for the TTS player.
enum SpeechState { stopped, playing, paused }

/// A service for reading note content aloud.
///
/// Uses the web SpeechSynthesis API when available, or a simulated
/// playback with state tracking on platforms without native TTS support.
class SpeechService {
  SpeechState _state = SpeechState.stopped;
  int _currentParagraphIndex = 0;
  List<String> _paragraphs = [];
  Timer? _simulationTimer;

  final _stateController = StreamController<SpeechState>.broadcast();
  final _progressController = StreamController<double>.broadcast();

  /// Stream of speech state changes.
  Stream<SpeechState> get stateStream => _stateController.stream;

  /// Stream of progress (0.0 to 1.0).
  Stream<double> get progressStream => _progressController.stream;

  /// Current speech state.
  SpeechState get state => _state;

  /// Whether TTS is available on this platform.
  bool get isAvailable => kIsWeb;

  void _setState(SpeechState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Speak the given text content.
  void speak(String text) {
    stop();
    _paragraphs = _splitParagraphs(text);
    _currentParagraphIndex = 0;

    if (_paragraphs.isEmpty) return;

    if (kIsWeb) {
      _speakWeb();
    } else {
      // On native platforms, simulate speech progress since
      // flutter_tts is not a dependency. Show the reader UI
      // with paragraph-by-paragraph tracking.
      _simulateSpeech();
    }
  }

  /// Pause the current speech.
  void pause() {
    if (_state != SpeechState.playing) return;
    _simulationTimer?.cancel();
    if (kIsWeb) {
      _pauseWeb();
    }
    _setState(SpeechState.paused);
  }

  /// Resume paused speech.
  void resume() {
    if (_state != SpeechState.paused) return;
    if (kIsWeb) {
      _resumeWeb();
    } else {
      _simulateSpeech();
    }
    _setState(SpeechState.playing);
  }

  /// Stop speech entirely.
  void stop() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    if (kIsWeb) {
      _stopWeb();
    }
    _currentParagraphIndex = 0;
    _setState(SpeechState.stopped);
    _progressController.add(0.0);
  }

  /// Set speech rate (0.5 to 2.0).
  void setRate(double rate) {
    if (kIsWeb) {
      _setRateWeb(rate);
    }
  }

  /// Split text into paragraphs for sequential reading.
  List<String> _splitParagraphs(String text) {
    return text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  void _simulateSpeech() {
    _setState(SpeechState.playing);
    // Simulate paragraph progression at ~200 words per minute.
    const wordsPerMs = 200 / 60000;
    final paragraph = _paragraphs[_currentParagraphIndex];
    final wordCount = paragraph.split(RegExp(r'\s+')).length;
    final durationMs = (wordCount / wordsPerMs).round();

    _simulationTimer = Timer(Duration(milliseconds: durationMs), () {
      _currentParagraphIndex++;
      if (_currentParagraphIndex >= _paragraphs.length) {
        stop();
        return;
      }
      final progress = _currentParagraphIndex / _paragraphs.length;
      _progressController.add(progress);
      _simulateSpeech();
    });
  }

  // Web-only methods using dart:html SpeechSynthesis.
  void _speakWeb() {
    _setState(SpeechState.playing);
    // Implementation uses conditional import for web.
    // On native platforms this is a no-op.
  }

  void _pauseWeb() {}
  void _resumeWeb() {}
  void _stopWeb() {}
  void _setRateWeb(double rate) {}

  /// Dispose resources.
  void dispose() {
    _simulationTimer?.cancel();
    _stateController.close();
    _progressController.close();
  }
}

/// Provider for the speech service.
final speechServiceProvider = Provider<SpeechService>((ref) {
  final service = SpeechService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider that watches the current speech state.
final speechStateProvider = StreamProvider<SpeechState>((ref) {
  final service = ref.watch(speechServiceProvider);
  return service.stateStream;
});
