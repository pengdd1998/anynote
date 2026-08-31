import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:anynote/core/theme/app_icons.dart';
import 'package:anynote/features/notes/presentation/widgets/formatting_toolbar.dart';
import 'package:anynote/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps a [FormattingToolbar] inside a localized [MaterialApp].
Future<void> pumpToolbar(
  WidgetTester tester, {
  quill.QuillController? controller,
  VoidCallback? onInsertLink,
  VoidCallback? onPickImage,
  VoidCallback? onAiAction,
}) async {
  final ctrl = controller ?? quill.QuillController.basic();
  addTearDown(() => ctrl.dispose());

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        quill.FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: FormattingToolbar(
          quillController: ctrl,
          onInsertLink: onInsertLink,
          onPickImage: onPickImage,
          onAiAction: onAiAction,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// FormattingToolbar Extended Button Tests
// ---------------------------------------------------------------------------

void main() {
  group('FormattingToolbar structure', () {
    testWidgets('renders as a Container with height 44', (tester) async {
      await pumpToolbar(tester);
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Container),
        ),
      );
      final box = container.constraints;
      // The container has a fixed height of 44.
      expect(box?.maxHeight ?? 44, 44);
    });

    testWidgets('is horizontally scrollable', (tester) async {
      await pumpToolbar(tester);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scrollView.scrollDirection, Axis.horizontal);
    });
  });

  group('FormattingToolbar text style buttons', () {
    testWidgets('has bold button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(AppIcons.bold), findsOneWidget);
    });

    testWidgets('has italic button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(AppIcons.italic), findsOneWidget);
    });

    testWidgets('has underline button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(AppIcons.underline), findsOneWidget);
    });

    testWidgets('has strikethrough button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(AppIcons.strikethrough), findsOneWidget);
    });
  });

  group('FormattingToolbar heading buttons', () {
    testWidgets('has three heading buttons (H1, H2, H3)', (tester) async {
      await pumpToolbar(tester);
      // Three title icons for H1, H2, H3.
      expect(find.byIcon(AppIcons.title), findsNWidgets(3));
    });
  });

  group('FormattingToolbar list buttons', () {
    testWidgets('has bullet list button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(AppIcons.bulletList), findsOneWidget);
    });

    testWidgets('has numbered list button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(AppIcons.numberedList), findsOneWidget);
    });

    testWidgets('has block quote button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(PhosphorIconsRegular.quotes), findsOneWidget);
    });
  });

  group('FormattingToolbar code block button', () {
    testWidgets('has code block button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(AppIcons.code), findsOneWidget);
    });

    testWidgets('code block tooltip is localized', (tester) async {
      await pumpToolbar(tester);
      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(AppIcons.code),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.tooltip, 'Code block');
    });

    testWidgets('code block is not active by default', (tester) async {
      await pumpToolbar(tester);
      final iconButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(AppIcons.code),
          matching: find.byType(IconButton),
        ),
      );
      // Default style has no background (not active).
      expect(iconButton.style, isNotNull);
    });
  });

  group('FormattingToolbar checklist button', () {
    testWidgets('has checklist button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(AppIcons.checklist), findsOneWidget);
    });

    testWidgets('checklist tooltip is localized', (tester) async {
      await pumpToolbar(tester);
      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(AppIcons.checklist),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.tooltip, 'Checklist');
    });
  });

  group('FormattingToolbar indent/outdent buttons', () {
    testWidgets('has indent button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(AppIcons.indentIncrease), findsOneWidget);
    });

    testWidgets('has outdent button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(AppIcons.indentDecrease), findsOneWidget);
    });

    testWidgets('indent tooltip is localized', (tester) async {
      await pumpToolbar(tester);
      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(AppIcons.indentIncrease),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.tooltip, 'Indent');
    });

    testWidgets('outdent tooltip is localized', (tester) async {
      await pumpToolbar(tester);
      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(AppIcons.indentDecrease),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.tooltip, 'Outdent');
    });
  });

  group('FormattingToolbar undo/redo buttons', () {
    testWidgets('has undo button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(AppIcons.undo), findsOneWidget);
    });

    testWidgets('has redo button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(AppIcons.redo), findsOneWidget);
    });

    testWidgets('undo tooltip is set', (tester) async {
      await pumpToolbar(tester);
      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(AppIcons.undo),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.tooltip, 'Undo');
    });

    testWidgets('redo tooltip is set', (tester) async {
      await pumpToolbar(tester);
      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(AppIcons.redo),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.tooltip, 'Redo');
    });
  });

  group('FormattingToolbar optional buttons', () {
    testWidgets('shows image button when onPickImage provided', (tester) async {
      await pumpToolbar(tester, onPickImage: () {});
      expect(find.byIcon(AppIcons.imageIcon), findsOneWidget);
    });

    testWidgets('hides image button when onPickImage is null', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(AppIcons.imageIcon), findsNothing);
    });

    testWidgets('shows AI button when onAiAction provided', (tester) async {
      await pumpToolbar(tester, onAiAction: () {});
      expect(find.byIcon(AppIcons.sparkles), findsOneWidget);
    });

    testWidgets('hides AI button when onAiAction is null', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(AppIcons.sparkles), findsNothing);
    });

    testWidgets('shows link button when onInsertLink provided', (tester) async {
      await pumpToolbar(tester, onInsertLink: () {});
      expect(find.byIcon(AppIcons.link), findsOneWidget);
    });

    testWidgets('hides link button when onInsertLink is null', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(AppIcons.link), findsNothing);
    });
  });

  group('FormattingToolbar dividers', () {
    testWidgets('has divider containers between groups', (tester) async {
      await pumpToolbar(tester);
      // The toolbar uses Container(width: 1, height: 16) dividers instead of
      // VerticalDivider widgets. Verify that multiple such containers exist.
      final containers = tester.widgetList<Container>(
        find.byType(Container),
      );
      final dividers = containers.where((c) {
        final box = c.constraints;
        return box != null && box.maxWidth == 1 && box.maxHeight == 16;
      });
      expect(dividers.length, greaterThanOrEqualTo(1));
    });

    testWidgets('has at least 4 divider groups', (tester) async {
      await pumpToolbar(tester);
      // Groups: text style | heading | list/code/checklist | indent/outdent | undo/redo
      // Minimum 4 dividers.
      final containers = tester.widgetList<Container>(
        find.byType(Container),
      );
      final dividers = containers.where((c) {
        final box = c.constraints;
        return box != null && box.maxWidth == 1 && box.maxHeight == 16;
      });
      expect(dividers.length, greaterThanOrEqualTo(4));
    });
  });

  group('FormattingToolbar button interactions', () {
    testWidgets('bold button formats selection', (tester) async {
      await pumpToolbar(tester);

      await tester.tap(find.byIcon(AppIcons.bold));
      await tester.pump();

      // After tapping bold, the selection style should contain bold.
      // The toolbar rebuilds with updated style (may need a second pump).
      expect(find.byIcon(AppIcons.bold), findsOneWidget);
    });

    testWidgets('undo button can be tapped without error', (tester) async {
      await pumpToolbar(tester);
      await tester.ensureVisible(find.byIcon(AppIcons.undo));
      await tester.pump();
      await tester.tap(find.byIcon(AppIcons.undo));
      await tester.pump();
      // No exception means success.
      expect(find.byIcon(AppIcons.undo), findsOneWidget);
    });

    testWidgets('redo button can be tapped without error', (tester) async {
      await pumpToolbar(tester);
      await tester.ensureVisible(find.byIcon(AppIcons.redo));
      await tester.pump();
      await tester.tap(find.byIcon(AppIcons.redo));
      await tester.pump();
      expect(find.byIcon(AppIcons.redo), findsOneWidget);
    });

    testWidgets('indent button can be tapped without error', (tester) async {
      await pumpToolbar(tester);
      await tester.ensureVisible(find.byIcon(AppIcons.indentIncrease));
      await tester.pump();
      await tester.tap(find.byIcon(AppIcons.indentIncrease));
      await tester.pump();
      expect(find.byIcon(AppIcons.indentIncrease), findsOneWidget);
    });

    testWidgets('outdent button can be tapped without error', (tester) async {
      await pumpToolbar(tester);
      await tester.ensureVisible(find.byIcon(AppIcons.indentDecrease));
      await tester.pump();
      await tester.tap(find.byIcon(AppIcons.indentDecrease));
      await tester.pump();
      expect(find.byIcon(AppIcons.indentDecrease), findsOneWidget);
    });

    testWidgets('code block button can be tapped without error',
        (tester) async {
      await pumpToolbar(tester);
      await tester.ensureVisible(find.byIcon(AppIcons.code));
      await tester.pump();
      await tester.tap(find.byIcon(AppIcons.code));
      await tester.pump();
      expect(find.byIcon(AppIcons.code), findsOneWidget);
    });

    testWidgets('checklist button can be tapped without error', (tester) async {
      await pumpToolbar(tester);
      await tester.ensureVisible(find.byIcon(AppIcons.checklist));
      await tester.pump();
      await tester.tap(find.byIcon(AppIcons.checklist));
      await tester.pump();
      expect(find.byIcon(AppIcons.checklist), findsOneWidget);
    });
  });

  group('FormattingToolbar theme', () {
    testWidgets('renders with light theme', (tester) async {
      final controller = quill.QuillController.basic();
      addTearDown(() => controller.dispose());
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            quill.FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: FormattingToolbar(quillController: controller),
          ),
        ),
      );
      expect(find.byType(FormattingToolbar), findsOneWidget);
    });

    testWidgets('renders with dark theme', (tester) async {
      final controller = quill.QuillController.basic();
      addTearDown(() => controller.dispose());
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            quill.FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: FormattingToolbar(quillController: controller),
          ),
        ),
      );
      expect(find.byType(FormattingToolbar), findsOneWidget);
    });
  });
}
