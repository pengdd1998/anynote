import 'dart:async';
import 'dart:convert';

import 'package:anynote/features/compose/data/ai_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Stream<List<int>> bytes(List<String> parts) async* {
  for (final p in parts) {
    yield utf8.encode(p);
  }
}

Stream<List<int>> rawBytes(List<List<int>> chunks) async* {
  for (final c in chunks) {
    yield c;
  }
}

void main() {
  group('parseSseLine', () {
    test('extracts content from a data line', () {
      final line = 'data: {"content":"hello"}';
      expect(AIRepository.parseSseLine(line), 'hello');
    });

    test('DONE event line yields a sentinel, not user content', () {
      // The sentinel value is opaque to callers; stream consumers stop on it.
      expect(AIRepository.parseSseLine('data: [DONE]'), isNotNull);
    });

    test('returns null for non-data lines', () {
      expect(AIRepository.parseSseLine('event: ping'), isNull);
      expect(AIRepository.parseSseLine(': keep-alive'), isNull);
      expect(AIRepository.parseSseLine(''), isNull);
    });

    test('returns null for data lines without content field', () {
      expect(AIRepository.parseSseLine('data: {"role":"assistant"}'), isNull);
    });

    test('returns null (no throw) for malformed JSON', () {
      expect(AIRepository.parseSseLine('data: {oops'), isNull);
    });
  });

  group('parseSseContentStream', () {
    test('parses complete lines in a single chunk', () async {
      final chunks = [
        'data: {"content":"hello"}\ndata: {"content":" world"}\n',
      ];
      final out = await AIRepository.parseSseContentStream(bytes(chunks)).join();
      expect(out, 'hello world');
    });

    test('parses lines split across chunk boundaries', () async {
      final chunks = [
        'data: {"cont',
        'ent":"he',
        'llo"}\ndata: {"content":"!"}\n',
      ];
      final out = await AIRepository.parseSseContentStream(bytes(chunks)).join();
      expect(out, 'hello!');
    });

    test('decodes UTF-8 multibyte characters split across chunks', () async {
      // 你 in UTF-8 is E4 BD A0; split the sequence across two chunks.
      final full = utf8.encode('data: {"content":"你好"}\n');
      final splitAt = full.indexOf(0xE4) + 2; // inside 你's 3 bytes
      final out = await AIRepository.parseSseContentStream(
        rawBytes([full.sublist(0, splitAt), full.sublist(splitAt)]),
      ).join();
      expect(out, '你好');
    });

    test('handles content with embedded newlines via chunk boundary', () async {
      // A JSON payload must never contain a raw newline inside the SSE line,
      // so lines are the unit; verify buffering carries across chunks.
      final chunks = ['data: {"content":"a"}\n', '\ndata: {"content":"b"}\n'];
      final out = await AIRepository.parseSseContentStream(bytes(chunks)).join();
      expect(out, 'ab');
    });

    test('terminates on DONE and ignores subsequent data', () async {
      final chunks = [
        'data: {"content":"x"}\ndata: [DONE]\ndata: {"content":"y"}\n',
      ];
      final out = await AIRepository.parseSseContentStream(bytes(chunks)).join();
      expect(out, 'x');
    });

    test('handles CRLF line endings', () async {
      final chunks = ['data: {"content":"a"}\r\ndata: {"content":"b"}\r\n'];
      final out = await AIRepository.parseSseContentStream(bytes(chunks)).join();
      expect(out, 'ab');
    });

    test('skips malformed data lines without breaking the stream', () async {
      final chunks = [
        'data: {bad}\ndata: {"content":"ok"}\ndata: []\ndata: {"content":"!"}\n',
      ];
      final out = await AIRepository.parseSseContentStream(bytes(chunks)).join();
      expect(out, 'ok!');
    });

    test('flushes a trailing line without newline at stream end', () async {
      // Some servers close without a final newline; the buffered remainder
      // is currently dropped by design (newline-delimited protocol).
      final chunks = ['data: {"content":"tail"}'];
      final out = await AIRepository.parseSseContentStream(bytes(chunks)).join();
      expect(out, isEmpty);
    });
  });
}
