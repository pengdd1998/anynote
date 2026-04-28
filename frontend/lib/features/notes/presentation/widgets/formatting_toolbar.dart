import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../../l10n/app_localizations.dart';

/// Tooltip strings for formatting toolbar buttons.
/// These are universal editor terms that don't need localization.
/// ignore: unused_element
final class _Tooltips {
  static const String bold = 'Bold';
  static const String italic = 'Italic';
  static const String underline = 'Underline';
  static const String strikethrough = 'Strikethrough';
  static const String bulletList = 'Bullet list';
  static const String numberedList = 'Numbered list';
  static const String quote = 'Block quote';
  static const String insertLink = 'Insert link';
}

/// A horizontal formatting toolbar for the rich text editor.
///
/// Displays grouped formatting buttons: Bold, Italic, Underline, Strikethrough
/// | H1/H2/H3 | UL/OL/Quote | Code block/Checklist | Link/Image | AI button
/// | Undo/Redo | Indent/Outdent.
/// Only shown when the editor is in rich text mode (not plain text).
class FormattingToolbar extends StatelessWidget {
  /// The QuillController used to inspect and modify formatting state.
  final quill.QuillController quillController;

  /// Callback to insert a link at the current selection.
  final VoidCallback? onInsertLink;

  /// Callback to pick an image.
  final VoidCallback? onPickImage;

  /// Callback to trigger AI features popup.
  final VoidCallback? onAiAction;

  const FormattingToolbar({
    super.key,
    required this.quillController,
    this.onInsertLink,
    this.onPickImage,
    this.onAiAction,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final style = quillController.getSelectionStyle();
    final attrs = style.attributes;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          // --- Text style group ---
          _FormatButton(
            icon: Icons.format_bold,
            tooltip: _Tooltips.bold,
            isActive: attrs.containsKey(quill.Attribute.bold.key),
            onPressed: () => _toggleAttribute(quill.Attribute.bold),
          ),
          _FormatButton(
            icon: Icons.format_italic,
            tooltip: _Tooltips.italic,
            isActive: attrs.containsKey(quill.Attribute.italic.key),
            onPressed: () => _toggleAttribute(quill.Attribute.italic),
          ),
          _FormatButton(
            icon: Icons.format_underline,
            tooltip: _Tooltips.underline,
            isActive: attrs.containsKey(quill.Attribute.underline.key),
            onPressed: () => _toggleAttribute(quill.Attribute.underline),
          ),
          _FormatButton(
            icon: Icons.format_strikethrough,
            tooltip: _Tooltips.strikethrough,
            isActive: attrs.containsKey(quill.Attribute.strikeThrough.key),
            onPressed: () => _toggleAttribute(quill.Attribute.strikeThrough),
          ),

          _groupDivider(colorScheme),

          // --- Heading group ---
          _FormatButton(
            icon: Icons.title,
            tooltip: 'H1',
            isActive: attrs[quill.Attribute.header.key]?.value == 1,
            onPressed: () => _toggleHeading(1),
          ),
          _FormatButton(
            icon: Icons.title,
            tooltip: 'H2',
            iconSize: 18,
            isActive: attrs[quill.Attribute.header.key]?.value == 2,
            onPressed: () => _toggleHeading(2),
          ),
          _FormatButton(
            icon: Icons.title,
            tooltip: 'H3',
            iconSize: 16,
            isActive: attrs[quill.Attribute.header.key]?.value == 3,
            onPressed: () => _toggleHeading(3),
          ),

          _groupDivider(colorScheme),

          // --- List group ---
          _FormatButton(
            icon: Icons.format_list_bulleted,
            tooltip: _Tooltips.bulletList,
            isActive: attrs.containsKey(quill.Attribute.list.key) &&
                attrs[quill.Attribute.list.key]?.value ==
                    quill.Attribute.ul.value,
            onPressed: () => _toggleList(quill.Attribute.ul),
          ),
          _FormatButton(
            icon: Icons.format_list_numbered,
            tooltip: _Tooltips.numberedList,
            isActive: attrs.containsKey(quill.Attribute.list.key) &&
                attrs[quill.Attribute.list.key]?.value ==
                    quill.Attribute.ol.value,
            onPressed: () => _toggleList(quill.Attribute.ol),
          ),
          _FormatButton(
            icon: Icons.format_quote,
            tooltip: _Tooltips.quote,
            isActive: attrs.containsKey(quill.Attribute.blockQuote.key),
            onPressed: () => _toggleAttribute(quill.Attribute.blockQuote),
          ),

          // --- Code block / Checklist ---
          _FormatButton(
            icon: Icons.code,
            tooltip: l10n.codeBlock,
            isActive: attrs.containsKey(quill.Attribute.codeBlock.key),
            onPressed: () => _toggleAttribute(quill.Attribute.codeBlock),
          ),
          _FormatButton(
            icon: Icons.checklist,
            tooltip: l10n.checklist,
            isActive: attrs.containsKey(quill.Attribute.list.key) &&
                attrs[quill.Attribute.list.key]?.value ==
                    quill.Attribute.checked.value,
            onPressed: () => _toggleChecklist(),
          ),

          _groupDivider(colorScheme),

          // --- Indent / Outdent ---
          _FormatButton(
            icon: Icons.format_indent_increase,
            tooltip: l10n.indent,
            isActive: false,
            onPressed: () => _indent(),
          ),
          _FormatButton(
            icon: Icons.format_indent_decrease,
            tooltip: l10n.outdent,
            isActive: false,
            onPressed: () => _outdent(),
          ),

          _groupDivider(colorScheme),

          // --- Insert group ---
          if (onInsertLink != null)
            _FormatButton(
              icon: Icons.link,
              tooltip: _Tooltips.insertLink,
              isActive: false,
              onPressed: onInsertLink!,
            ),
          if (onPickImage != null)
            _FormatButton(
              icon: Icons.image_outlined,
              tooltip: l10n.addImage,
              isActive: false,
              onPressed: onPickImage!,
            ),

          // --- AI group ---
          if (onAiAction != null) ...[
            _groupDivider(colorScheme),
            _FormatButton(
              icon: Icons.auto_awesome_outlined,
              tooltip: l10n.aiFeatures,
              isActive: false,
              onPressed: onAiAction!,
            ),
          ],

          _groupDivider(colorScheme),

          // --- Undo / Redo ---
          _FormatButton(
            icon: Icons.undo,
            tooltip: l10n.undo,
            isActive: false,
            onPressed: () => quillController.undo(),
          ),
          _FormatButton(
            icon: Icons.redo,
            tooltip: l10n.menuRedo,
            isActive: false,
            onPressed: () => quillController.redo(),
          ),
        ],
      ),
    );
  }

  Widget _groupDivider(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: VerticalDivider(
        width: 1,
        indent: 10,
        endIndent: 10,
        color: colorScheme.outlineVariant.withOpacity(0.5),
      ),
    );
  }

  void _toggleAttribute(quill.Attribute attribute) {
    quillController.formatSelection(attribute);
  }

  void _toggleHeading(int level) {
    final currentStyle = quillController.getSelectionStyle();
    final existing = currentStyle.attributes[quill.Attribute.header.key];
    if (existing != null && existing.value == level) {
      quillController.formatSelection(quill.Attribute.header);
    } else {
      final attr = switch (level) {
        1 => quill.Attribute.h1,
        2 => quill.Attribute.h2,
        3 => quill.Attribute.h3,
        _ => quill.Attribute.h1,
      };
      quillController.formatSelection(attr);
    }
  }

  void _toggleList(quill.Attribute listAttr) {
    final currentStyle = quillController.getSelectionStyle();
    final isActive =
        currentStyle.attributes.containsKey(quill.Attribute.list.key) &&
            currentStyle.attributes[quill.Attribute.list.key]?.value ==
                listAttr.value;
    if (isActive) {
      quillController.formatSelection(quill.Attribute.list);
    } else {
      quillController.formatSelection(listAttr);
    }
  }

  /// Toggle checklist format on the current selection.
  void _toggleChecklist() {
    final currentStyle = quillController.getSelectionStyle();
    final isChecklist =
        currentStyle.attributes.containsKey(quill.Attribute.list.key) &&
            currentStyle.attributes[quill.Attribute.list.key]?.value ==
                quill.Attribute.checked.value;
    if (isChecklist) {
      quillController.formatSelection(quill.Attribute.list);
    } else {
      quillController.formatSelection(quill.Attribute.checked);
    }
  }

  /// Increase indent level of the current paragraph.
  void _indent() {
    quillController.formatSelection(quill.Attribute.indent);
  }

  /// Decrease indent level of the current paragraph.
  void _outdent() {
    final currentStyle = quillController.getSelectionStyle();
    final indentValue = currentStyle.attributes[quill.Attribute.indent.key];
    if (indentValue != null && indentValue.value is int) {
      final current = indentValue.value as int;
      if (current <= 1) {
        // Remove indent attribute when outdenting from level 1.
        quillController.formatSelection(quill.Attribute.indent);
      } else {
        quillController.formatSelection(
          quill.Attribute<int>(
            'indent',
            quill.AttributeScope.block,
            current - 1,
          ),
        );
      }
    }
  }
}

/// A single formatting button that highlights when active.
class _FormatButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onPressed;
  final double iconSize;

  const _FormatButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onPressed,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      icon: Icon(icon, size: iconSize),
      tooltip: tooltip,
      iconSize: iconSize,
      color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
      style: IconButton.styleFrom(
        backgroundColor: isActive
            ? colorScheme.primaryContainer.withOpacity(0.3)
            : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
    );
  }
}
