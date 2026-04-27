import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/ai_chat/domain/chat_session.dart';

void main() {
  group('ChatSession', () {
    // -- Construction ----------------------------------------------------------

    test('construction with required id', () {
      const session = ChatSession(id: 'session-123');

      expect(session.id, 'session-123');
      expect(session.title, isEmpty);
      expect(session.contextNoteIds, isEmpty);
      expect(session.contextNoteContents, isEmpty);
      expect(session.messages, isEmpty);
      expect(session.isLoading, isFalse);
      expect(session.error, isNull);
    });

    test('construction with all fields', () {
      const session = ChatSession(
        id: 'abc',
        title: 'My Chat',
        contextNoteIds: ['n1', 'n2'],
        contextNoteContents: {'n1': 'note one', 'n2': 'note two'},
        messages: ['msg1', 'msg2'],
        isLoading: true,
        error: 'Something went wrong',
      );

      expect(session.id, 'abc');
      expect(session.title, 'My Chat');
      expect(session.contextNoteIds, ['n1', 'n2']);
      expect(session.contextNoteContents, {'n1': 'note one', 'n2': 'note two'});
      expect(session.messages, ['msg1', 'msg2']);
      expect(session.isLoading, isTrue);
      expect(session.error, 'Something went wrong');
    });

    // -- Default values --------------------------------------------------------

    test('default title is empty string', () {
      const session = ChatSession(id: 'test');
      expect(session.title, '');
    });

    test('default contextNoteIds is empty list', () {
      const session = ChatSession(id: 'test');
      expect(session.contextNoteIds, isEmpty);
    });

    test('default contextNoteContents is empty map', () {
      const session = ChatSession(id: 'test');
      expect(session.contextNoteContents, isEmpty);
    });

    test('default messages is empty list', () {
      const session = ChatSession(id: 'test');
      expect(session.messages, isEmpty);
    });

    test('default isLoading is false', () {
      const session = ChatSession(id: 'test');
      expect(session.isLoading, isFalse);
    });

    test('default error is null', () {
      const session = ChatSession(id: 'test');
      expect(session.error, isNull);
    });

    // -- copyWith --------------------------------------------------------------

    test('copyWith preserves id unchanged', () {
      const session = ChatSession(id: 'fixed-id');
      final copy = session.copyWith(title: 'new title');

      expect(copy.id, 'fixed-id');
    });

    test('copyWith updates title', () {
      const session = ChatSession(id: 'test');
      final copy = session.copyWith(title: 'New Title');

      expect(copy.title, 'New Title');
    });

    test('copyWith updates contextNoteIds', () {
      const session = ChatSession(id: 'test');
      final copy = session.copyWith(contextNoteIds: ['a', 'b', 'c']);

      expect(copy.contextNoteIds, ['a', 'b', 'c']);
    });

    test('copyWith updates contextNoteContents', () {
      const session = ChatSession(id: 'test');
      final copy = session.copyWith(
        contextNoteContents: {'x': 'content x'},
      );

      expect(copy.contextNoteContents, {'x': 'content x'});
    });

    test('copyWith updates messages', () {
      const session = ChatSession(id: 'test');
      final copy = session.copyWith(messages: ['m1', 'm2']);

      expect(copy.messages, ['m1', 'm2']);
      expect(copy.messages.length, 2);
    });

    test('copyWith updates isLoading', () {
      const session = ChatSession(id: 'test', isLoading: false);
      final copy = session.copyWith(isLoading: true);

      expect(copy.isLoading, isTrue);
    });

    test('copyWith sets error to provided value', () {
      const session = ChatSession(id: 'test');
      final copy = session.copyWith(error: 'Network error');

      expect(copy.error, 'Network error');
    });

    test('copyWith sets error to null when omitted after previous error', () {
      const session = ChatSession(id: 'test', error: 'old error');
      // copyWith always replaces error with the provided value or null.
      final copy = session.copyWith();

      expect(copy.error, isNull);
    });

    test('copyWith can clear error by passing null', () {
      const session = ChatSession(id: 'test', error: 'bad');
      final copy = session.copyWith(error: null);

      expect(copy.error, isNull);
    });

    test('copyWith preserves unchanged fields', () {
      const session = ChatSession(
        id: 'test',
        title: 'original',
        isLoading: true,
      );
      final copy = session.copyWith(error: 'new error');

      expect(copy.title, 'original');
      expect(copy.isLoading, isTrue);
      expect(copy.error, 'new error');
    });

    test('copyWith can update multiple fields at once', () {
      const session = ChatSession(id: 'test');
      final copy = session.copyWith(
        title: 'Chat Title',
        contextNoteIds: ['n1'],
        isLoading: true,
        messages: ['msg'],
      );

      expect(copy.title, 'Chat Title');
      expect(copy.contextNoteIds, ['n1']);
      expect(copy.isLoading, isTrue);
      expect(copy.messages, ['msg']);
    });

    // -- messages list handling ------------------------------------------------

    test('messages list is stored as provided', () {
      final messages = [
        1,
        'two',
        true,
        {'key': 'value'},
      ];
      final session = ChatSession(id: 'test', messages: messages);

      expect(session.messages.length, 4);
      expect(session.messages[0], 1);
      expect(session.messages[1], 'two');
      expect(session.messages[2], true);
    });

    test('messages list can be replaced entirely via copyWith', () {
      const session = ChatSession(id: 'test', messages: ['old']);
      final copy = session.copyWith(messages: ['new1', 'new2']);

      expect(copy.messages, ['new1', 'new2']);
      expect(copy.messages.length, 2);
    });

    // -- contextNoteContents ---------------------------------------------------

    test('contextNoteContents map is stored as provided', () {
      const contents = {
        'note-1': 'First note content',
        'note-2': 'Second note content',
      };
      const session = ChatSession(
        id: 'test',
        contextNoteContents: contents,
      );

      expect(session.contextNoteContents.length, 2);
      expect(session.contextNoteContents['note-1'], 'First note content');
      expect(session.contextNoteContents['note-2'], 'Second note content');
    });

    // -- Const construction ----------------------------------------------------

    test('const constructor allows compile-time constants', () {
      const session1 = ChatSession(id: 'test');
      const session2 = ChatSession(id: 'test');

      expect(session1.id, session2.id);
      expect(session1.isLoading, session2.isLoading);
    });
  });
}
