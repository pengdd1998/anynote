import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// A rich text editor widget using flutter_quill.
///
/// Wraps a [quill.QuillSimpleToolbar] above a [quill.QuillEditor] with a
/// divider between them. The toolbar is configured for note-taking with
/// heading styles, lists, quotes, code blocks, inline formatting, undo/redo,
/// and link support. Font family, font size, color, alignment, subscript, and
/// superscript buttons are hidden to keep the toolbar compact.
///
/// Toolbar buttons use the warm theme colors from the enclosing [ThemeData].
/// Active/toggled buttons display with the primary accent, inactive buttons
/// use the theme's secondary text color. Subtle dividers separate button
/// groups for a polished, non-cluttered look.
class RichNoteEditor extends StatefulWidget {
  final quill.QuillController controller;
  final FocusNode focusNode;

  /// Optional scroll controller for the editor area.
  /// When provided, the editor uses this controller instead of creating one
  /// internally. This enables typewriter-scrolling behavior driven by the
  /// parent widget.
  final ScrollController? scrollController;

  const RichNoteEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    this.scrollController,
  });

  @override
  State<RichNoteEditor> createState() => _RichNoteEditorState();
}

class _RichNoteEditorState extends State<RichNoteEditor> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Warm icon theme: active buttons use primary accent, inactive use a
    // subdued warm grey. This avoids the default blue/gray from Material.
    final iconTheme = quill.QuillIconTheme(
      iconButtonSelectedData: quill.IconButtonData(
        color: colorScheme.primary,
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(
            colorScheme.primaryContainer.withValues(alpha: 0.3),
          ),
        ),
      ),
      iconButtonUnselectedData: quill.IconButtonData(
        color: isDark
            ? const Color(0xFF9B8E82) // warm medium grey (dark theme)
            : const Color(0xFF6B5E54), // warm brown-grey (light theme)
      ),
    );

    return Column(
      children: [
        // Toolbar with warm background and styled dividers.
        quill.QuillSimpleToolbar(
          controller: widget.controller,
          config: quill.QuillSimpleToolbarConfig(
            multiRowsDisplay: true,
            showDividers: true,
            showFontFamily: false,
            showFontSize: false,
            showBoldButton: true,
            showItalicButton: true,
            showUnderLineButton: true,
            showStrikeThrough: true,
            showInlineCode: true,
            showColorButton: false,
            showBackgroundColorButton: false,
            showClearFormat: true,
            showAlignmentButtons: false,
            showHeaderStyle: true,
            showListNumbers: true,
            showListBullets: true,
            showListCheck: true,
            showCodeBlock: true,
            showQuote: true,
            showIndent: false,
            showLink: true,
            showSearchButton: false,
            showUndo: true,
            showRedo: true,
            showDirection: false,
            showSubscript: false,
            showSuperscript: false,
            showSmallButton: false,

            // Warm toolbar background.
            color: isDark
                ? const Color(0xFF252220) // dark card background
                : const Color(0xFFFFFDFB), // warm white

            // Subtle warm dividers between button groups.
            sectionDividerColor: isDark
                ? const Color(0xFF332E2B) // warm dark divider
                : const Color(0xFFF0E8DF), // warm light divider
            sectionDividerSpace: 8,

            // Apply warm icon theme to all buttons.
            iconTheme: iconTheme,
            buttonOptions: quill.QuillSimpleToolbarButtonOptions(
              base: quill.QuillToolbarBaseButtonOptions(
                iconTheme: iconTheme,
              ),
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: isDark
              ? const Color(0xFF332E2B)
              : const Color(0xFFF0E8DF),
        ),
        // Editor
        Expanded(
          child: quill.QuillEditor.basic(
            controller: widget.controller,
            focusNode: widget.focusNode,
            scrollController:
                widget.scrollController ?? ScrollController(),
            config: const quill.QuillEditorConfig(
              padding: EdgeInsets.all(16),
              autoFocus: false,
              expands: false,
            ),
          ),
        ),
      ],
    );
  }
}
