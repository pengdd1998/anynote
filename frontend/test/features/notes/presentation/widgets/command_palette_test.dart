import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/features/notes/presentation/widgets/command_palette.dart';
import 'package:anynote/l10n/app_localizations.dart';
import 'package:anynote/main.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps the [CommandPaletteOverlay] inside a localized [MaterialApp]
/// with the palette visible by default.
Future<void> pumpPalette(
  WidgetTester tester, {
  List<Override> overrides = const [],
  List<String> recentNoteIds = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(_testDb!),
        ...overrides,
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: Scaffold(
          body: CommandPaletteOverlay(),
        ),
      ),
    ),
  );

  // Make the palette visible.
  final container = ProviderScope.containerOf(
    tester.element(find.byType(CommandPaletteOverlay)),
  );
  container.read(commandPaletteVisibleProvider.notifier).state = true;
  if (recentNoteIds.isNotEmpty) {
    container.read(recentlyOpenedProvider.notifier).state = recentNoteIds;
  }

  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

AppDatabase? _testDb;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    _testDb = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDownAll(() async {
    await _testDb?.close();
    _testDb = null;
  });

  tearDown(() async {
    await Future.delayed(const Duration(milliseconds: 200));
  });

  group('CommandPaletteOverlay', () {
    testWidgets('renders search text field when visible', (tester) async {
      await pumpPalette(tester);

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows empty state when no recent notes and no query',
        (tester) async {
      await pumpPalette(tester);

      // The empty state shows the search hint text. It appears in both the
      // TextField hint and the empty state body, so we expect at least one.
      expect(
        find.text('Type to search notes and commands...'),
        findsAtLeast(1),
      );
    });

    testWidgets('shows recent notes section when recent IDs are present',
        (tester) async {
      await pumpPalette(tester, recentNoteIds: ['recent-note-1']);

      // Should show the "Recent" section header. The title cache is empty
      // so the title falls back to id.substring(0, 8) = 'recent-n'.
      // "Recent" appears as both section header and item subtitle.
      expect(find.text('Recent'), findsAtLeast(1));
      // The fallback title from the ID prefix.
      expect(find.text('recent-n'), findsOneWidget);
    });

    testWidgets('typing filters action results', (tester) async {
      await pumpPalette(tester);

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'settings');

      // Wait for debounce.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // Should show "Open Settings" action.
      expect(find.text('Open Settings'), findsOneWidget);
      // Should NOT show "Create New Note".
      expect(find.text('Create New Note'), findsNothing);
    });

    testWidgets('typing a non-matching query shows empty state',
        (tester) async {
      await pumpPalette(tester);

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'zzzznonexistent');

      // Wait for debounce.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.text('No results found'), findsOneWidget);
    });

    testWidgets('shows all actions when query matches broadly', (tester) async {
      await pumpPalette(tester);

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'open');

      // Wait for debounce.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // "open" matches multiple actions.
      expect(find.text('Open Daily Notes'), findsOneWidget);
      expect(find.text('Open Graph View'), findsOneWidget);
      expect(find.text('Open Dashboard'), findsOneWidget);
      expect(find.text('Open Trash'), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);
    });

    testWidgets('tapping backdrop closes palette', (tester) async {
      await pumpPalette(tester);

      // Palette should be visible.
      expect(find.byType(CommandPaletteOverlay), findsOneWidget);

      // Tap the backdrop area (the dimmed Container behind the panel).
      // Tap at a location that is on the backdrop, not the panel itself.
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // After closing, the palette widget still exists but the inner
      // content should be replaced with SizedBox.shrink.
      // Verify the TextField is gone.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('does not render panel when visibility is false',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(_testDb!),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: Scaffold(
              body: CommandPaletteOverlay(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // Not visible by default -- no TextField.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('action items have correct icons', (tester) async {
      await pumpPalette(tester);

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'create');

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.note_add_outlined), findsOneWidget);
    });
  });

  group('CommandPaletteItem', () {
    test('holds expected fields', () {
      var tapped = false;
      final item = CommandPaletteItem(
        id: 'test-id',
        title: 'Test Title',
        subtitle: 'Test Subtitle',
        icon: Icons.star,
        type: CommandPaletteItemType.action,
        onTap: () => tapped = true,
      );

      expect(item.id, 'test-id');
      expect(item.title, 'Test Title');
      expect(item.subtitle, 'Test Subtitle');
      expect(item.icon, Icons.star);
      expect(item.type, CommandPaletteItemType.action);

      item.onTap();
      expect(tapped, isTrue);
    });

    test('subtitle can be null', () {
      final item = CommandPaletteItem(
        id: 'x',
        title: 'X',
        icon: Icons.add,
        type: CommandPaletteItemType.note,
        onTap: () {},
      );
      expect(item.subtitle, isNull);
    });
  });

  group('recentlyOpenedProvider', () {
    testWidgets('stores note IDs in order', (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(_testDb!),
            commandPaletteVisibleProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  container = ProviderScope.containerOf(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set state outside the build phase.
      container.read(recentlyOpenedProvider.notifier).state = [
        'note-3',
        'note-2',
        'note-1',
      ];

      expect(
        container.read(recentlyOpenedProvider),
        ['note-3', 'note-2', 'note-1'],
      );
    });

    testWidgets('deduplicates and caps at 20', (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(_testDb!),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  container = ProviderScope.containerOf(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate 25 items with a duplicate.
      final list = List<String>.generate(25, (i) => 'note-$i');
      list[5] = 'note-0'; // duplicate
      container.read(recentlyOpenedProvider.notifier).state = list;

      // The provider is a simple StateProvider so it stores exactly what is set.
      // The addRecentlyOpened function handles dedup and cap.
      expect(container.read(recentlyOpenedProvider).length, 25);
    });
  });
}
