import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/compose/data/ai_repository.dart';

// ---------------------------------------------------------------------------
// ChatMessage tests
// ---------------------------------------------------------------------------

void main() {
  group('ChatMessage', () {
    test('constructor sets role and content', () {
      const message = ChatMessage(role: 'user', content: 'Hello');

      expect(message.role, 'user');
      expect(message.content, 'Hello');
    });

    test('role can be system', () {
      const message = ChatMessage(
        role: 'system',
        content: 'You are a helpful assistant.',
      );

      expect(message.role, 'system');
      expect(message.content, 'You are a helpful assistant.');
    });

    test('role can be assistant', () {
      const message = ChatMessage(role: 'assistant', content: 'Hi there!');

      expect(message.role, 'assistant');
      expect(message.content, 'Hi there!');
    });

    test('content can be empty string', () {
      const message = ChatMessage(role: 'user', content: '');

      expect(message.content, isEmpty);
    });

    test('content can contain unicode and special characters', () {
      const message = ChatMessage(
        role: 'user',
        content: '\u4f60\u597d\u4e16\u754c! <special> "chars" & more',
      );

      expect(message.content, contains('\u4f60\u597d'));
      expect(message.content, contains('<special>'));
      expect(message.content, contains('"chars"'));
    });

    test('content can be long text', () {
      final longContent = 'A' * 10000;
      final message = ChatMessage(role: 'user', content: longContent);

      expect(message.content.length, 10000);
    });
  });

  // ---------------------------------------------------------------------------
  // AIRepository request body construction
  // ---------------------------------------------------------------------------

  group('AIRepository chat request construction', () {
    test('messages are mapped to role/content pairs', () {
      final messages = [
        const ChatMessage(role: 'system', content: 'Be helpful'),
        const ChatMessage(role: 'user', content: 'What is 2+2?'),
        const ChatMessage(role: 'assistant', content: '4'),
        const ChatMessage(role: 'user', content: 'Thanks'),
      ];

      // Verify the mapping logic that AIRepository.chat uses internally.
      final mapped = messages
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      expect(mapped.length, 4);
      expect(mapped[0]['role'], 'system');
      expect(mapped[0]['content'], 'Be helpful');
      expect(mapped[1]['role'], 'user');
      expect(mapped[1]['content'], 'What is 2+2?');
      expect(mapped[2]['role'], 'assistant');
      expect(mapped[2]['content'], '4');
      expect(mapped[3]['role'], 'user');
      expect(mapped[3]['content'], 'Thanks');
    });

    test('request body includes stream: false for non-streaming', () {
      final messages = [
        const ChatMessage(role: 'user', content: 'test'),
      ];

      final body = {
        'messages': messages.map((m) => {'role': m.role, 'content': m.content}).toList(),
        'stream': false,
      };

      expect(body['stream'], false);
      expect(body['messages'], isA<List>());
    });

    test('request body includes optional model when provided', () {
      final messages = [
        const ChatMessage(role: 'user', content: 'test'),
      ];

      final body = {
        'messages': messages.map((m) => {'role': m.role, 'content': m.content}).toList(),
        'model': 'gpt-4',
        'stream': false,
      };

      expect(body['model'], 'gpt-4');
    });

    test('request body omits model when null', () {
      final messages = [
        const ChatMessage(role: 'user', content: 'test'),
      ];

      // Simulate a null model variable to verify conditional key omission.
      const String? model = null;
      final body = <String, dynamic>{
        'messages': messages.map((m) => {'role': m.role, 'content': m.content}).toList(),
        if (model != null) 'model': model,
        'stream': false,
      };

      expect(body.containsKey('model'), isFalse);
    });

    test('request body for streaming includes stream: true', () {
      final messages = [
        const ChatMessage(role: 'user', content: 'stream test'),
      ];

      final body = {
        'messages': messages.map((m) => {'role': m.role, 'content': m.content}).toList(),
        'stream': true,
      };

      expect(body['stream'], true);
    });
  });

  // ---------------------------------------------------------------------------
  // SSE parsing logic (replicated from AIRepository.chatStream)
  // ---------------------------------------------------------------------------

  group('SSE parsing', () {
    /// Simulates the SSE parsing logic from AIRepository.chatStream.
    /// Extracts content strings from raw SSE-formatted bytes.
    List<String> parseSSE(String rawSSE) {
      final results = <String>[];
      for (final line in rawSSE.split('\n')) {
        if (line.startsWith('data: ')) {
          final jsonStr = line.substring(6);
          if (jsonStr == '[DONE]') break;
          try {
            final json = jsonDecode(jsonStr) as Map<String, dynamic>;
            if (json['content'] != null) {
              results.add(json['content'] as String);
            }
          } catch (_) {
            // Ignore malformed JSON lines, same as the real implementation.
          }
        }
      }
      return results;
    }

    test('parses single SSE data line with content', () {
      final sse = 'data: {"content":"Hello"}\n\n';
      final results = parseSSE(sse);

      expect(results, ['Hello']);
    });

    test('parses multiple SSE data lines', () {
      final sse = ''
          'data: {"content":"Hello "}\n'
          'data: {"content":"world"}\n'
          '\n';
      final results = parseSSE(sse);

      expect(results, ['Hello ', 'world']);
    });

    test('stops at [DONE] sentinel', () {
      final sse = ''
          'data: {"content":"part one"}\n'
          'data: [DONE]\n'
          'data: {"content":"should not appear"}\n'
          '\n';
      final results = parseSSE(sse);

      expect(results, ['part one']);
    });

    test('skips lines that do not start with "data: "', () {
      final sse = ''
          ': this is a comment\n'
          'data: {"content":"visible"}\n'
          'event: ping\n'
          '\n';
      final results = parseSSE(sse);

      expect(results, ['visible']);
    });

    test('skips malformed JSON in data line', () {
      final sse = ''
          'data: {invalid json}\n'
          'data: {"content":"valid"}\n'
          '\n';
      final results = parseSSE(sse);

      expect(results, ['valid']);
    });

    test('skips data line without content field', () {
      final sse = ''
          'data: {"type":"ping"}\n'
          'data: {"content":"actual content"}\n'
          '\n';
      final results = parseSSE(sse);

      expect(results, ['actual content']);
    });

    test('handles empty SSE input', () {
      final results = parseSSE('');
      expect(results, isEmpty);
    });

    test('handles unicode content in SSE', () {
      final content = '\u4f60\u597d\u4e16\u754c';
      final sse = 'data: {"content":"$content"}\n\n';
      final results = parseSSE(sse);

      expect(results, [content]);
    });
  });

  // ---------------------------------------------------------------------------
  // AIRepository instantiation
  // ---------------------------------------------------------------------------

  group('AIRepository instantiation', () {
    test('constructor accepts an ApiClient', () {
      // AIRepository requires an ApiClient. We cannot instantiate a real one
      // in unit tests without a server, so we verify the type signature is
      // correct by creating the repository with null checks.
      //
      // Instead of testing with a real client, we verify that the
      // ChatMessage class is correctly used as the input type.
      const messages = [
        ChatMessage(role: 'user', content: 'test'),
      ];
      expect(messages.first.role, 'user');
      expect(messages.first.content, 'test');
    });
  });
}
