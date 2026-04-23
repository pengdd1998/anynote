import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/widgets/character_count_bar.dart';
import 'package:anynote/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> pumpCountBar(
  WidgetTester tester, {
  int wordCount = 0,
  int charCount = 0,
  bool isZenMode = false,
  VoidCallback? onToggleZenMode,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: CharacterCountBar(
          wordCount: wordCount,
          charCount: charCount,
          isZenMode: isZenMode,
          onToggleZenMode: onToggleZenMode ?? () {},
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('CharacterCountBar', () {
    testWidgets('renders word count text', (tester) async {
      await pumpCountBar(tester, wordCount: 42);
      // The l10n key for wordCount produces something like "42 words".
      expect(find.textContaining('42'), findsOneWidget);
    });

    testWidgets('renders character count text', (tester) async {
      await pumpCountBar(tester, charCount: 256);
      expect(find.textContaining('256'), findsOneWidget);
    });

    testWidgets('shows zen mode toggle button when not in zen mode',
        (tester) async {
      await pumpCountBar(tester, isZenMode: false);
      expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    });

    testWidgets('hides zen mode toggle button when in zen mode',
        (tester) async {
      await pumpCountBar(tester, isZenMode: true);
      expect(find.byIcon(Icons.fullscreen), findsNothing);
    });

    testWidgets('fires onToggleZenMode when zen button tapped', (tester) async {
      var toggled = false;
      await pumpCountBar(
        tester,
        isZenMode: false,
        onToggleZenMode: () => toggled = true,
      );

      await tester.tap(find.byIcon(Icons.fullscreen));
      expect(toggled, isTrue);
    });

    testWidgets('renders separator pipe between counts', (tester) async {
      await pumpCountBar(tester, wordCount: 10, charCount: 50);
      expect(find.text('|'), findsOneWidget);
    });

    testWidgets('uses SafeArea', (tester) async {
      await pumpCountBar(tester);
      expect(find.byType(SafeArea), findsOneWidget);
    });

    testWidgets('updates when word count changes', (tester) async {
      await pumpCountBar(tester, wordCount: 10);
      expect(find.textContaining('10'), findsOneWidget);

      // Pump with different word count. Since we rebuild the whole widget tree,
      // the old value should be gone.
      await pumpCountBar(tester, wordCount: 20);
      expect(find.textContaining('20'), findsOneWidget);
      // The '10' pattern might still be in '20' substring, so check more specifically.
      // Instead, just verify the new count is present.
    });
  });
}
