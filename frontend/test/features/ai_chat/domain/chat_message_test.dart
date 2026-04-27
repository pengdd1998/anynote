import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/ai_chat/domain/chat_message.dart';

void main() {
  group('ChatMessage', () {
    // -- Construction ----------------------------------------------------------

    test('construction with required fields', () {
      final timestamp = DateTime(2026, 4, 25, 12, 0);
      final msg = ChatMessage(
        role: 'user',
        content: 'Hello, AI!',
        timestamp: timestamp,
      );

      expect(msg.role, 'user');
      expect(msg.content, 'Hello, AI!');
      expect(msg.timestamp, timestamp);
      expect(msg.isStreaming, isFalse);
    });

    test('construction with isStreaming true', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: '',
        timestamp: DateTime.now(),
        isStreaming: true,
      );

      expect(msg.isStreaming, isTrue);
    });

    test('default isStreaming is false', () {
      final msg = ChatMessage(
        role: 'user',
        content: 'test',
        timestamp: DateTime.now(),
      );

      expect(msg.isStreaming, isFalse);
    });

    test('supports all role values', () {
      for (final role in ['system', 'user', 'assistant']) {
        final msg = ChatMessage(
          role: role,
          content: 'content',
          timestamp: DateTime.now(),
        );
        expect(msg.role, role);
      }
    });

    test('accepts empty content', () {
      final msg = ChatMessage(
        role: 'user',
        content: '',
        timestamp: DateTime.now(),
      );

      expect(msg.content, isEmpty);
    });

    // -- copyWith --------------------------------------------------------------

    test('copyWith preserves all fields when no arguments given', () {
      final timestamp = DateTime(2026, 4, 25);
      final original = ChatMessage(
        role: 'assistant',
        content: 'response text',
        timestamp: timestamp,
        isStreaming: true,
      );

      final copy = original.copyWith();

      expect(copy.role, 'assistant');
      expect(copy.content, 'response text');
      expect(copy.timestamp, timestamp);
      expect(copy.isStreaming, isTrue);
    });

    test('copyWith updates role', () {
      final original = ChatMessage(
        role: 'user',
        content: 'hello',
        timestamp: DateTime.now(),
      );

      final copy = original.copyWith(role: 'assistant');

      expect(copy.role, 'assistant');
      expect(copy.content, 'hello');
    });

    test('copyWith updates content', () {
      final original = ChatMessage(
        role: 'assistant',
        content: '',
        timestamp: DateTime.now(),
        isStreaming: true,
      );

      final copy = original.copyWith(content: 'accumulated text');

      expect(copy.content, 'accumulated text');
      expect(copy.isStreaming, isTrue);
    });

    test('copyWith updates timestamp', () {
      final t1 = DateTime(2026, 1, 1);
      final t2 = DateTime(2026, 6, 15);
      final original = ChatMessage(
        role: 'user',
        content: 'hello',
        timestamp: t1,
      );

      final copy = original.copyWith(timestamp: t2);

      expect(copy.timestamp, t2);
      expect(copy.timestamp, isNot(equals(t1)));
    });

    test('copyWith updates isStreaming', () {
      final original = ChatMessage(
        role: 'assistant',
        content: 'response',
        timestamp: DateTime.now(),
        isStreaming: true,
      );

      final copy = original.copyWith(isStreaming: false);

      expect(copy.isStreaming, isFalse);
    });

    test('copyWith updates multiple fields at once', () {
      final original = ChatMessage(
        role: 'user',
        content: 'old',
        timestamp: DateTime(2026, 1, 1),
      );
      final newTimestamp = DateTime(2026, 12, 31);

      final copy = original.copyWith(
        content: 'new',
        timestamp: newTimestamp,
        isStreaming: true,
      );

      expect(copy.role, 'user'); // unchanged
      expect(copy.content, 'new');
      expect(copy.timestamp, newTimestamp);
      expect(copy.isStreaming, isTrue);
    });

    // -- toApiMap --------------------------------------------------------------

    test('toApiMap returns correct map', () {
      final msg = ChatMessage(
        role: 'user',
        content: 'What is flutter?',
        timestamp: DateTime.now(),
      );

      final map = msg.toApiMap();

      expect(map, isA<Map<String, String>>());
      expect(map['role'], 'user');
      expect(map['content'], 'What is flutter?');
      expect(map.length, 2);
    });

    test('toApiMap for assistant message', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Flutter is a UI toolkit.',
        timestamp: DateTime.now(),
      );

      final map = msg.toApiMap();

      expect(map['role'], 'assistant');
      expect(map['content'], 'Flutter is a UI toolkit.');
    });

    test('toApiMap for system message', () {
      final msg = ChatMessage(
        role: 'system',
        content: 'You are a helpful assistant.',
        timestamp: DateTime.now(),
      );

      final map = msg.toApiMap();

      expect(map['role'], 'system');
      expect(map['content'], 'You are a helpful assistant.');
    });

    test('toApiMap does not include timestamp or isStreaming', () {
      final msg = ChatMessage(
        role: 'user',
        content: 'test',
        timestamp: DateTime.now(),
        isStreaming: true,
      );

      final map = msg.toApiMap();

      expect(map.containsKey('timestamp'), isFalse);
      expect(map.containsKey('isStreaming'), isFalse);
    });

    // -- Equality (value equality via operator== override) -----------

    test('identical fields produce equal instances (value equality)', () {
      final timestamp = DateTime(2026, 4, 25);
      final msg1 = ChatMessage(
        role: 'user',
        content: 'hello',
        timestamp: timestamp,
      );
      final msg2 = ChatMessage(
        role: 'user',
        content: 'hello',
        timestamp: timestamp,
      );

      expect(msg1, equals(msg2));
      expect(msg1.hashCode, equals(msg2.hashCode));
      expect(identical(msg1, msg2), isFalse);
    });

    test('same instance is identical', () {
      final msg = ChatMessage(
        role: 'user',
        content: 'test',
        timestamp: DateTime.now(),
      );

      expect(identical(msg, msg), isTrue);
    });
  });
}
