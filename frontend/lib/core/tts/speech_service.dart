import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Speech state for the TTS player.
enum SpeechState { stopped, playing, paused }

/// A service for reading note content aloud.
///
/// Native platforms use flutter_tts (Android/iOS system engines); web uses
/// the browser SpeechSynthesis API via flutter_tts' web implementation.
/// Paragraphs are spoken sequentially with per-paragraph progress reporting,
/// matching the reader UI's highlight model.
class SpeechService {
  SpeechState _state = SpeechState.stopped;
  int _currentParagraphIndex = 0;
  List<String> _paragraphs = [];
  FlutterTts? _tts;
  double _rate = 1.0;

  /// Generation token for the paragraph-speaking loop: speak/stop/resume
  /// bump it so a stale loop (e.g. its await hung on a paused utterance)
  /// exits instead of racing the new sequence.
  int _speakToken = 0;

  final _stateController = StreamController<SpeechState>.broadcast();
  final _progressController = StreamController<double>.broadcast();

  /// Stream of speech state changes.
  Stream<SpeechState> get stateStream => _stateController.stream;

  /// Stream of progress (0.0 to 1.0) — advances per completed paragraph.
  Stream<double> get progressStream => _progressController.stream;

  /// Current speech state.
  SpeechState get state => _state;

  /// Whether TTS is available on this platform. Native engines exist on
  /// effectively all Android/iOS devices; the actual availability is
  /// verified lazily on the first [speak] (a missing engine simply produces
  /// no audio and an immediate completion).
  bool get isAvailable => true;

  void _setState(SpeechState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  Future<FlutterTts?> _ensureTts() async {
    if (_tts != null) return _tts;
    final tts = FlutterTts();
    try {
      await tts.awaitSpeakCompletion(true);
      tts.setCancelHandler(_onNativeStop);
      _tts = tts;
      return tts;
    } catch (_) {
      // Engine missing or failed to initialize — speech is a no-op.
      return null;
    }
  }

  /// Detect the dominant script of the text so the right engine voice is
  /// used: CJK-heavy content reads in Chinese, otherwise English.
  String _languageFor(String text) {
    final cjk = RegExp(r'[\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7af]')
        .allMatches(text)
        .length;
    final letters = RegExp(r'[A-Za-z]').allMatches(text).length;
    return cjk > letters ? 'zh-CN' : 'en-US';
  }

  Future<void> speak(String text) async {
    stop();
    _speakToken++;
    final token = _speakToken;
    _paragraphs = _splitParagraphs(text);
    _currentParagraphIndex = 0;

    if (_paragraphs.isEmpty) return;

    final tts = await _ensureTts();
    if (tts == null) return;
    if (token != _speakToken) return; // superseded while initializing

    await tts.setLanguage(_languageFor(text));
    await tts.setSpeechRate(_platformRate(_rate));

    _setState(SpeechState.playing);
    await _speakCurrentParagraph(token);
  }

  Future<void> _speakCurrentParagraph(int token) async {
    final tts = _tts;
    if (tts == null || _state == SpeechState.stopped) return;
    if (token != _speakToken) return;
    if (_currentParagraphIndex >= _paragraphs.length) {
      stop();
      return;
    }
    // awaitSpeakCompletion(true) makes this resolve when the utterance
    // finishes (or fails); no timers, no simulation.
    await tts.speak(_paragraphs[_currentParagraphIndex]);
    if (token != _speakToken || _state == SpeechState.stopped) return;
    _currentParagraphIndex++;
    if (_currentParagraphIndex >= _paragraphs.length) {
      stop();
      return;
    }
    _progressController.add(_currentParagraphIndex / _paragraphs.length);
    await _speakCurrentParagraph(token);
  }

  /// Pause the current speech.
  Future<void> pause() async {
    if (_state != SpeechState.playing) return;
    await _tts?.pause();
    _setState(SpeechState.paused);
  }

  /// Resume paused speech. flutter_tts exposes pause() but no imperative
  /// continue, so resume replays the current paragraph from its start; the
  /// token bump also retires any loop still awaiting the paused utterance.
  Future<void> resume() async {
    if (_state != SpeechState.paused) return;
    _speakToken++;
    _setState(SpeechState.playing);
    await _speakCurrentParagraph(_speakToken);
  }

  /// Stop speech entirely.
  void stop() {
    _speakToken++;
    _tts?.stop();
    _currentParagraphIndex = 0;
    _setState(SpeechState.stopped);
    _progressController.add(0.0);
  }

  /// Set speech rate (0.5 to 2.0), applied to the next utterance.
  Future<void> setRate(double rate) async {
    _rate = rate;
    await _tts?.setSpeechRate(_platformRate(rate));
  }

  /// Map our 0.5–2.0 rate scale onto the platform scales: Android expects
  /// 0.0–1.0 (1.0 = normal), iOS 0.0–0.5 (0.5 = normal), web 0.1–10.
  double _platformRate(double rate) {
    if (kIsWeb) return rate;
    if (defaultTargetPlatform == TargetPlatform.iOS) return rate * 0.25;
    // Android and other natives.
    return rate * 0.5;
  }

  /// Split text into paragraphs for sequential reading.
  List<String> _splitParagraphs(String text) {
    return text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  void _onNativeStop() {
    // Fired when the engine cancels (user dismissal, engine switch).
    if (_state != SpeechState.stopped) {
      _setState(SpeechState.stopped);
      _progressController.add(0.0);
    }
  }

  /// Dispose resources.
  void dispose() {
    _tts?.stop();
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
