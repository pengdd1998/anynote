import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/features/notes/presentation/widgets/print_preview_sheet.dart';
import 'package:anynote/l10n/app_localizations.dart';

import '../../../../helpers/test_app_helper.dart';

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

Note _testNote({
  String id = 'note-1',
  String? plainTitle = 'Test Title',
  String? plainContent = 'This is the note content for testing.',
}) =>
    Note(
      id: id,
      encryptedContent: 'enc_content',
      encryptedTitle: 'enc_title',
      version: 1,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 4, 22),
      isSynced: false,
      isPinned: false,
      plainContent: plainContent,
      plainTitle: plainTitle,
      sortOrder: 0,
    );

/// Pump the [PrintPreviewSheet] inside a localized [MaterialApp].
Future<void> pumpPrintPreviewSheet(
  WidgetTester tester, {
  Note? note,
  String title = 'My Note',
  String content = 'This is the note content for the print preview.',
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...defaultProviderOverrides(), ...overrides],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => PrintPreviewSheet(
                      note: note ?? _testNote(),
                      title: title,
                      content: content,
                    ),
                  );
                },
                child: const Text('Open Sheet'),
              );
            },
          ),
        ),
      ),
    ),
  );

  // Open the bottom sheet.
  await tester.tap(find.text('Open Sheet'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PrintPreviewSheet', () {
    testWidgets('renders print preview title', (tester) async {
      await pumpPrintPreviewSheet(tester);

      expect(find.text('Print preview'), findsOneWidget);
    });

    testWidgets('renders note title in preview card', (tester) async {
      await pumpPrintPreviewSheet(tester, title: 'My Test Note');

      expect(find.text('My Test Note'), findsOneWidget);
    });

    testWidgets('renders untitled fallback when title is empty',
        (tester) async {
      await pumpPrintPreviewSheet(tester, title: '');

      // The app uses l10n.untitled when title is empty
      expect(find.text('Untitled'), findsOneWidget);
    });

    testWidgets('renders content preview in preview card', (tester) async {
      await pumpPrintPreviewSheet(
        tester,
        content: 'Short preview text that fits',
      );

      expect(find.textContaining('Short preview text'), findsOneWidget);
    });

    testWidgets('truncates long content to 200 chars with ellipsis',
        (tester) async {
      final longContent = 'A' * 250;
      await pumpPrintPreviewSheet(tester, content: longContent);

      expect(find.textContaining('...'), findsWidgets);
    });

    testWidgets('renders include metadata toggle', (tester) async {
      await pumpPrintPreviewSheet(tester);

      expect(find.text('Include metadata'), findsOneWidget);
    });

    testWidgets('renders include images toggle', (tester) async {
      await pumpPrintPreviewSheet(tester);

      expect(find.text('Include images'), findsOneWidget);
    });

    testWidgets('metadata toggle can be switched off', (tester) async {
      await pumpPrintPreviewSheet(tester);

      // Find the switch for includeMetadata. There are two SwitchListTiles;
      // the first one is for metadata, the second for images.
      final switches = find.byType(SwitchListTile);
      expect(switches, findsNWidgets(2));

      // Tap the first switch (metadata).
      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      final updatedSwitch = tester.widgetList<SwitchListTile>(switches).first;
      expect(updatedSwitch.value, isFalse);
    });

    testWidgets('renders copy to clipboard button', (tester) async {
      await pumpPrintPreviewSheet(tester);

      expect(find.text('Copy to Clipboard'), findsOneWidget);
    });

    testWidgets('renders share as HTML button', (tester) async {
      await pumpPrintPreviewSheet(tester);

      expect(find.text('Share as HTML'), findsOneWidget);
    });

    testWidgets('copy to clipboard button triggers clipboard write',
        (tester) async {
      // Intercept clipboard calls.
      final log = <String>[];
      TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final data = methodCall.arguments as Map;
            log.add(data['text'] as String);
          }
          return null;
        },
      );

      await pumpPrintPreviewSheet(
        tester,
        title: 'ClipTest',
        content: 'clip content',
      );

      await tester.tap(find.text('Copy to Clipboard'));
      await tester.pumpAndSettle();

      // Verify clipboard was written with the note content.
      expect(log, isNotEmpty);
      expect(log.first, contains('ClipTest'));
      expect(log.first, contains('clip content'));

      // Verify snackbar.
      expect(find.text('Copied to clipboard'), findsOneWidget);

      // Clean up.
      TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('has both OutlinedButton and FilledButton for actions',
        (tester) async {
      await pumpPrintPreviewSheet(tester);

      // The "Copy to Clipboard" button is an OutlinedButton.
      // The "Share as HTML" button is a FilledButton.
      // There may also be an ElevatedButton from the test harness.
      expect(
        find.widgetWithText(OutlinedButton, 'Copy to Clipboard'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Share as HTML'),
        findsOneWidget,
      );
    });
  });
}
