import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/widgets/writing_stats.dart';
import 'package:anynote/features/notes/presentation/widgets/writing_stats_bar.dart';
import 'package:anynote/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pump the [WritingStatsBar] inside a localized MaterialApp.
Future<void> pumpWritingStatsBar(
  WidgetTester tester, {
  WritingStats stats = WritingStats.empty,
  bool isVisible = true,
  VoidCallback? onToggleVisibility,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: WritingStatsBar(
          stats: stats,
          isVisible: isVisible,
          onToggleVisibility: onToggleVisibility ?? () {},
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('WritingStatsBar', () {
    testWidgets('renders word count when visible', (tester) async {
      final stats = WritingStats(
        wordCount: 42,
        charCount: 200,
        charCountNoSpaces: 170,
        lineCount: 10,
        paragraphCount: 3,
        estimatedReadingTime: const Duration(minutes: 1),
        isCJK: false,
      );

      await pumpWritingStatsBar(tester, stats: stats);

      expect(find.textContaining('42'), findsOneWidget);
    });

    testWidgets('renders character count when visible', (tester) async {
      final stats = WritingStats(
        wordCount: 10,
        charCount: 256,
        charCountNoSpaces: 220,
        lineCount: 5,
        paragraphCount: 2,
        estimatedReadingTime: Duration.zero,
        isCJK: false,
      );

      await pumpWritingStatsBar(tester, stats: stats);

      expect(find.textContaining('256'), findsOneWidget);
    });

    testWidgets('renders reading time for less than 1 minute', (tester) async {
      final stats = WritingStats(
        wordCount: 5,
        charCount: 20,
        charCountNoSpaces: 18,
        lineCount: 1,
        paragraphCount: 1,
        estimatedReadingTime: const Duration(seconds: 30),
        isCJK: false,
      );

      await pumpWritingStatsBar(tester, stats: stats);

      expect(find.text('Less than 1 min read'), findsOneWidget);
    });

    testWidgets('renders reading time for multiple minutes', (tester) async {
      final stats = WritingStats(
        wordCount: 400,
        charCount: 2000,
        charCountNoSpaces: 1700,
        lineCount: 50,
        paragraphCount: 10,
        estimatedReadingTime: const Duration(minutes: 5),
        isCJK: false,
      );

      await pumpWritingStatsBar(tester, stats: stats);

      expect(find.text('5 min read'), findsOneWidget);
    });

    testWidgets('renders line count', (tester) async {
      final stats = WritingStats(
        wordCount: 10,
        charCount: 50,
        charCountNoSpaces: 40,
        lineCount: 25,
        paragraphCount: 4,
        estimatedReadingTime: Duration.zero,
        isCJK: false,
      );

      await pumpWritingStatsBar(tester, stats: stats);

      expect(find.textContaining('25'), findsOneWidget);
    });

    testWidgets('renders paragraph count', (tester) async {
      final stats = WritingStats(
        wordCount: 10,
        charCount: 50,
        charCountNoSpaces: 40,
        lineCount: 5,
        paragraphCount: 7,
        estimatedReadingTime: Duration.zero,
        isCJK: false,
      );

      await pumpWritingStatsBar(tester, stats: stats);

      expect(find.textContaining('7'), findsOneWidget);
    });

    testWidgets('shows bar chart icon when visible', (tester) async {
      await pumpWritingStatsBar(tester, isVisible: true);

      expect(find.byIcon(Icons.bar_chart), findsOneWidget);
    });

    testWidgets('shows outlined bar chart icon when hidden', (tester) async {
      await pumpWritingStatsBar(tester, isVisible: false);

      expect(find.byIcon(Icons.bar_chart_outlined), findsOneWidget);
    });

    testWidgets('does not show stat chips when hidden', (tester) async {
      final stats = WritingStats(
        wordCount: 99,
        charCount: 500,
        charCountNoSpaces: 400,
        lineCount: 20,
        paragraphCount: 5,
        estimatedReadingTime: const Duration(minutes: 1),
        isCJK: false,
      );

      await pumpWritingStatsBar(tester, stats: stats, isVisible: false);

      // Stats should not be visible when the bar is hidden.
      expect(find.textContaining('99'), findsNothing);
      expect(find.textContaining('500'), findsNothing);
    });

    testWidgets('toggle button fires callback', (tester) async {
      var toggled = false;
      await pumpWritingStatsBar(
        tester,
        isVisible: true,
        onToggleVisibility: () => toggled = true,
      );

      await tester.tap(find.byIcon(Icons.bar_chart));
      expect(toggled, isTrue);
    });

    testWidgets('toggle button fires callback when hidden', (tester) async {
      var toggled = false;
      await pumpWritingStatsBar(
        tester,
        isVisible: false,
        onToggleVisibility: () => toggled = true,
      );

      await tester.tap(find.byIcon(Icons.bar_chart_outlined));
      expect(toggled, isTrue);
    });

    testWidgets('uses SafeArea', (tester) async {
      await pumpWritingStatsBar(tester);

      expect(find.byType(SafeArea), findsOneWidget);
    });

    testWidgets('updates stats when rebuilt with new values', (tester) async {
      final stats1 = WritingStats(
        wordCount: 10,
        charCount: 50,
        charCountNoSpaces: 40,
        lineCount: 3,
        paragraphCount: 1,
        estimatedReadingTime: Duration.zero,
        isCJK: false,
      );

      await pumpWritingStatsBar(tester, stats: stats1);
      expect(find.textContaining('10'), findsOneWidget);

      final stats2 = WritingStats(
        wordCount: 20,
        charCount: 100,
        charCountNoSpaces: 80,
        lineCount: 6,
        paragraphCount: 2,
        estimatedReadingTime: Duration.zero,
        isCJK: false,
      );

      await pumpWritingStatsBar(tester, stats: stats2);
      expect(find.textContaining('20'), findsOneWidget);
    });

    testWidgets('renders dividers between stat chips', (tester) async {
      final stats = WritingStats(
        wordCount: 10,
        charCount: 50,
        charCountNoSpaces: 40,
        lineCount: 3,
        paragraphCount: 1,
        estimatedReadingTime: Duration.zero,
        isCJK: false,
      );

      await pumpWritingStatsBar(tester, stats: stats);

      // The _StatDivider renders a '|' character. With 5 stats there should
      // be 4 dividers.
      expect(find.text('|'), findsNWidgets(4));
    });
  });
}
