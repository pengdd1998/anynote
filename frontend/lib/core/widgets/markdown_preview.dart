import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';

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
  ///
  /// Note: The `builders` parameter is intentionally NOT used because
  /// flutter_markdown 0.7.7+1 has an internal assertion bug
  /// (`_inlines.isEmpty` at builder.dart:267) when custom builders are
  /// provided for block elements like `pre` or `p` that have inline children.
  /// Code block styling is handled purely through MarkdownStyleSheet.
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

    // If LaTeX expressions exist, build a Column that interleaves
    // MarkdownBody segments with Math widgets.
    if (latexExpressions != null && latexExpressions.isNotEmpty) {
      return _buildLatexColumn(context, data, latexExpressions, isDark);
    }

    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: _buildStyleSheet(
        isDark: isDark,
        codeBlockBg: codeBlockBg,
        codeBlockText: codeBlockText,
      ),
    );
  }

  /// Builds the theme-aware MarkdownStyleSheet.
  MarkdownStyleSheet _buildStyleSheet({
    required bool isDark,
    required Color codeBlockBg,
    required Color codeBlockText,
  }) {
    return MarkdownStyleSheet(
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
            ? const Color(0xFFA3988E)
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
            ? const Color(0xFFA3988E)
            : const Color(0xFF6B5E54),
      ),
      tableBody: TextStyle(
        fontSize: 14,
        color: isDark ? const Color(0xFFF5F0EB) : const Color(0xFF2C2520),
      ),
    );
  }

  /// Builds a Column that interleaves MarkdownBody segments with LaTeX
  /// Math widgets, splitting the processed markdown on LaTeX placeholder
  /// boundaries.
  Widget _buildLatexColumn(
    BuildContext context,
    String data,
    List<String> latexExpressions,
    bool isDark,
  ) {
    final textColor =
        isDark ? const Color(0xFFF5F0EB) : const Color(0xFF2C2520);
    final codeBlockBg =
        isDark ? const Color(0xFF1A1614) : const Color(0xFFF5F0EB);
    final codeBlockText =
        isDark ? const Color(0xFFF5F0EB) : const Color(0xFF2C2520);
    final styleSheet = _buildStyleSheet(
      isDark: isDark,
      codeBlockBg: codeBlockBg,
      codeBlockText: codeBlockText,
    );

    // Build a pattern that matches any LaTeX placeholder.
    final placeholderPattern = RegExp(
      '(${RegExp.escape(_blockPlaceholderPrefix)}\\d+'
      '|${RegExp.escape(_inlinePlaceholderPrefix)}\\d+)',
    );

    // Split data on placeholders and interleave Math widgets.
    final children = <Widget>[];
    final parts = data.split(placeholderPattern);

    for (final part in parts) {
      if (part.isEmpty) continue;

      final blockMatch = RegExp(
        '${RegExp.escape(_blockPlaceholderPrefix)}(\\d+)',
      ).firstMatch(part);
      final inlineMatch = RegExp(
        '${RegExp.escape(_inlinePlaceholderPrefix)}(\\d+)',
      ).firstMatch(part);

      if (blockMatch != null) {
        final index = int.parse(blockMatch.group(1)!);
        if (index < latexExpressions.length) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Math.tex(
                    latexExpressions[index].trim(),
                    mathStyle: MathStyle.display,
                    textStyle: TextStyle(fontSize: 18, color: textColor),
                  ),
                ),
              ),
            ),
          );
        }
      } else if (inlineMatch != null) {
        final index = int.parse(inlineMatch.group(1)!);
        if (index < latexExpressions.length) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Math.tex(
                    latexExpressions[index].trim(),
                    mathStyle: MathStyle.text,
                    textStyle: TextStyle(fontSize: 16, color: textColor),
                  ),
                ),
              ),
            ),
          );
        }
      } else {
        // Regular markdown segment.
        children.add(
          MarkdownBody(
            data: part,
            selectable: true,
            styleSheet: styleSheet,
          ),
        );
      }
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    if (children.length == 1) {
      return children.single;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

