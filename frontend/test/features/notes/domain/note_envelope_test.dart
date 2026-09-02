import 'dart:convert';

import 'package:anynote/features/notes/domain/note_envelope.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for the sync-envelope unwrap helper — the core of the fix for
/// the "note content shows raw {"content":...,"title":...} JSON" bug.
///
/// The sync engine packs a note for push as {"content": <plainContent>,
/// "title": <plainTitle>}. A prior bug stored that envelope (and, after an
/// editor round-trip, the envelope embedded inside a Quill Delta's text) as
/// the note content. `unwrapSyncEnvelope` must recover the real body in all
/// these forms and across note formats.
void main() {
  /// Representative note bodies (the value of the envelope "content" field)
  /// across formats. Rich formatting (bold/heading) is reduced to plain text
  /// by the editor's _extractPlainText before it is wrapped, so the envelope
  /// only ever carries plain text — these exercise that variety.
  final formats = <String, String>{
    'plain': 'Hello world',
    'multiline': 'Line one\nLine two\nLine three',
    'heading-ish': 'My Heading\nBody paragraph here',
    'bullet list': 'item alpha\nitem beta\nitem gamma',
    'numbered list': 'first\nsecond\nthird',
    'chinese': '中文笔记内容\n第二行',
    'emoji/symbols': 'Notes with emoji 🚀 and symbols !@#',
    'mixed long':
        'Project Notes\n\n'
        'TODO:\n'
        '- fix sync\n'
        '- test formats\n\n'
        'This is a longer paragraph used to verify the unwrap handles '
        'multi-paragraph content with newlines and punctuation, end.',
  };

  /// Build the sync envelope JSON for a body.
  String envelope(String body, {String title = 'NoteTitle'}) =>
      jsonEncode({'content': body, 'title': title});

  group('unwrapSyncEnvelope — pure envelope', () {
    formats.forEach((name, body) {
      test('$name: extracts the body', () {
        expect(unwrapSyncEnvelope(envelope(body)), body);
      });
    });
  });

  group('unwrapSyncEnvelope — title prepended before the envelope', () {
    // The editor prepends the title to content on load; the envelope can end
    // up after it: "NoteTitle\n{...}".
    formats.forEach((name, body) {
      test('$name: extracts the body past the title', () {
        final content = 'NoteTitle\n${envelope(body)}';
        expect(unwrapSyncEnvelope(content), body);
      });
    });
  });

  group('unwrapSyncEnvelope — envelope embedded inside a Quill Delta', () {
    // The worst corruption: the envelope was inserted as literal text into the
    // editor, then saved as a Delta, so the envelope is buried inside an
    // insert op (and jsonEncode escapes its quotes).
    formats.forEach((name, body) {
      test('$name: extracts the body from the baked-in Delta', () {
        final env = envelope(body);
        final baked = jsonEncode([
          {'insert': 'NoteTitle\n$env\n\nMore trailing text\n'},
        ]);
        expect(unwrapSyncEnvelope(baked), body);
      });
    });
  });

  group('unwrapSyncEnvelope — non-envelope content is left intact', () {
    test('plain text with no envelope is unchanged', () {
      const content = 'Just a normal note with no JSON envelope at all.';
      expect(unwrapSyncEnvelope(content), content);
    });

    test('a real Quill Delta is unchanged', () {
      final delta = jsonEncode([
        {'insert': 'Hello'},
        {'insert': '\n', 'attributes': {'heading': 1}},
        {'insert': 'Body\n'},
      ]);
      expect(unwrapSyncEnvelope(delta), delta);
    });

    test('a JSON object without "content" is unchanged', () {
      final other = jsonEncode({'foo': 'bar', 'baz': 42});
      expect(unwrapSyncEnvelope(other), other);
    });
  });

  group('containsSyncEnvelope', () {
    test('true for a pure envelope', () {
      expect(containsSyncEnvelope(envelope('x')), isTrue);
    });
    test('true for a Delta-baked envelope', () {
      final baked = jsonEncode([
        {'insert': 't\n${envelope("x")}\n'},
      ]);
      expect(containsSyncEnvelope(baked), isTrue);
    });
    test('false for plain text', () {
      expect(containsSyncEnvelope('just text'), isFalse);
    });
  });

  group('round-trip: body -> envelope -> unwrap == body', () {
    formats.forEach((name, body) {
      test('$name round-trips intact', () {
        expect(unwrapSyncEnvelope(envelope(body)), body);
      });
    });
  });

  group('stripObjectPlaceholders — [OBJ] placeholder hygiene', () {
    test('strips U+FFFC object replacement chars', () {
      expect(stripObjectPlaceholders('￼'), '');
      expect(stripObjectPlaceholders('a￼b'), 'ab');
    });

    test('strips U+FFFE / U+FFFF noncharacters', () {
      expect(stripObjectPlaceholders('￾￿'), '');
    });

    test('keeps emoji and normal text untouched', () {
      const text = '红红的太阳 🌞 egg 🥚!';
      expect(stripObjectPlaceholders(text), text);
    });

    test('plainContent with FFFC is cleaned by plainTextFromStoredContent', () {
      expect(
        plainTextFromStoredContent('标题￼正文'),
        '标题正文',
      );
    });

    test('delta text inserts with FFFC are cleaned', () {
      final delta = jsonEncode([
        {'insert': '红红的太阳￼\n'},
      ]);
      expect(plainTextFromStoredContent(delta), '红红的太阳\n');
    });

    test('sanitizeDeltaOps cleans string inserts, keeps embeds', () {
      final ops = sanitizeDeltaOps([
        {
          'insert': 'text￼',
        },
        {
          'insert': {'image': 'x.png'},
        },
      ]);
      expect(ops[0]['insert'], 'text');
      expect(ops[1]['insert'], isMap);
    });

    test('storedContentToPlainText strips placeholders', () {
      expect(storedContentToPlainText('abc￼'), 'abc');
    });
  });
}
