import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/domain/note_reading_view.dart';

/// What the note page reads. The title is the body's first line, and it is
/// not the body's first line a second time.
void main() {
  const untitled = 'Untitled';

  group('a note without a stored title', () {
    test('plain: the first line is the title and leaves the body', () {
      final view = readingViewOf(
        content: 'Meeting notes\nAttendees: Mei, Li\nNext week: the deck.',
        storedTitle: untitled,
        untitled: untitled,
      );

      expect(view.title, 'Meeting notes');
      expect(view.content, 'Attendees: Mei, Li\nNext week: the deck.');
    });

    test('rich: the same, from a Delta', () {
      final view = readingViewOf(
        content: '[{"insert":"Meeting notes\\nAttendees: Mei\\n"}]',
        storedTitle: untitled,
        untitled: untitled,
      );

      expect(view.title, 'Meeting notes');
      expect(view.content, '[{"insert":"Attendees: Mei\\n"}]');
    });
  });

  group('a note with a stored title', () {
    test('that says what the first line says: the title is shown once', () {
      // Left by a test script that wrote the title into both fields; the
      // page read "Search Target Note XYZ" as its title and again above
      // its body.
      final view = readingViewOf(
        content: 'Search Target Note XYZ\nUnique keyword: ZEBRA-QA-42.',
        storedTitle: 'Search Target Note XYZ',
        untitled: untitled,
      );

      expect(view.title, 'Search Target Note XYZ');
      expect(view.content, 'Unique keyword: ZEBRA-QA-42.');
    });

    test('that is its own: it stays, and so does the whole body', () {
      final view = readingViewOf(
        content: 'Call Mei after lunch.\nThe deck needs one more example.',
        storedTitle: 'Things to do',
        untitled: untitled,
      );

      expect(view.title, 'Things to do');
      expect(
        view.content,
        'Call Mei after lunch.\nThe deck needs one more example.',
      );
    });

    test('an empty body: the title stays and nothing is stripped', () {
      final view = readingViewOf(
        content: '   \n',
        storedTitle: 'Things to do',
        untitled: untitled,
      );

      expect(view.title, 'Things to do');
      expect(view.content, '   \n');
    });
  });
}
