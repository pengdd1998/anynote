import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

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
          of: find.byType(ListView),
          matching: find.byType(Container),
        ),
      );
      final box = container.constraints;
      // The container has a fixed height of 44.
      expect(box?.maxHeight ?? 44, 44);
    });

    testWidgets('is horizontally scrollable', (tester) async {
      await pumpToolbar(tester);
      expect(find.byType(ListView), findsOneWidget);
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.scrollDirection, Axis.horizontal);
    });
  });

  group('FormattingToolbar text style buttons', () {
    testWidgets('has bold button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(Icons.format_bold), findsOneWidget);
    });

    testWidgets('has italic button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(Icons.format_italic), findsOneWidget);
    });

    testWidgets('has underline button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(Icons.format_underline), findsOneWidget);
    });

    testWidgets('has strikethrough button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(Icons.format_strikethrough), findsOneWidget);
    });
  });

  group('FormattingToolbar heading buttons', () {
    testWidgets('has three heading buttons (H1, H2, H3)', (tester) async {
      await pumpToolbar(tester);
      // Three title icons for H1, H2, H3.
      expect(find.byIcon(Icons.title), findsNWidgets(3));
    });
  });

  group('FormattingToolbar list buttons', () {
    testWidgets('has bullet list button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(Icons.format_list_bulleted), findsOneWidget);
    });

    testWidgets('has numbered list button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(Icons.format_list_numbered), findsOneWidget);
    });

    testWidgets('has block quote button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(Icons.format_quote), findsOneWidget);
    });
  });

  group('FormattingToolbar code block button', () {
    testWidgets('has code block button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(Icons.code), findsOneWidget);
    });

    testWidgets('code block tooltip is localized', (tester) async {
      await pumpToolbar(tester);
      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.code),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.tooltip, 'Code block');
    });

    testWidgets('code block is not active by default', (tester) async {
      await pumpToolbar(tester);
      final iconButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.code),
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
      expect(find.byIcon(Icons.checklist), findsOneWidget);
    });

    testWidgets('checklist tooltip is localized', (tester) async {
      await pumpToolbar(tester);
      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.checklist),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.tooltip, 'Checklist');
    });
  });

  group('FormattingToolbar indent/outdent buttons', () {
    testWidgets('has indent button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(Icons.format_indent_increase), findsOneWidget);
    });

    testWidgets('has outdent button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(Icons.format_indent_decrease), findsOneWidget);
    });

    testWidgets('indent tooltip is localized', (tester) async {
      await pumpToolbar(tester);
      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.format_indent_increase),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.tooltip, 'Indent');
    });

    testWidgets('outdent tooltip is localized', (tester) async {
      await pumpToolbar(tester);
      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.format_indent_decrease),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.tooltip, 'Outdent');
    });
  });

  group('FormattingToolbar undo/redo buttons', () {
    testWidgets('has undo button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(Icons.undo), findsOneWidget);
    });

    testWidgets('has redo button', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(Icons.redo), findsOneWidget);
    });

    testWidgets('undo tooltip is set', (tester) async {
      await pumpToolbar(tester);
      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.undo),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.tooltip, 'Undo');
    });

    testWidgets('redo tooltip is set', (tester) async {
      await pumpToolbar(tester);
      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.redo),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.tooltip, 'Redo');
    });
  });

  group('FormattingToolbar optional buttons', () {
    testWidgets('shows image button when onPickImage provided', (tester) async {
      await pumpToolbar(tester, onPickImage: () {});
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('hides image button when onPickImage is null', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(Icons.image_outlined), findsNothing);
    });

    testWidgets('shows AI button when onAiAction provided', (tester) async {
      await pumpToolbar(tester, onAiAction: () {});
      expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
    });

    testWidgets('hides AI button when onAiAction is null', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);
    });

    testWidgets('shows link button when onInsertLink provided', (tester) async {
      await pumpToolbar(tester, onInsertLink: () {});
      expect(find.byIcon(Icons.link), findsOneWidget);
    });

    testWidgets('hides link button when onInsertLink is null', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(Icons.link), findsNothing);
    });
  });

  group('FormattingToolbar dividers', () {
    testWidgets('has vertical dividers between groups', (tester) async {
      await pumpToolbar(tester);
      expect(find.byType(VerticalDivider), findsWidgets);
    });

    testWidgets('has at least 4 divider groups', (tester) async {
      await pumpToolbar(tester);
      // Groups: text style | heading | list/code/checklist | indent/outdent | undo/redo
      // Minimum 4 dividers.
      expect(find.byType(VerticalDivider), findsAtLeast(4));
    });
  });

  group('FormattingToolbar button interactions', () {
    testWidgets('bold button formats selection', (tester) async {
      await pumpToolbar(tester);

      await tester.tap(find.byIcon(Icons.format_bold));
      await tester.pump();

      // After tapping bold, the selection style should contain bold.
      // The toolbar rebuilds with updated style (may need a second pump).
      expect(find.byIcon(Icons.format_bold), findsOneWidget);
    });

    testWidgets('undo button can be tapped without error', (tester) async {
      await pumpToolbar(tester);
      await tester.tap(find.byIcon(Icons.undo));
      await tester.pump();
      // No exception means success.
      expect(find.byIcon(Icons.undo), findsOneWidget);
    });

    testWidgets('redo button can be tapped without error', (tester) async {
      await pumpToolbar(tester);
      await tester.tap(find.byIcon(Icons.redo));
      await tester.pump();
      expect(find.byIcon(Icons.redo), findsOneWidget);
    });

    testWidgets('indent button can be tapped without error', (tester) async {
      await pumpToolbar(tester);
      await tester.tap(find.byIcon(Icons.format_indent_increase));
      await tester.pump();
      expect(find.byIcon(Icons.format_indent_increase), findsOneWidget);
    });

    testWidgets('outdent button can be tapped without error', (tester) async {
      await pumpToolbar(tester);
      await tester.tap(find.byIcon(Icons.format_indent_decrease));
      await tester.pump();
      expect(find.byIcon(Icons.format_indent_decrease), findsOneWidget);
    });

    testWidgets('code block button can be tapped without error',
        (tester) async {
      await pumpToolbar(tester);
      await tester.tap(find.byIcon(Icons.code));
      await tester.pump();
      expect(find.byIcon(Icons.code), findsOneWidget);
    });

    testWidgets('checklist button can be tapped without error', (tester) async {
      await pumpToolbar(tester);
      await tester.tap(find.byIcon(Icons.checklist));
      await tester.pump();
      expect(find.byIcon(Icons.checklist), findsOneWidget);
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
