import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/widgets/markdown_preview.dart';
import 'package:anynote/l10n/app_localizations.dart';

// ===========================================================================
// Tests
// ===========================================================================

void main() {
  // =========================================================================
  // MarkdownPreview rendering
  // =========================================================================

  group('MarkdownPreview', () {
    testWidgets('renders plain text content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(content: 'Hello world'),
          ),
        ),
      );

      expect(find.text('Hello world'), findsOneWidget);
    });

    testWidgets('renders empty content without crashing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(content: ''),
          ),
        ),
      );

      // Should not throw. An empty MarkdownBody renders nothing.
      expect(find.byType(MarkdownPreview), findsOneWidget);
    });

    testWidgets('renders heading text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(content: '# Main Title'),
          ),
        ),
      );

      // With selectable: true, MarkdownBody uses SelectableText rather than
      // RichText, so verify the heading text is present in the tree.
      expect(find.text('Main Title'), findsOneWidget);
    });

    testWidgets('renders bold text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(content: 'This is **bold** text'),
          ),
        ),
      );

      // Should render without error. Bold text is rendered inline.
      expect(find.byType(MarkdownPreview), findsOneWidget);
    });

    testWidgets('renders italic text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(content: 'This is *italic* text'),
          ),
        ),
      );

      // Should render without error. Italic text is rendered inline.
      expect(find.byType(MarkdownPreview), findsOneWidget);
    });

    testWidgets('renders inline code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(content: 'Use `print()` to debug'),
          ),
        ),
      );

      // Inline code should be rendered, possibly as styled text.
      expect(find.byType(MarkdownPreview), findsOneWidget);
    });

    testWidgets('renders code block', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(content: '```dart\nprint("hello");\n```'),
          ),
        ),
      );

      // Code block content should be rendered.
      expect(find.text('print("hello");'), findsOneWidget);
    });

    testWidgets('renders unordered list', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(
              content: '- Item one\n- Item two\n- Item three',
            ),
          ),
        ),
      );

      expect(find.text('Item one'), findsOneWidget);
      expect(find.text('Item two'), findsOneWidget);
      expect(find.text('Item three'), findsOneWidget);
    });

    testWidgets('renders blockquote', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(content: '> This is a quote'),
          ),
        ),
      );

      expect(find.text('This is a quote'), findsOneWidget);
    });

    testWidgets('renders link', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(
              content: 'Visit [Flutter](https://flutter.dev)',
            ),
          ),
        ),
      );

      // Link text is rendered inside a SelectableText's TextSpan children
      // (not as a standalone Text widget), so verify the widget exists.
      expect(find.byType(MarkdownPreview), findsOneWidget);
    });

    testWidgets('renders multiple headings', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(
              content: '# H1\n## H2\n### H3\n#### H4',
            ),
          ),
        ),
      );

      expect(find.text('H1'), findsOneWidget);
      expect(find.text('H2'), findsOneWidget);
      expect(find.text('H3'), findsOneWidget);
      expect(find.text('H4'), findsOneWidget);
    });

    testWidgets('renders horizontal rule', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(content: 'Above\n---\nBelow'),
          ),
        ),
      );

      expect(find.text('Above'), findsOneWidget);
      expect(find.text('Below'), findsOneWidget);
    });

    testWidgets('renders mixed content with headings and paragraphs',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(
              content: '# Title\n\nFirst paragraph.\n\nSecond paragraph.',
            ),
          ),
        ),
      );

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('First paragraph.'), findsOneWidget);
      expect(find.text('Second paragraph.'), findsOneWidget);
    });
  });

  // =========================================================================
  // MarkdownPreview with long content
  // =========================================================================

  group('MarkdownPreview long content', () {
    testWidgets('renders long plain text content', (tester) async {
      final longText = 'A' * 10000;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarkdownPreview(content: longText),
            ),
          ),
        ),
      );

      expect(find.byType(MarkdownPreview), findsOneWidget);
    });

    testWidgets('renders many paragraphs', (tester) async {
      final buffer = StringBuffer();
      for (var i = 0; i < 100; i++) {
        buffer.writeln('Paragraph $i content here.');
        buffer.writeln();
      }

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarkdownPreview(content: buffer.toString()),
            ),
          ),
        ),
      );

      expect(find.text('Paragraph 0 content here.'), findsOneWidget);
      expect(find.text('Paragraph 99 content here.'), findsOneWidget);
    });

    testWidgets('renders many code blocks', (tester) async {
      final buffer = StringBuffer();
      for (var i = 0; i < 20; i++) {
        buffer.writeln('```dart');
        buffer.writeln('print($i);');
        buffer.writeln('```');
        buffer.writeln();
      }

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarkdownPreview(content: buffer.toString()),
            ),
          ),
        ),
      );

      // Each code block renders its content as selectable text.
      expect(find.text('print(0);'), findsOneWidget);
      expect(find.text('print(19);'), findsOneWidget);
    });
  });

  // =========================================================================
  // MarkdownPreview dark mode
  // =========================================================================

  group('MarkdownPreview theme adaptation', () {
    testWidgets('renders with dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
          home: const Scaffold(
            body: MarkdownPreview(
              content: '# Dark Title\n\nSome content here.',
            ),
          ),
        ),
      );

      expect(find.text('Dark Title'), findsOneWidget);
      expect(find.text('Some content here.'), findsOneWidget);
    });

    testWidgets('renders code block in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
          home: const Scaffold(
            body: MarkdownPreview(
              content: '```python\nprint("dark mode")\n```',
            ),
          ),
        ),
      );

      // Code block content should render in dark mode.
      expect(find.text('print("dark mode")'), findsOneWidget);
    });
  });

  // =========================================================================
  // MarkdownPreview LaTeX handling
  // =========================================================================

  group('MarkdownPreview LaTeX', () {
    testWidgets('showLaTeX=false skips LaTeX processing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(
              content: 'Inline \$x^2\$ math',
              showLaTeX: false,
            ),
          ),
        ),
      );

      // With LaTeX disabled, the raw text is rendered as-is through markdown.
      expect(find.byType(MarkdownPreview), findsOneWidget);
    });

    testWidgets('showLaTeX=true (default) handles block LaTeX',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(
              content: 'Some text\n\n\$\$E = mc^2\$\$\n\nMore text',
            ),
          ),
        ),
      );

      expect(find.text('Some text'), findsOneWidget);
      expect(find.text('More text'), findsOneWidget);
    });

    testWidgets('handles content with only inline LaTeX', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(
              content: 'The equation \$a + b = c\$ is simple.',
            ),
          ),
        ),
      );

      expect(find.byType(MarkdownPreview), findsOneWidget);
    });

    testWidgets('handles content with no LaTeX gracefully', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(
              content: 'Just a regular paragraph with no math.',
            ),
          ),
        ),
      );

      expect(find.text('Just a regular paragraph with no math.'), findsOneWidget);
    });
  });

  // =========================================================================
  // MarkdownPreview edge cases
  // =========================================================================

  group('MarkdownPreview edge cases', () {
    testWidgets('renders content with only whitespace', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(content: '   \n\n   '),
          ),
        ),
      );

      expect(find.byType(MarkdownPreview), findsOneWidget);
    });

    testWidgets('renders content with special characters', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(
              content: "Special chars: < > & \" ' / \\",
            ),
          ),
        ),
      );

      expect(find.byType(MarkdownPreview), findsOneWidget);
    });

    testWidgets('renders nested formatting', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(
              content: '**Bold and *italic* together**',
            ),
          ),
        ),
      );

      expect(find.byType(MarkdownPreview), findsOneWidget);
    });

    testWidgets('renders numbered list', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(
              content: '1. First\n2. Second\n3. Third',
            ),
          ),
        ),
      );

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('Third'), findsOneWidget);
    });

    testWidgets('renders image markdown without crashing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(
              content: '![Alt text](https://example.com/image.png)',
            ),
          ),
        ),
      );

      // Image rendering depends on the markdown package's image builder.
      // At minimum it should not crash.
      expect(find.byType(MarkdownPreview), findsOneWidget);
    });

    testWidgets('renders table without crashing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(
              content: '| A | B |\n|---|---|\n| 1 | 2 |',
            ),
          ),
        ),
      );

      expect(find.byType(MarkdownPreview), findsOneWidget);
    });

    testWidgets('renders HTML-like content in markdown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: MarkdownPreview(
              content: '<br>\n<hr>',
            ),
          ),
        ),
      );

      // Should not crash on HTML-like input.
      expect(find.byType(MarkdownPreview), findsOneWidget);
    });
  });
}
