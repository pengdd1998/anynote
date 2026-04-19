import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents shared content received from another app via the share extension.
class SharedContent {
  /// The type of shared content: "text", "image", or "file".
  final String type;

  /// The shared text content. Non-null when [type] is "text".
  final String? text;

  /// The local file path for shared images or files.
  /// Non-null when [type] is "image" or "file".
  final String? path;

  const SharedContent({
    required this.type,
    this.text,
    this.path,
  });

  /// Whether this shared content contains text.
  bool get isText => type == 'text';

  /// Whether this shared content is an image.
  bool get isImage => type == 'image';

  /// Whether this shared content is a generic file.
  bool get isFile => type == 'file';

  /// Returns a display-friendly representation for pre-filling a note.
  /// For text: the raw text.
  /// For images: a markdown image reference.
  /// For files: a note mentioning the file.
  String toNoteContent() {
    switch (type) {
      case 'text':
        return text ?? '';
      case 'image':
        if (path != null) {
          return '![shared image](file://$path)';
        }
        return '';
      case 'file':
        if (path != null) {
          return 'Shared file: $path';
        }
        return '';
      default:
        return text ?? '';
    }
  }

  factory SharedContent.fromJson(Map<String, dynamic> json) {
    return SharedContent(
      type: json['type'] as String? ?? 'text',
      text: json['text'] as String?,
      path: json['path'] as String?,
    );
  }
}

/// Service that listens for and processes incoming shared content from
/// platform-specific share extensions.
///
/// **Android**: ShareActivity writes shared data to SharedPreferences with
/// the key `pending_share`. On cold start or resume, this service reads and
/// clears the pending value.
///
/// **iOS**: The ShareExtension writes to shared UserDefaults (App Group
/// `group.com.anynote.app`) with key `pending_share`. On resume, this
/// service checks for pending data.
///
/// Both platforms also send a deep link (`anynote://share/received`) which
/// triggers the GoRouter navigation. The service exposes a stream that the
/// router or main widget listens to.
class ReceiveShareService {
  static const _methodChannel = MethodChannel('com.anynote.app/share');
  static const _prefsKey = 'pending_share';
  static const _prefsTimestampKey = 'pending_share_timestamp';

  final _controller = StreamController<SharedContent>.broadcast();

  /// Stream of received shared content. Emits once per shared item.
  /// Listeners should navigate to the note editor with the content.
  Stream<SharedContent> get onShareReceived => _controller.stream;

  /// Whether there is a pending share that has not yet been consumed.
  bool _hasPendingShare = false;

  /// Initialize the service. Call once during app startup.
  ///
  /// Sets up the MethodChannel handler for Android and checks for any
  /// pending share data that arrived during cold start.
  Future<void> init() async {
    // Set up MethodChannel handler for real-time communication.
    _methodChannel.setMethodCallHandler(_handleMethodCall);

    // Check for pending share data from cold start.
    await checkPendingShare();
  }

  /// Handle incoming method calls from the platform side.
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'shareReceived':
        final data = call.arguments as String?;
        if (data != null) {
          _processShareData(data);
        }
        break;
    }
  }

  /// Check for any pending share data stored during cold start.
  ///
  /// On Android, reads from SharedPreferences.
  /// On iOS, reads from shared UserDefaults (App Group).
  Future<void> checkPendingShare() async {
    if (_hasPendingShare) return;

    String? pendingData;

    if (Platform.isAndroid) {
      // Android: read from SharedPreferences used by ShareActivity.
      final prefs = await SharedPreferences.getInstance();
      pendingData = prefs.getString(_prefsKey);
      if (pendingData != null) {
        // Clear the pending data so it is not consumed again.
        await prefs.remove(_prefsKey);
        await prefs.remove(_prefsTimestampKey);
      }
    } else if (Platform.isIOS) {
      // iOS: read from shared App Group UserDefaults.
      try {
        final result = await _methodChannel.invokeMethod<Map>('getPendingShare');
        if (result != null && result.containsKey('data')) {
          pendingData = result['data'] as String?;
        }
      } on PlatformException {
        // Method not available on iOS (e.g., share extension not configured).
        // Fall back to checking shared UserDefaults via platform channel.
        final prefs = await SharedPreferences.getInstance();
        pendingData = prefs.getString(_prefsKey);
        if (pendingData != null) {
          await prefs.remove(_prefsKey);
          await prefs.remove(_prefsTimestampKey);
        }
      }
    }

    if (pendingData != null) {
      _processShareData(pendingData);
    }
  }

  /// Process a raw JSON share data string and emit it to listeners.
  void _processShareData(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final content = SharedContent.fromJson(json);
      _hasPendingShare = true;
      _controller.add(content);
    } catch (e) {
      debugPrint('ReceiveShareService: failed to parse share data: $e');
    }
  }

  /// Reset the pending share flag after the content has been consumed.
  void markConsumed() {
    _hasPendingShare = false;
  }

  /// Dispose the service and close the stream.
  void dispose() {
    _controller.close();
  }
}

/// Riverpod provider for the ReceiveShareService singleton.
final receiveShareServiceProvider = Provider<ReceiveShareService>((ref) {
  final service = ReceiveShareService();
  ref.onDispose(() => service.dispose());
  return service;
});
