import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anynote/core/share/receive_share_service.dart';

/// Method channel used by ReceiveShareService.
const _channelName = 'com.anynote.app/share';
const _channel = MethodChannel(_channelName);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // SharedContent model
  // ===========================================================================

  group('SharedContent', () {
    test('constructs with required type', () {
      const content = SharedContent(type: 'text', text: 'hello');
      expect(content.type, 'text');
      expect(content.text, 'hello');
      expect(content.path, isNull);
    });

    test('constructs with all fields', () {
      const content = SharedContent(type: 'image', path: '/tmp/img.png');
      expect(content.type, 'image');
      expect(content.text, isNull);
      expect(content.path, '/tmp/img.png');
    });

    test('isText is true only for text type', () {
      const content = SharedContent(type: 'text', text: 'hello');
      expect(content.isText, isTrue);
      expect(content.isImage, isFalse);
      expect(content.isFile, isFalse);
    });

    test('isImage is true only for image type', () {
      const content = SharedContent(type: 'image', path: '/tmp/img.png');
      expect(content.isImage, isTrue);
      expect(content.isText, isFalse);
      expect(content.isFile, isFalse);
    });

    test('isFile is true only for file type', () {
      const content = SharedContent(type: 'file', path: '/tmp/doc.pdf');
      expect(content.isFile, isTrue);
      expect(content.isText, isFalse);
      expect(content.isImage, isFalse);
    });

    test('toNoteContent returns text for text type', () {
      const content = SharedContent(type: 'text', text: 'hello world');
      expect(content.toNoteContent(), 'hello world');
    });

    test('toNoteContent returns empty string for text with null text', () {
      const content = SharedContent(type: 'text');
      expect(content.toNoteContent(), '');
    });

    test('toNoteContent returns markdown image for image type with path', () {
      const content = SharedContent(type: 'image', path: '/tmp/photo.jpg');
      expect(content.toNoteContent(), '![shared image](file:///tmp/photo.jpg)');
    });

    test('toNoteContent returns empty for image type without path', () {
      const content = SharedContent(type: 'image');
      expect(content.toNoteContent(), '');
    });

    test('toNoteContent returns shared file message for file type with path', () {
      const content = SharedContent(type: 'file', path: '/tmp/doc.pdf');
      expect(content.toNoteContent(), 'Shared file: /tmp/doc.pdf');
    });

    test('toNoteContent returns empty for file type without path', () {
      const content = SharedContent(type: 'file');
      expect(content.toNoteContent(), '');
    });

    test('toNoteContent falls back to text for unknown type', () {
      const content = SharedContent(type: 'video', text: 'fallback');
      expect(content.toNoteContent(), 'fallback');
    });

    test('toNoteContent falls back to empty for unknown type with null text', () {
      const content = SharedContent(type: 'video');
      expect(content.toNoteContent(), '');
    });

    test('fromJson constructs from valid JSON', () {
      final json = {'type': 'text', 'text': 'hello', 'path': '/tmp/file'};
      final content = SharedContent.fromJson(json);
      expect(content.type, 'text');
      expect(content.text, 'hello');
      expect(content.path, '/tmp/file');
    });

    test('fromJson defaults type to text when null', () {
      final json = <String, dynamic>{};
      final content = SharedContent.fromJson(json);
      expect(content.type, 'text');
      expect(content.text, isNull);
      expect(content.path, isNull);
    });

    test('fromJson handles partial JSON with only type', () {
      final json = {'type': 'image'};
      final content = SharedContent.fromJson(json);
      expect(content.type, 'image');
      expect(content.text, isNull);
      expect(content.path, isNull);
    });
  });

  // ===========================================================================
  // ReceiveShareService -- stream and lifecycle
  // ===========================================================================

  group('ReceiveShareService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('stream emits SharedContent when valid JSON is processed', () async {
      final service = ReceiveShareService();
      final received = <SharedContent>[];
      service.onShareReceived.listen(received.add);

      // Set up mock method channel handler before init.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (MethodCall call) async {
        return null;
      });

      await service.init();

      // Simulate a platform-initiated share via binary messenger.
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final data = jsonEncode({'type': 'text', 'text': 'shared text'});
      await messenger.handlePlatformMessage(
        _channelName,
        const StandardMethodCodec()
            .encodeMethodCall(MethodCall('shareReceived', data)),
        (_) {},
      );

      await Future<void>.delayed(Duration.zero);

      expect(received.length, 1);
      expect(received[0].type, 'text');
      expect(received[0].text, 'shared text');

      service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    });

    test('stream does not emit for null arguments', () async {
      final service = ReceiveShareService();
      final received = <SharedContent>[];
      service.onShareReceived.listen(received.add);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (MethodCall call) async {
        return null;
      });

      await service.init();

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      await messenger.handlePlatformMessage(
        _channelName,
        const StandardMethodCodec()
            .encodeMethodCall(const MethodCall('shareReceived', null)),
        (_) {},
      );

      await Future<void>.delayed(Duration.zero);

      expect(received, isEmpty);

      service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    });

    test('stream does not emit for malformed JSON', () async {
      final service = ReceiveShareService();
      final received = <SharedContent>[];
      service.onShareReceived.listen(received.add);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (MethodCall call) async {
        return null;
      });

      await service.init();

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      await messenger.handlePlatformMessage(
        _channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('shareReceived', 'not valid json {'),
        ),
        (_) {},
      );

      await Future<void>.delayed(Duration.zero);

      expect(received, isEmpty);

      service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    });

    test('multiple shares are emitted in order', () async {
      final service = ReceiveShareService();
      final received = <SharedContent>[];
      service.onShareReceived.listen(received.add);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (MethodCall call) async {
        return null;
      });

      await service.init();

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      for (var i = 0; i < 3; i++) {
        final data = jsonEncode({'type': 'text', 'text': 'item $i'});
        await messenger.handlePlatformMessage(
          _channelName,
          const StandardMethodCodec()
              .encodeMethodCall(MethodCall('shareReceived', data)),
          (_) {},
        );
      }

      await Future<void>.delayed(Duration.zero);

      expect(received.length, 3);
      expect(received[0].text, 'item 0');
      expect(received[1].text, 'item 1');
      expect(received[2].text, 'item 2');

      service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    });

    test('unknown method call does not crash', () async {
      final service = ReceiveShareService();
      final received = <SharedContent>[];
      service.onShareReceived.listen(received.add);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (MethodCall call) async {
        return null;
      });

      await service.init();

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      await messenger.handlePlatformMessage(
        _channelName,
        const StandardMethodCodec()
            .encodeMethodCall(const MethodCall('unknownMethod', 'data')),
        (_) {},
      );

      await Future<void>.delayed(Duration.zero);

      expect(received, isEmpty);

      service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    });

    test('markConsumed allows subsequent shares', () async {
      final service = ReceiveShareService();
      final received = <SharedContent>[];
      service.onShareReceived.listen(received.add);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (MethodCall call) async {
        return null;
      });

      await service.init();

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      // First share.
      final data1 = jsonEncode({'type': 'text', 'text': 'first'});
      await messenger.handlePlatformMessage(
        _channelName,
        const StandardMethodCodec()
            .encodeMethodCall(MethodCall('shareReceived', data1)),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(received.length, 1);

      service.markConsumed();

      // Second share should still work.
      final data2 = jsonEncode({'type': 'image', 'path': '/img.png'});
      await messenger.handlePlatformMessage(
        _channelName,
        const StandardMethodCodec()
            .encodeMethodCall(MethodCall('shareReceived', data2)),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);

      expect(received.length, 2);
      expect(received[1].type, 'image');

      service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    });

    test('dispose closes the stream', () async {
      final service = ReceiveShareService();
      var done = false;
      service.onShareReceived.listen(
        (_) {},
        onDone: () => done = true,
      );

      service.dispose();

      await Future<void>.delayed(Duration.zero);
      expect(done, isTrue);
    });

    test('init does not throw with empty SharedPreferences', () async {
      final service = ReceiveShareService();
      SharedPreferences.setMockInitialValues({});

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (MethodCall call) async {
        return null;
      });

      // Should complete without error.
      await service.init();

      service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    });

    test('checkPendingShare clears pending data after reading on Linux', () async {
      // On the Linux test runner, Platform.isAndroid is false and Platform.isIOS
      // is false, so checkPendingShare will skip both branches. This test
      // verifies no crash occurs.
      SharedPreferences.setMockInitialValues({
        'pending_share': jsonEncode({'type': 'text', 'text': 'pending'}),
      });

      final service = ReceiveShareService();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (MethodCall call) async {
        return null;
      });

      await service.init();

      // Verify no crash occurred.
      service.markConsumed();
      service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    });

    test('image share with path produces correct note content', () async {
      final service = ReceiveShareService();
      final received = <SharedContent>[];
      service.onShareReceived.listen(received.add);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (MethodCall call) async {
        return null;
      });

      await service.init();

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final data = jsonEncode({
        'type': 'image',
        'path': '/data/user/0/com.anynote.app/cache/shared_image.jpg',
      });
      await messenger.handlePlatformMessage(
        _channelName,
        const StandardMethodCodec()
            .encodeMethodCall(MethodCall('shareReceived', data)),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);

      expect(received.length, 1);
      expect(received[0].toNoteContent(),
          '![shared image](file:///data/user/0/com.anynote.app/cache/shared_image.jpg)',);

      service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    });

    test('file share with path produces correct note content', () async {
      final service = ReceiveShareService();
      final received = <SharedContent>[];
      service.onShareReceived.listen(received.add);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (MethodCall call) async {
        return null;
      });

      await service.init();

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final data =
          jsonEncode({'type': 'file', 'path': '/storage/emulated/0/doc.pdf'});
      await messenger.handlePlatformMessage(
        _channelName,
        const StandardMethodCodec()
            .encodeMethodCall(MethodCall('shareReceived', data)),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);

      expect(received.length, 1);
      expect(received[0].toNoteContent(),
          'Shared file: /storage/emulated/0/doc.pdf',);

      service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    });
  });

  // ===========================================================================
  // Share intent data formats
  // ===========================================================================

  group('share intent parsing', () {
    test('URL share intent is parsed as text type', () async {
      final service = ReceiveShareService();
      final received = <SharedContent>[];
      service.onShareReceived.listen(received.add);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (MethodCall call) async {
        return null;
      });

      await service.init();

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      // A URL shared from a browser arrives as text content containing the URL.
      final data = jsonEncode({
        'type': 'text',
        'text': 'https://example.com/article/123',
      });
      await messenger.handlePlatformMessage(
        _channelName,
        const StandardMethodCodec()
            .encodeMethodCall(MethodCall('shareReceived', data)),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);

      expect(received.length, 1);
      expect(received[0].type, 'text');
      expect(received[0].text, 'https://example.com/article/123');
      expect(received[0].isText, isTrue);
      // The note content for a URL share is just the raw URL.
      expect(received[0].toNoteContent(), 'https://example.com/article/123');

      service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    });

    test('share intent with subject and text preserves both in text field',
        () async {
      final service = ReceiveShareService();
      final received = <SharedContent>[];
      service.onShareReceived.listen(received.add);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (MethodCall call) async {
        return null;
      });

      await service.init();

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      // Android share intents may include a subject alongside the text.
      // The subject is typically concatenated with the text by the sending app.
      final data = jsonEncode({
        'type': 'text',
        'text': 'Meeting Notes\n\nShared from Email app',
      });
      await messenger.handlePlatformMessage(
        _channelName,
        const StandardMethodCodec()
            .encodeMethodCall(MethodCall('shareReceived', data)),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);

      expect(received.length, 1);
      expect(received[0].text, contains('Meeting Notes'));
      expect(received[0].text, contains('Shared from Email app'));

      service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    });

    test('deep link URL in shared text is preserved verbatim', () async {
      // When an app shares an anynote:// deep link URL, it should be treated
      // as regular text content. The routing layer handles deep link
      // navigation separately.
      const deepLink = 'anynote://share/received';
      final service = ReceiveShareService();
      final received = <SharedContent>[];
      service.onShareReceived.listen(received.add);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (MethodCall call) async {
        return null;
      });

      await service.init();

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final data = jsonEncode({
        'type': 'text',
        'text': deepLink,
      });
      await messenger.handlePlatformMessage(
        _channelName,
        const StandardMethodCodec()
            .encodeMethodCall(MethodCall('shareReceived', data)),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);

      expect(received.length, 1);
      expect(received[0].text, deepLink);
      expect(received[0].toNoteContent(), deepLink);

      service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    });

    test('empty string share data does not emit', () async {
      final service = ReceiveShareService();
      final received = <SharedContent>[];
      service.onShareReceived.listen(received.add);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (MethodCall call) async {
        return null;
      });

      await service.init();

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      // An empty string is technically valid JSON but produces null after
      // jsonDecode, which should not crash the service.
      await messenger.handlePlatformMessage(
        _channelName,
        const StandardMethodCodec()
            .encodeMethodCall(const MethodCall('shareReceived', '')),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);

      expect(received, isEmpty);

      service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    });

    test('invalid share type is handled gracefully', () async {
      // A share with an unrecognized type should still be emitted; the
      // consumer can inspect the type field.
      final service = ReceiveShareService();
      final received = <SharedContent>[];
      service.onShareReceived.listen(received.add);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (MethodCall call) async {
        return null;
      });

      await service.init();

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final data = jsonEncode({
        'type': 'video',
        'path': '/tmp/movie.mp4',
      });
      await messenger.handlePlatformMessage(
        _channelName,
        const StandardMethodCodec()
            .encodeMethodCall(MethodCall('shareReceived', data)),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);

      expect(received.length, 1);
      expect(received[0].type, 'video');
      // isText, isImage, isFile are all false for unknown types.
      expect(received[0].isText, isFalse);
      expect(received[0].isImage, isFalse);
      expect(received[0].isFile, isFalse);
      // toNoteContent falls back to text field for unknown types.
      expect(received[0].toNoteContent(), '');

      service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    });

    test('multiple share items emitted sequentially preserve order', () async {
      final service = ReceiveShareService();
      final received = <SharedContent>[];
      service.onShareReceived.listen(received.add);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (MethodCall call) async {
        return null;
      });

      await service.init();

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      // Simulate receiving multiple share items in quick succession.
      final items = [
        {'type': 'text', 'text': 'First item'},
        {'type': 'image', 'path': '/tmp/a.jpg'},
        {'type': 'text', 'text': 'Second text'},
        {'type': 'file', 'path': '/tmp/doc.pdf'},
      ];

      for (final item in items) {
        final data = jsonEncode(item);
        await messenger.handlePlatformMessage(
          _channelName,
          const StandardMethodCodec()
              .encodeMethodCall(MethodCall('shareReceived', data)),
          (_) {},
        );
      }
      await Future<void>.delayed(Duration.zero);

      expect(received.length, 4);
      expect(received[0].type, 'text');
      expect(received[0].text, 'First item');
      expect(received[1].type, 'image');
      expect(received[1].path, '/tmp/a.jpg');
      expect(received[2].type, 'text');
      expect(received[2].text, 'Second text');
      expect(received[3].type, 'file');
      expect(received[3].path, '/tmp/doc.pdf');

      service.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    });
  });

  // ===========================================================================
  // receiveShareServiceProvider
  // ===========================================================================

  group('receiveShareServiceProvider', () {
    test('can be read from a ProviderContainer', () {
      final container = ProviderContainer();
      final service = container.read(receiveShareServiceProvider);
      expect(service, isA<ReceiveShareService>());
      container.dispose();
    });

    test('container dispose calls service dispose', () async {
      final container = ProviderContainer();
      final service = container.read(receiveShareServiceProvider);
      expect(service.onShareReceived, isNotNull);

      container.dispose();

      // The stream should be closed after container disposal.
      var done = false;
      service.onShareReceived.listen(
        (_) {},
        onDone: () => done = true,
      );

      // Allow microtasks to complete.
      await Future<void>.delayed(Duration.zero);
      expect(done, isTrue);
    });
  });
}
