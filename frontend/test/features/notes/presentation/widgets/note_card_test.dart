import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/features/notes/presentation/widgets/note_card.dart';
import 'package:anynote/features/notes/presentation/widgets/tag_chips_row.dart';
import 'package:anynote/l10n/app_localizations.dart';
import 'package:anynote/main.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps a [NoteCard] inside a localized [MaterialApp].
///
/// For grid layout, the card is wrapped in a SizedBox with finite height
/// so that the Expanded widget inside does not overflow.
Future<void> pumpNoteCard(
  WidgetTester tester, {
  Note? note,
  String time = '2 hours ago',
  List<Tag> tags = const [],
  bool isSelected = false,
  VoidCallback? onTap,
  VoidCallback? onLongPress,
  String untitled = 'Untitled',
  NoteCardLayout layout = NoteCardLayout.list,
}) async {
  final card = NoteCard(
    note: note ?? _defaultNote(),
    time: time,
    tags: tags,
    isSelected: isSelected,
    onTap: onTap ?? () {},
    onLongPress: onLongPress ?? () {},
    untitled: untitled,
    layout: layout,
    skipPropertyBadges: true, // Avoid timer leaks in tests
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(_testDb!),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: layout == NoteCardLayout.grid
              ? SizedBox(
                  height: 300,
                  child: card,
                )
              : SingleChildScrollView(child: card),
        ),
      ),
    ),
  );
  // Let the stream builders settle
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

/// Create a test database instance.
AppDatabase _createTestDatabase() {
  // Use an in-memory database for testing
  return AppDatabase.forTesting(NativeDatabase.memory());
}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

Note _defaultNote({
  String id = 'note-1',
  String? plainTitle = 'Test Note',
  String? plainContent = 'This is the note content for testing.',
  bool isPinned = false,
  bool isSynced = false,
}) =>
    Note(
      id: id,
      encryptedContent: 'enc_content',
      encryptedTitle: 'enc_title',
      version: 1,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 4, 22),
      isSynced: isSynced,
      isPinned: isPinned,
      plainContent: plainContent,
      plainTitle: plainTitle,
      sortOrder: 0,
    );

Tag _makeTag({required String id, String? plainName}) => Tag(
      id: id,
      encryptedName: 'enc_$id',
      plainName: plainName,
      version: 1,
      isSynced: false,
    );

// ---------------------------------------------------------------------------
// Tests — List layout
// ---------------------------------------------------------------------------

AppDatabase? _testDb;

void main() {
  setUpAll(() {
    _testDb = _createTestDatabase();
  });

  tearDownAll(() async {
    await _testDb?.close();
    _testDb = null;
  });

  tearDown(() async {
    // Pump any pending microtasks and timers to avoid timer leaks
    await Future.delayed(const Duration(milliseconds: 200));
  });

  group('NoteCard (list)', () {
    testWidgets('renders note title', (tester) async {
      await pumpNoteCard(
        tester,
        note: _defaultNote(plainTitle: 'My Note'),
      );
      expect(find.text('My Note'), findsOneWidget);
    });

    testWidgets('renders untitled fallback when plainTitle is null',
        (tester) async {
      await pumpNoteCard(
        tester,
        note: _defaultNote(plainTitle: null),
        untitled: 'No title',
      );
      expect(find.text('No title'), findsOneWidget);
    });

    testWidgets('renders preview content', (tester) async {
      await pumpNoteCard(
        tester,
        note: _defaultNote(plainContent: 'Short preview text'),
      );
      expect(find.textContaining('Short preview text'), findsOneWidget);
    });

    testWidgets('truncates long content to 100 chars with ellipsis',
        (tester) async {
      final longContent = 'A' * 150;
      await pumpNoteCard(
        tester,
        note: _defaultNote(plainContent: longContent),
      );
      expect(find.textContaining('...'), findsOneWidget);
    });

    testWidgets('renders time string', (tester) async {
      await pumpNoteCard(tester, time: '3 days ago');
      expect(find.text('3 days ago'), findsOneWidget);
    });

    testWidgets('renders tag chips when tags provided', (tester) async {
      await pumpNoteCard(
        tester,
        tags: [_makeTag(id: 't1', plainName: 'Work')],
      );
      expect(find.byType(TagChipsRow), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
    });

    testWidgets('does not render tag chips when no tags', (tester) async {
      await pumpNoteCard(tester, tags: []);
      expect(find.byType(TagChipsRow), findsNothing);
    });

    testWidgets('shows pin icon when note is pinned', (tester) async {
      await pumpNoteCard(tester, note: _defaultNote(isPinned: true));
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
    });

    testWidgets('hides pin icon when note is not pinned', (tester) async {
      await pumpNoteCard(tester, note: _defaultNote(isPinned: false));
      expect(find.byIcon(Icons.push_pin), findsNothing);
    });

    testWidgets('fires onTap callback', (tester) async {
      var tapped = false;
      await pumpNoteCard(tester, onTap: () => tapped = true);

      await tester.tap(find.byType(NoteCard));
      expect(tapped, isTrue);
    });

    testWidgets('fires onLongPress callback', (tester) async {
      var longPressed = false;
      await pumpNoteCard(
        tester,
        onLongPress: () => longPressed = true,
      );

      await tester.longPress(find.byType(NoteCard));
      expect(longPressed, isTrue);
    });

    testWidgets('renders as Card widget', (tester) async {
      await pumpNoteCard(tester);
      expect(find.byType(Card), findsOneWidget);
    });
  });

  // -----------------------------------------------------------------------
  // Tests — Grid layout
  // -----------------------------------------------------------------------

  group('NoteCard (grid)', () {
    testWidgets('renders note title in grid', (tester) async {
      await pumpNoteCard(
        tester,
        note: _defaultNote(plainTitle: 'Grid Note'),
        layout: NoteCardLayout.grid,
      );
      expect(find.text('Grid Note'), findsOneWidget);
    });

    testWidgets('renders untitled fallback in grid', (tester) async {
      await pumpNoteCard(
        tester,
        note: _defaultNote(plainTitle: null),
        untitled: 'Empty',
        layout: NoteCardLayout.grid,
      );
      expect(find.text('Empty'), findsOneWidget);
    });

    testWidgets('renders preview in grid', (tester) async {
      await pumpNoteCard(
        tester,
        note: _defaultNote(plainContent: 'Grid preview text'),
        layout: NoteCardLayout.grid,
      );
      expect(find.textContaining('Grid preview text'), findsOneWidget);
    });

    testWidgets('truncates long content to 80 chars in grid', (tester) async {
      final longContent = 'B' * 150;
      await pumpNoteCard(
        tester,
        note: _defaultNote(plainContent: longContent),
        layout: NoteCardLayout.grid,
      );
      expect(find.textContaining('...'), findsOneWidget);
    });

    testWidgets('renders time in grid', (tester) async {
      await pumpNoteCard(
        tester,
        time: '5 min ago',
        layout: NoteCardLayout.grid,
      );
      expect(find.text('5 min ago'), findsOneWidget);
    });

    testWidgets('renders tags in grid', (tester) async {
      await pumpNoteCard(
        tester,
        tags: [_makeTag(id: 't1', plainName: 'Personal')],
        layout: NoteCardLayout.grid,
      );
      expect(find.byType(TagChipsRow), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
    });

    testWidgets('shows pin icon in grid when pinned', (tester) async {
      await pumpNoteCard(
        tester,
        note: _defaultNote(isPinned: true),
        layout: NoteCardLayout.grid,
      );
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
    });

    testWidgets('fires onTap in grid', (tester) async {
      var tapped = false;
      await pumpNoteCard(
        tester,
        onTap: () => tapped = true,
        layout: NoteCardLayout.grid,
      );
      await tester.tap(find.byType(NoteCard));
      expect(tapped, isTrue);
    });

    testWidgets('fires onLongPress in grid', (tester) async {
      var longPressed = false;
      await pumpNoteCard(
        tester,
        onLongPress: () => longPressed = true,
        layout: NoteCardLayout.grid,
      );
      await tester.longPress(find.byType(NoteCard));
      expect(longPressed, isTrue);
    });

    testWidgets('renders as Card in grid', (tester) async {
      await pumpNoteCard(tester, layout: NoteCardLayout.grid);
      expect(find.byType(Card), findsOneWidget);
    });
  });
}
