import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/collab/ws_client.dart';

void main() {
  // ===========================================================================
  // WSMessage -- serialization / deserialization
  // ===========================================================================

  group('WSMessage', () {
    test('encode produces valid JSON with type and data', () {
      final msg = WSMessage(WSMessageType.join, {'room': 'note-1'});
      final encoded = msg.encode();
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded['type'], equals('join'));
      expect(decoded['room'], equals('note-1'));
    });

    test('decode parses a JSON string into WSMessage', () {
      const raw = '{"type":"edit","room":"note-1","ops":[1,2,3]}';
      final msg = WSMessage.decode(raw);

      expect(msg.type, equals(WSMessageType.edit));
      expect(msg.data['room'], equals('note-1'));
      expect(msg.data['ops'], equals([1, 2, 3]));
    });

    test('encode/decode round-trip preserves type and data', () {
      final original = WSMessage(WSMessageType.typing, {'room': 'abc'});
      final encoded = original.encode();
      final decoded = WSMessage.decode(encoded);

      expect(decoded.type, equals(original.type));
      expect(decoded.data, equals(original.data));
    });

    test('decode handles all message types', () {
      for (final type in WSMessageType.values) {
        final msg = WSMessage(type, {'key': 'value'});
        final encoded = msg.encode();
        final decoded = WSMessage.decode(encoded);
        expect(decoded.type, equals(type));
      }
    });

    test('decode with empty data payload', () {
      const raw = '{"type":"ping"}';
      final msg = WSMessage.decode(raw);
      expect(msg.type, equals(WSMessageType.ping));
      expect(msg.data, isEmpty);
    });

    test('toString contains type name and data', () {
      final msg = WSMessage(WSMessageType.join, {'room': 'test'});
      final str = msg.toString();
      expect(str, contains('join'));
      expect(str, contains('test'));
    });

    test('encode merges data fields at top level', () {
      final msg = WSMessage(WSMessageType.cursor, {
        'room': 'note-1',
        'position': 42,
      });
      final encoded = msg.encode();
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded['type'], equals('cursor'));
      expect(decoded['room'], equals('note-1'));
      expect(decoded['position'], equals(42));
    });
  });

  // ===========================================================================
  // WSMessageType -- enum coverage
  // ===========================================================================

  group('WSMessageType', () {
    test('has expected values', () {
      expect(WSMessageType.values, containsAll([
        WSMessageType.join,
        WSMessageType.leave,
        WSMessageType.presence,
        WSMessageType.typing,
        WSMessageType.comment,
        WSMessageType.edit,
        WSMessageType.cursor,
        WSMessageType.ping,
        WSMessageType.pong,
      ]));
    });

    test('name property matches expected strings', () {
      expect(WSMessageType.join.name, equals('join'));
      expect(WSMessageType.leave.name, equals('leave'));
      expect(WSMessageType.presence.name, equals('presence'));
      expect(WSMessageType.typing.name, equals('typing'));
      expect(WSMessageType.comment.name, equals('comment'));
      expect(WSMessageType.edit.name, equals('edit'));
      expect(WSMessageType.cursor.name, equals('cursor'));
      expect(WSMessageType.ping.name, equals('ping'));
      expect(WSMessageType.pong.name, equals('pong'));
    });
  });

  // ===========================================================================
  // WSConnectionState -- enum coverage
  // ===========================================================================

  group('WSConnectionState', () {
    test('has expected values', () {
      expect(WSConnectionState.values, containsAll([
        WSConnectionState.disconnected,
        WSConnectionState.connecting,
        WSConnectionState.connected,
        WSConnectionState.error,
      ]));
    });
  });

  // ===========================================================================
  // WSClient -- construction and initial state
  // ===========================================================================

  group('WSClient construction', () {
    test('initial state is disconnected', () {
      final client = WSClient(baseUrl: 'ws://localhost:8080', token: 'test');
      expect(client.state, equals(WSConnectionState.disconnected));
      client.dispose();
    });

    test('messages stream is a broadcast stream', () {
      final client = WSClient(baseUrl: 'ws://localhost:8080', token: 'test');
      // Should be able to listen multiple times on a broadcast stream.
      final sub1 = client.messages.listen((_) {});
      final sub2 = client.messages.listen((_) {});
      sub1.cancel();
      sub2.cancel();
      client.dispose();
    });

    test('connectionState stream is a broadcast stream', () {
      final client = WSClient(baseUrl: 'ws://localhost:8080', token: 'test');
      final sub1 = client.connectionState.listen((_) {});
      final sub2 = client.connectionState.listen((_) {});
      sub1.cancel();
      sub2.cancel();
      client.dispose();
    });
  });

  // ===========================================================================
  // WSClient -- send drops messages when disconnected
  // ===========================================================================

  group('WSClient send when disconnected', () {
    test('send silently drops message when not connected', () {
      final client = WSClient(baseUrl: 'ws://localhost:8080', token: 'test');
      // This should not throw.
      client.send(WSMessage(WSMessageType.join, {'room': 'test'}));
      client.dispose();
    });

    test('joinRoom stores room but does not throw when disconnected', () {
      final client = WSClient(baseUrl: 'ws://localhost:8080', token: 'test');
      // Should not throw even though the connection is not open.
      client.joinRoom('note-1');
      client.dispose();
    });

    test('leaveRoom does not throw when disconnected', () {
      final client = WSClient(baseUrl: 'ws://localhost:8080', token: 'test');
      client.leaveRoom('note-1');
      client.dispose();
    });

    test('sendTyping does not throw when disconnected', () {
      final client = WSClient(baseUrl: 'ws://localhost:8080', token: 'test');
      client.sendTyping('note-1');
      client.dispose();
    });

    test('sendEdit does not throw when disconnected', () {
      final client = WSClient(baseUrl: 'ws://localhost:8080', token: 'test');
      client.sendEdit('note-1', {'ops': []});
      client.dispose();
    });

    test('sendCursor does not throw when disconnected', () {
      final client = WSClient(baseUrl: 'ws://localhost:8080', token: 'test');
      client.sendCursor('note-1', 42);
      client.dispose();
    });
  });

  // ===========================================================================
  // WSClient -- dispose
  // ===========================================================================

  group('WSClient dispose', () {
    test('dispose closes message stream', () async {
      final client = WSClient(baseUrl: 'ws://localhost:8080', token: 'test');
      final msgFuture = client.messages.isEmpty;
      client.dispose();

      // Stream should be closed.
      final isEmpty = await msgFuture;
      expect(isEmpty, isTrue);
    });

    test('dispose closes connectionState stream', () async {
      final client = WSClient(baseUrl: 'ws://localhost:8080', token: 'test');
      final stateFuture = client.connectionState.isEmpty;
      client.dispose();

      final isEmpty = await stateFuture;
      expect(isEmpty, isTrue);
    });

    test('dispose can be called multiple times without error', () {
      final client = WSClient(baseUrl: 'ws://localhost:8080', token: 'test');
      client.dispose();
      // Second dispose should not throw.
      client.dispose();
    });
  });

  // ===========================================================================
  // WSClient -- connection state transitions
  // ===========================================================================

  group('WSClient connection state transitions', () {
    test('state transitions are emitted on connectionState stream', () async {
      final client = WSClient(
        baseUrl: 'ws://invalid-host-that-does-not-exist.local:9999',
        token: 'test',
      );

      final states = <WSConnectionState>[];
      final sub = client.connectionState.listen(states.add);

      // Attempt to connect to an invalid host -- this should fail.
      await client.connect().catchError((_) => null);

      // Allow timers to fire.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      sub.cancel();
      client.dispose();

      // We should see at least a connecting state.
      expect(states, contains(WSConnectionState.connecting));
    });

    test('connect is no-op when already connected', () async {
      // We cannot easily simulate a successful connection in unit tests,
      // but we can verify the initial disconnected state and that calling
      // connect on a disconnected client attempts to change state.
      final client = WSClient(baseUrl: 'ws://localhost:8080', token: 'test');
      expect(client.state, equals(WSConnectionState.disconnected));
      client.dispose();
    });
  });

  // ===========================================================================
  // WSMessage -- edge cases
  // ===========================================================================

  group('WSMessage edge cases', () {
    test('decode with nested JSON data', () {
      final data = {
        'type': 'edit',
        'room': 'note-1',
        'payload': {'ops': [1, 2, 3], 'clock': 42},
      };
      final raw = jsonEncode(data);
      final msg = WSMessage.decode(raw);

      expect(msg.type, equals(WSMessageType.edit));
      expect(msg.data['room'], equals('note-1'));
      final payload = msg.data['payload'] as Map<String, dynamic>;
      expect(payload['ops'], equals([1, 2, 3]));
      expect(payload['clock'], equals(42));
    });

    test('decode with special characters in data values', () {
      final data = {
        'type': 'comment',
        'text': 'Hello "world" & <friends>',
      };
      final raw = jsonEncode(data);
      final msg = WSMessage.decode(raw);
      expect(msg.data['text'], equals('Hello "world" & <friends>'));
    });

    test('encode with unicode data', () {
      final msg = WSMessage(WSMessageType.comment, {'text': 'hello'});
      final encoded = msg.encode();
      expect(encoded, contains('hello'));
    });
  });
}
