import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/domain/note_statistics.dart';
import 'package:anynote/features/notes/presentation/widgets/statistics_screen.dart';
import 'package:anynote/features/search/data/statistics_providers.dart';
import '../../../../helpers/test_app_helper.dart';

// ---------------------------------------------------------------------------
// Sample statistics for testing
// ---------------------------------------------------------------------------

NoteStatistics _sampleStats() {
  return NoteStatistics(
    totalNotes: 42,
    totalWords: 12000,
    totalCharacters: 68000,
    notesWithProperties: 10,
    notesWithLinks: 5,
    orphanedNotes: 30,
    totalLinks: 15,
    notesByMonth: {'2026-03': 10, '2026-04': 32},
    wordsByMonth: {'2026-03': 3000, '2026-04': 9000},
    topTags: [
      const TagStat(tagName: 'flutter', noteCount: 12),
      const TagStat(tagName: 'dart', noteCount: 8),
    ],
    topCollections: [
      const CollectionStat(collectionTitle: 'Work', noteCount: 20),
      const CollectionStat(collectionTitle: 'Personal', noteCount: 10),
    ],
    writingStreak: const WritingStreak(
      currentStreak: 5,
      longestStreak: 12,
      activeDaysLast30: {'2026-04-20', '2026-04-21', '2026-04-22'},
    ),
    statusDistribution: {'Done': 20, 'Todo': 15, 'In Progress': 7},
    priorityDistribution: {'High': 10, 'Medium': 20, 'Low': 12},
    oldestNote: DateTime(2025, 1, 15),
    newestNote: DateTime(2026, 4, 25),
    averageWordsPerNote: 285.7,
    mostConnectedNote: const ConnectedNoteStat(
      noteId: 'note-1',
      noteTitle: 'Architecture Notes',
      linkCount: 8,
    ),
  );
}

NoteStatistics _emptyStats() {
  return const NoteStatistics(
    totalNotes: 0,
    totalWords: 0,
    totalCharacters: 0,
    notesWithProperties: 0,
    notesWithLinks: 0,
    orphanedNotes: 0,
    totalLinks: 0,
    notesByMonth: {},
    wordsByMonth: {},
    topTags: [],
    topCollections: [],
    writingStreak: const WritingStreak(
      currentStreak: 0,
      longestStreak: 0,
      activeDaysLast30: {},
    ),
    statusDistribution: {},
    priorityDistribution: {},
    averageWordsPerNote: 0.0,
  );
}

void main() {
  group('StatisticsScreen', () {
    testWidgets('shows loading indicator while statistics load',
        (tester) async {
      // Use a Completer that never completes to keep loading state.
      final completer = Completer<NoteStatistics>();
      final handle = await pumpScreen(
        tester,
        const StatisticsScreen(),
        overrides: [
          ...defaultProviderOverrides(),
          noteStatisticsProvider.overrideWith((ref) => completer.future),
        ],
      );
      addTearDown(() => handle.dispose());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows empty state when total notes is zero', (tester) async {
      final handle = await pumpScreen(
        tester,
        const StatisticsScreen(),
        overrides: [
          ...defaultProviderOverrides(),
          noteStatisticsProvider.overrideWith((ref) async => _emptyStats()),
        ],
      );
      addTearDown(() => handle.dispose());

      // Empty state shows the bar chart icon and fallback text.
      expect(find.byIcon(Icons.bar_chart_outlined), findsOneWidget);
      expect(find.text('No statistics yet'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows error state on failure', (tester) async {
      final handle = await pumpScreen(
        tester,
        const StatisticsScreen(),
        overrides: [
          ...defaultProviderOverrides(),
          noteStatisticsProvider.overrideWith((ref) async {
            throw Exception('Database error');
          }),
        ],
      );
      addTearDown(() => handle.dispose());

      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('renders overview cards with correct values', (tester) async {
      final handle = await pumpScreen(
        tester,
        const StatisticsScreen(),
        overrides: [
          ...defaultProviderOverrides(),
          noteStatisticsProvider.overrideWith((ref) async => _sampleStats()),
        ],
      );
      addTearDown(() => handle.dispose());

      // Overview card values.
      expect(find.text('42'),
          findsAtLeast(1)); // total notes (also in donut total)
      expect(find.text('12.0K'), findsOneWidget); // total words
      expect(find.text('286'), findsOneWidget); // avg words per note

      await handle.dispose();
    });

    testWidgets('renders writing streak section', (tester) async {
      final handle = await pumpScreen(
        tester,
        const StatisticsScreen(),
        overrides: [
          ...defaultProviderOverrides(),
          noteStatisticsProvider.overrideWith((ref) async => _sampleStats()),
        ],
      );
      addTearDown(() => handle.dispose());

      // Streak card shows fire icon and streak number.
      expect(find.byIcon(Icons.local_fire_department_outlined), findsOneWidget);
      expect(find.text('5'), findsWidgets); // current streak number

      await handle.dispose();
    });

    testWidgets('renders top tags section', (tester) async {
      final handle = await pumpScreen(
        tester,
        const StatisticsScreen(),
        overrides: [
          ...defaultProviderOverrides(),
          noteStatisticsProvider.overrideWith((ref) async => _sampleStats()),
        ],
      );
      addTearDown(() => handle.dispose());

      // Top tags should be rendered as Chips.
      expect(find.text('flutter'), findsOneWidget);
      expect(find.text('dart'), findsOneWidget);
      expect(find.byType(Chip), findsWidgets);

      await handle.dispose();
    });

    testWidgets('renders top collections section', (tester) async {
      final handle = await pumpScreen(
        tester,
        const StatisticsScreen(),
        overrides: [
          ...defaultProviderOverrides(),
          noteStatisticsProvider.overrideWith((ref) async => _sampleStats()),
        ],
      );
      addTearDown(() => handle.dispose());

      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
      // Progress indicators for collection bars.
      expect(find.byType(LinearProgressIndicator), findsWidgets);

      await handle.dispose();
    });

    testWidgets('renders knowledge graph section', (tester) async {
      final handle = await pumpScreen(
        tester,
        const StatisticsScreen(),
        overrides: [
          ...defaultProviderOverrides(),
          noteStatisticsProvider.overrideWith((ref) async => _sampleStats()),
        ],
      );
      addTearDown(() => handle.dispose());

      expect(find.byIcon(Icons.hub_outlined), findsOneWidget);
      expect(find.text('15'), findsOneWidget); // total links
      expect(find.text('Architecture Notes'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('renders monthly activity chart section', (tester) async {
      final handle = await pumpScreen(
        tester,
        const StatisticsScreen(),
        overrides: [
          ...defaultProviderOverrides(),
          noteStatisticsProvider.overrideWith((ref) async => _sampleStats()),
        ],
      );
      addTearDown(() => handle.dispose());

      // Monthly Activity header text.
      expect(find.text('Monthly Activity'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      await handle.dispose();
    });

    testWidgets('renders status distribution section', (tester) async {
      final handle = await pumpScreen(
        tester,
        const StatisticsScreen(),
        overrides: [
          ...defaultProviderOverrides(),
          noteStatisticsProvider.overrideWith((ref) async => _sampleStats()),
        ],
      );
      addTearDown(() => handle.dispose());

      // Status names should appear in the legend.
      expect(find.text('Status Distribution'), findsOneWidget);
      expect(find.textContaining('Done'), findsWidgets);
      expect(find.textContaining('Todo'), findsWidgets);

      await handle.dispose();
    });

    testWidgets('renders priority distribution section', (tester) async {
      final handle = await pumpScreen(
        tester,
        const StatisticsScreen(),
        overrides: [
          ...defaultProviderOverrides(),
          noteStatisticsProvider.overrideWith((ref) async => _sampleStats()),
        ],
      );
      addTearDown(() => handle.dispose());

      expect(find.text('Priority Distribution'), findsOneWidget);
      expect(find.textContaining('High'), findsWidgets);
      expect(find.textContaining('Medium'), findsWidgets);

      await handle.dispose();
    });

    testWidgets('overview number formatting for large numbers', (tester) async {
      const largeStats = NoteStatistics(
        totalNotes: 1500000,
        totalWords: 25000,
        totalCharacters: 150000,
        notesWithProperties: 0,
        notesWithLinks: 0,
        orphanedNotes: 0,
        totalLinks: 0,
        notesByMonth: {},
        wordsByMonth: {},
        topTags: [],
        topCollections: [],
        writingStreak: const WritingStreak(
          currentStreak: 0,
          longestStreak: 0,
          activeDaysLast30: {},
        ),
        statusDistribution: {},
        priorityDistribution: {},
        averageWordsPerNote: 0.0,
      );

      final handle = await pumpScreen(
        tester,
        const StatisticsScreen(),
        overrides: [
          ...defaultProviderOverrides(),
          noteStatisticsProvider.overrideWith((ref) async => largeStats),
        ],
      );
      addTearDown(() => handle.dispose());

      // 1500000 should format to "1.5M".
      expect(find.text('1.5M'), findsOneWidget);
      // 25000 should format to "25.0K".
      expect(find.text('25.0K'), findsOneWidget);

      await handle.dispose();
    });
  });
}
