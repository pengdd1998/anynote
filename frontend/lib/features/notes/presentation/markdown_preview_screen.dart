import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:share_plus/share_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';

/// Full-screen markdown preview with LaTeX math support.
///
/// Renders the decrypted [plainContent] of a note as rich markdown.
/// LaTeX math is handled via placeholder replacement before markdown
/// parsing, then substituted with [FlutterMath] widgets during rendering:
/// - `$$...$$` renders as centered block equations
/// - `$...$` renders as inline math
class MarkdownPreviewScreen extends ConsumerWidget {
  /// ID of the note to preview.
  final String noteId;

  const MarkdownPreviewScreen({super.key, required this.noteId});

  // Pre-compiled regex for block LaTeX ($$...$$).
  static final RegExp _blockLatexRegex = RegExp(
    r'\$\$([\s\S]*?)\$\$',
    multiLine: true,
  );

  // Pre-compiled regex for inline LaTeX ($...$).
  // Uses negative lookbehind/ahead to avoid matching currency.
  static final RegExp _inlineLatexRegex = RegExp(
    r'(?<!\$)\$(?!\$)(.*?)(?<!\$)\$(?!\$)',
    multiLine: true,
  );

  // Unique placeholder prefix for block LaTeX.
  static const _blockPlaceholderPrefix = '\x00LATEX_BLOCK_';

  // Unique placeholder prefix for inline LaTeX.
  static const _inlinePlaceholderPrefix = '\x00LATEX_INLINE_';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Note?>(
          future: db.notesDao.getNoteById(noteId),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Text(snapshot.data!.plainTitle ?? 'Preview');
            }
            return Text(AppLocalizations.of(context)?.preview ?? 'Preview');
          },
        ),
        actions: [
          FutureBuilder<Note?>(
            future: db.notesDao.getNoteById(noteId),
            builder: (context, snapshot) {
              if (snapshot.hasData &&
                  snapshot.data != null &&
                  snapshot.data!.plainContent != null) {
                return IconButton(
                  icon: const Icon(Icons.share_outlined),
                  tooltip:
                      AppLocalizations.of(context)?.shareViaLink ?? 'Share',
                  onPressed: () {
                    Share.share(snapshot.data!.plainContent!);
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: FutureBuilder<Note?>(
        future: db.notesDao.getNoteById(noteId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final l10n = AppLocalizations.of(context);

          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n?.noteNotFound ?? 'Note not found',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          final note = snapshot.data!;
          final content = note.plainContent;

          if (content == null || content.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n?.preview ?? 'Preview',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          return _MarkdownScrollView(content: content);
        },
      ),
    );
  }
}

/// Scrollable view that renders markdown with LaTeX math support.
///
/// Pre-processes the raw content to extract LaTeX expressions into
/// placeholders, then builds a [MarkdownBody] with custom element
/// builders that substitute the placeholders with [FlutterMath] widgets.
class _MarkdownScrollView extends StatelessWidget {
  final String content;

  const _MarkdownScrollView({required this.content});

  @override
  Widget build(BuildContext context) {
    final scrollController = ScrollController();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Phase 1: Extract LaTeX expressions and replace with placeholders.
    final List<String> latexExpressions = [];

    String processed = content;

    // Extract block LaTeX ($$...$$).
    processed = processed.replaceAllMapped(
      MarkdownPreviewScreen._blockLatexRegex,
      (match) {
        final index = latexExpressions.length;
        latexExpressions.add(match.group(1)!);
        return '\n${MarkdownPreviewScreen._blockPlaceholderPrefix}$index\n';
      },
    );

    // Extract inline LaTeX ($...$).
    processed = processed.replaceAllMapped(
      MarkdownPreviewScreen._inlineLatexRegex,
      (match) {
        final index = latexExpressions.length;
        latexExpressions.add(match.group(1)!);
        return '${MarkdownPreviewScreen._inlinePlaceholderPrefix}$index';
      },
    );

    // Build custom element builders.
    final builders = <String, MarkdownElementBuilder>{
      'pre': _CodeBlockBuilder(isDark: isDark),
    };

    if (latexExpressions.isNotEmpty) {
      builders['p'] = _LatexParagraphBuilder(
        latexExpressions: latexExpressions,
        blockPlaceholderPrefix:
            MarkdownPreviewScreen._blockPlaceholderPrefix,
        inlinePlaceholderPrefix:
            MarkdownPreviewScreen._inlinePlaceholderPrefix,
        textStyle: theme.textTheme.bodyLarge,
      );
    }

    // Code block background: warm fill from the design system.
    final codeBlockBg =
        isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;
    final codeBlockText =
        isDark ? const Color(0xFFF5F0EB) : const Color(0xFF2C2520);

    final styleSheet = MarkdownStyleSheet(
      p: TextStyle(
        fontSize: 16,
        height: 1.6,
        color: isDark ? const Color(0xFFF5F0EB) : const Color(0xFF2C2520),
      ),
      h1: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: isDark ? const Color(0xFFF5F0EB) : const Color(0xFF2C2520),
      ),
      h2: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: isDark ? const Color(0xFFF5F0EB) : const Color(0xFF2C2520),
      ),
      h3: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: isDark ? const Color(0xFFF5F0EB) : const Color(0xFF2C2520),
      ),
      h4: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: isDark ? const Color(0xFFF5F0EB) : const Color(0xFF2C2520),
      ),
      code: TextStyle(
        fontSize: 14,
        fontFamily: 'monospace',
        backgroundColor: codeBlockBg,
        color: codeBlockText,
      ),
      codeblockDecoration: BoxDecoration(
        color: codeBlockBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: isDark
              ? const Color(0xFF3D3835)
              : const Color(0xFFE8DFD5),
        ),
      ),
      codeblockAlign: WrapAlignment.start,
      blockquote: TextStyle(
        color: isDark
            ? const Color(0xFFA3988E)
            : const Color(0xFF6B5E54),
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        color: codeBlockBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      listBullet: TextStyle(
        color: isDark
            ? const Color(0xFFA3988E)
            : const Color(0xFF6B5E54),
      ),
      tableBody: TextStyle(
        fontSize: 14,
        color: isDark ? const Color(0xFFF5F0EB) : const Color(0xFF2C2520),
      ),
    );

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: MarkdownBody(
        data: processed,
        selectable: true,
        builders: builders,
        styleSheet: styleSheet,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Code block builder
// ---------------------------------------------------------------------------

/// Intercept `<pre>` elements to render code blocks with warm styling
/// and horizontal scrolling.
class _CodeBlockBuilder extends MarkdownElementBuilder {
  final bool isDark;

  _CodeBlockBuilder({required this.isDark});

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    String code = '';
    if (element.children != null && element.children!.isNotEmpty) {
      final codeElement = element.children!.first;
      if (codeElement is md.Element && codeElement.tag == 'code') {
        code = codeElement.textContent;
      } else {
        code = element.textContent;
      }
    } else {
      code = element.textContent;
    }

    final bgColor =
        isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;
    final textColor =
        isDark ? const Color(0xFFF5F0EB) : const Color(0xFF2C2520);
    final borderColor =
        isDark ? const Color(0xFF3D3835) : const Color(0xFFE8DFD5);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: borderColor),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          code,
          style: TextStyle(
            fontSize: 14,
            fontFamily: 'monospace',
            height: 1.5,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LaTeX paragraph builder
// ---------------------------------------------------------------------------

/// Markdown element builder that intercepts paragraph text to render
/// LaTeX placeholders as [FlutterMath] widgets.
///
/// - Paragraphs that are entirely a block placeholder render as centered
///   block equations.
/// - Paragraphs mixing text with inline placeholders render as a rich
///   inline layout with [WidgetSpan]s.
class _LatexParagraphBuilder extends MarkdownElementBuilder {
  final List<String> latexExpressions;
  final String blockPlaceholderPrefix;
  final String inlinePlaceholderPrefix;
  final TextStyle? textStyle;

  _LatexParagraphBuilder({
    required this.latexExpressions,
    required this.blockPlaceholderPrefix,
    required this.inlinePlaceholderPrefix,
    this.textStyle,
  });

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final textContent = element.textContent;

    // Check if this paragraph is entirely a block LaTeX placeholder.
    final blockRegex = RegExp(
      RegExp.escape(blockPlaceholderPrefix) + r'(\d+)',
    );
    final trimmed = textContent.trim();
    final blockMatch = blockRegex.firstMatch(trimmed);
    if (blockMatch != null && trimmed == blockMatch.group(0)) {
      final index = int.parse(blockMatch.group(1)!);
      if (index < latexExpressions.length) {
        return _buildBlockLatex(context, latexExpressions[index]);
      }
    }

    // Check if the text contains any LaTeX placeholders.
    if (textContent.contains(blockPlaceholderPrefix) ||
        textContent.contains(inlinePlaceholderPrefix)) {
      return _buildMixedContent(context, textContent);
    }

    // No LaTeX in this paragraph -- return null to use default rendering.
    return null;
  }

  /// Renders a centered block-level LaTeX equation.
  Widget _buildBlockLatex(BuildContext context, String expression) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFF5F0EB) : const Color(0xFF2C2520);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Math.tex(
            expression.trim(),
            mathStyle: MathStyle.display,
            textStyle: TextStyle(fontSize: 18, color: textColor),
          ),
        ),
      ),
    );
  }

  /// Renders a paragraph that mixes regular text with inline LaTeX placeholders.
  Widget _buildMixedContent(BuildContext context, String text) {
    final children = <InlineSpan>[];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFF5F0EB) : const Color(0xFF2C2520);

    final placeholderPattern = RegExp(
      '(${RegExp.escape(blockPlaceholderPrefix)}\\d+|${RegExp.escape(inlinePlaceholderPrefix)}\\d+)',
    );

    final parts = text.split(placeholderPattern);
    for (final part in parts) {
      if (part.isEmpty) continue;

      final blockMatch = RegExp(
        '${RegExp.escape(blockPlaceholderPrefix)}(\\d+)',
      ).firstMatch(part);
      final inlineMatch = RegExp(
        '${RegExp.escape(inlinePlaceholderPrefix)}(\\d+)',
      ).firstMatch(part);

      if (blockMatch != null) {
        final index = int.parse(blockMatch.group(1)!);
        if (index < latexExpressions.length) {
          children.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Math.tex(
                latexExpressions[index].trim(),
                mathStyle: MathStyle.display,
                textStyle: TextStyle(fontSize: 16, color: textColor),
              ),
            ),
          );
        }
      } else if (inlineMatch != null) {
        final index = int.parse(inlineMatch.group(1)!);
        if (index < latexExpressions.length) {
          children.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Math.tex(
                latexExpressions[index].trim(),
                mathStyle: MathStyle.text,
                textStyle: TextStyle(fontSize: 16, color: textColor),
              ),
            ),
          );
        }
      } else {
        children.add(
          TextSpan(
            text: part,
            style: textStyle?.copyWith(color: textColor),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(text: TextSpan(children: children)),
    );
  }
}
