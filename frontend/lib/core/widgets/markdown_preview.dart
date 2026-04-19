import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Renders markdown content with code highlighting and optional LaTeX math.
///
/// LaTeX patterns are intercepted before markdown parsing:
/// - `$$...$$` for block-level equations
/// - `$...$` for inline equations
///
/// Code blocks are styled with a warm dark background, monospace font,
/// horizontal scrolling, and a copy button.
class MarkdownPreview extends StatelessWidget {
  /// Raw markdown text to render.
  final String content;

  /// Whether to enable LaTeX math rendering. Defaults to true.
  final bool showLaTeX;

  const MarkdownPreview({
    super.key,
    required this.content,
    this.showLaTeX = true,
  });

  /// Pre-compiled regex for block LaTeX ($$...$$).
  static final RegExp _blockLatexRegex = RegExp(
    r'\$\$([\s\S]*?)\$\$',
    multiLine: true,
  );

  /// Pre-compiled regex for inline LaTeX ($...$).
  /// Uses negative lookbehind/ahead to avoid matching currency.
  static final RegExp _inlineLatexRegex = RegExp(
    r'(?<!\$)\$(?!\$)(.*?)(?<!\$)\$(?!\$)',
    multiLine: true,
  );

  /// Unique placeholder prefix for block LaTeX.
  static const _blockPlaceholderPrefix = '\x00LATEX_BLOCK_';

  /// Unique placeholder prefix for inline LaTeX.
  static const _inlinePlaceholderPrefix = '\x00LATEX_INLINE_';

  @override
  Widget build(BuildContext context) {
    if (showLaTeX) {
      return _buildWithLatex(context);
    }
    return _buildMarkdownBody(context, content);
  }

  /// Pre-processes the markdown to replace LaTeX patterns with placeholders,
  /// then renders markdown and substitutes placeholders with math widgets.
  Widget _buildWithLatex(BuildContext context) {
    final List<String> latexExpressions = [];

    // Phase 1: Extract block LaTeX ($$...$$) and replace with placeholders.
    String processed = content;
    processed = processed.replaceAllMapped(_blockLatexRegex, (match) {
      final index = latexExpressions.length;
      latexExpressions.add(match.group(1)!);
      return '\n$_blockPlaceholderPrefix$index\n';
    });

    // Phase 2: Extract inline LaTeX ($...$) and replace with placeholders.
    processed = processed.replaceAllMapped(_inlineLatexRegex, (match) {
      final index = latexExpressions.length;
      latexExpressions.add(match.group(1)!);
      return '$_inlinePlaceholderPrefix$index';
    });

    return _buildMarkdownBody(context, processed, latexExpressions);
  }

  /// Builds the MarkdownBody widget with theme-aware styling.
  Widget _buildMarkdownBody(
    BuildContext context,
    String data, [
    List<String>? latexExpressions,
  ]) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Warm code block background colors matching the design system.
    final codeBlockBg =
        isDark ? const Color(0xFF1A1614) : const Color(0xFFF5F0EB);
    final codeBlockText =
        isDark ? const Color(0xFFF5F0EB) : const Color(0xFF2C2520);

    // Build element builders map.
    final builders = <String, MarkdownElementBuilder>{
      'pre': _CodeBlockBuilder(isDark: isDark),
    };

    // Add LaTeX paragraph builder only when expressions exist.
    if (latexExpressions != null && latexExpressions.isNotEmpty) {
      builders['p'] = _LatexParagraphBuilder(
        latexExpressions: latexExpressions,
        blockPlaceholderPrefix: _blockPlaceholderPrefix,
        inlinePlaceholderPrefix: _inlinePlaceholderPrefix,
        textStyle: theme.textTheme.bodyLarge,
      );
    }

    return MarkdownBody(
      data: data,
      selectable: true,
      builders: builders,
      styleSheet: MarkdownStyleSheet(
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
          backgroundColor:
              isDark ? const Color(0xFF2C2826) : const Color(0xFFF5F0EB),
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
              ? const Color(0xFF9B8E82)
              : const Color(0xFF6B5E54),
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF2C2826)
              : const Color(0xFFF5F0EB),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        listBullet: TextStyle(
          color: isDark
              ? const Color(0xFF9B8E82)
              : const Color(0xFF6B5E54),
        ),
        tableBody: TextStyle(
          fontSize: 14,
          color: isDark ? const Color(0xFFF5F0EB) : const Color(0xFF2C2520),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Code block builder with copy button
// ---------------------------------------------------------------------------

/// Intercept `<pre>` elements to render code blocks with a copy button,
/// horizontal scrolling, and warm theme styling.
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
    // Extract the code content from the nested <code> element.
    String code = '';
    String? language;
    if (element.children != null && element.children!.isNotEmpty) {
      final codeElement = element.children!.first;
      if (codeElement is md.Element && codeElement.tag == 'code') {
        code = codeElement.textContent;
        // Extract language from class attribute (e.g. class="language-dart").
        final className = codeElement.attributes['class'];
        if (className != null && className.startsWith('language-')) {
          language = className.substring(9);
        }
      } else {
        code = element.textContent;
      }
    } else {
      code = element.textContent;
    }

    final bgColor =
        isDark ? const Color(0xFF1A1614) : const Color(0xFFF5F0EB);
    final textColor =
        isDark ? const Color(0xFFF5F0EB) : const Color(0xFF2C2520);
    final borderColor =
        isDark ? const Color(0xFF3D3835) : const Color(0xFFE8DFD5);
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bar with language label and copy button.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: borderColor),
              ),
            ),
            child: Row(
              children: [
                if (language != null)
                  Text(
                    language,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: isDark
                          ? const Color(0xFF9B8E82)
                          : const Color(0xFF6B5E54),
                    ),
                  ),
                const Spacer(),
                _CopyButton(
                  text: code,
                  tooltip: l10n?.copy ?? 'Copy',
                ),
              ],
            ),
          ),
          // Code content with horizontal scroll.
          SingleChildScrollView(
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
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LaTeX paragraph builder
// ---------------------------------------------------------------------------

/// Markdown element builder that intercepts paragraph text to render
/// LaTeX placeholders as FlutterMath widgets.
///
/// When a paragraph contains only a block LaTeX placeholder, it renders
/// as a centered block equation. When inline placeholders are mixed with
/// regular text, it renders a rich inline layout.
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

    // Pattern matching both block and inline placeholders.
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

// ---------------------------------------------------------------------------
// Copy button widget
// ---------------------------------------------------------------------------

/// A small icon button that copies text to the clipboard and shows feedback.
class _CopyButton extends StatefulWidget {
  final String text;
  final String tooltip;

  const _CopyButton({
    required this.text,
    required this.tooltip,
  });

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor =
        isDark ? const Color(0xFF9B8E82) : const Color(0xFF6B5E54);

    return IconButton(
      icon: Icon(
        _copied ? Icons.check : Icons.copy,
        size: 16,
        color: _copied
            ? Theme.of(context).colorScheme.primary
            : iconColor,
      ),
      tooltip: widget.tooltip,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
      onPressed: () {
        Clipboard.setData(ClipboardData(text: widget.text));
        setState(() => _copied = true);
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(l10n?.copiedToClipboard ?? 'Copied to clipboard'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _copied = false);
        });
      },
    );
  }
}
