import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the flutter_tts plugin, which has no platform side under
/// `flutter test`.
///
/// An utterance stays in progress until it is stopped or finished, as with a
/// real engine that is still speaking, so tests can look at the playing state
/// without racing a timer.
class FakeTtsEngine {
  static const _channel = MethodChannel('flutter_tts');

  /// What the service asked the engine to do, in order.
  final calls = <MethodCall>[];

  Completer<dynamic>? _utterance;

  /// Answers the channel from now on. Plain tests need
  /// `TestWidgetsFlutterBinding.ensureInitialized()` first; widget tests
  /// already have the binding.
  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, _onCall);
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }

  /// Ends the current utterance the way an engine does when it has read the
  /// paragraph to the end.
  void finishUtterance() => _endUtterance();

  /// The text of every `speak` call so far. The plugin passes the text
  /// alone, or wrapped in a map on Android.
  List<String> get spokenTexts => [
        for (final call in calls)
          if (call.method == 'speak')
            if (call.arguments is String)
              call.arguments as String
            else
              (call.arguments as Map)['text'] as String,
      ];

  Future<dynamic> _onCall(MethodCall call) async {
    calls.add(call);
    switch (call.method) {
      case 'speak':
        _utterance = Completer<dynamic>();
        return _utterance!.future;
      case 'stop':
        _endUtterance();
        return 1;
      default:
        return 1;
    }
  }

  void _endUtterance() {
    final pending = _utterance;
    _utterance = null;
    if (pending != null && !pending.isCompleted) pending.complete(1);
  }
}
