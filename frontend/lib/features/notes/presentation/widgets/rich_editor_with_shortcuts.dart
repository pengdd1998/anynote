import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../../core/widgets/keyboard_shortcuts.dart';
import '../rich_note_editor.dart';
import 'slash_command_menu.dart';

/// Rich text editor wrapped with additional keyboard shortcuts.
///
/// flutter_quill handles Ctrl+B/I natively. This widget adds:
/// - Ctrl+1: Heading level 1
/// - Ctrl+2: Heading level 2
/// - Ctrl+3: Heading level 3
/// - Ctrl+Shift+L: Toggle bullet list
/// - Ctrl+Z: Undo
/// - Ctrl+Y / Ctrl+Shift+Z: Redo
/// - Ctrl+Shift+S: Toggle strikethrough
/// - Ctrl+`: Toggle inline code
/// - Ctrl+H: Cycle heading level (h1 -> h2 -> h3 -> paragraph)
/// - Ctrl+Shift+K: Insert link
/// - Escape: Exit zen mode
///
/// Also forwards [onSlashCommand] to the [RichNoteEditor] so slash command
/// selections that require parent context (image picker, etc.) are handled.
class RichEditorWithShortcuts extends StatefulWidget {
  /// The quill controller for the rich editor.
  final quill.QuillController quillController;

  /// Focus node for the editor.
  final FocusNode focusNode;

  /// Called when the user triggers the exit-zen-mode shortcut (Escape).
  final VoidCallback onExitZenMode;

  /// Called when heading 1 is toggled.
  final void Function(int level) onToggleHeading;

  /// Called when bullet list is toggled.
  final VoidCallback onToggleBulletList;

  /// Called when a slash command requires parent-level handling (e.g. image
  /// picker, wiki link picker).
  final void Function(SlashCommandType type)? onSlashCommand;

  /// When true, the editor is read-only and the toolbar is hidden.
  final bool readOnly;

  const RichEditorWithShortcuts({
    super.key,
    required this.quillController,
    required this.focusNode,
    required this.onExitZenMode,
    required this.onToggleHeading,
    required this.onToggleBulletList,
    this.onSlashCommand,
    this.readOnly = false,
  });

  @override
  State<RichEditorWithShortcuts> createState() =>
      _RichEditorWithShortcutsState();
}

class _RichEditorWithShortcutsState extends State<RichEditorWithShortcuts> {
  @override
  void initState() {
    super.initState();
    _registerGlobalCallbacks();
  }

  @override
  void dispose() {
    _clearGlobalCallbacks();
    super.dispose();
  }

  /// Register this editor's shortcuts with the global keyboard shortcuts
  /// system so that Ctrl+P, Ctrl+Shift+K, etc. are forwarded here when
  /// the editor is active.
  void _registerGlobalCallbacks() {
    AppKeyboardShortcuts.setStrikethroughCallback(_toggleStrikethrough);
    AppKeyboardShortcuts.setInlineCodeCallback(_toggleInlineCode);
    AppKeyboardShortcuts.setHeadingCycleCallback(_cycleHeading);
    AppKeyboardShortcuts.setInsertLinkCallback(_insertLink);
  }

  /// Clear all global callbacks registered by this editor.
  void _clearGlobalCallbacks() {
    AppKeyboardShortcuts.clearStrikethroughCallback();
    AppKeyboardShortcuts.clearInlineCodeCallback();
    AppKeyboardShortcuts.clearHeadingCycleCallback();
    AppKeyboardShortcuts.clearInsertLinkCallback();
  }

  /// Toggle strikethrough on the current selection.
  void _toggleStrikethrough() {
    final style = widget.quillController.getSelectionStyle();
    final hasStrike =
        style.attributes.containsKey(quill.Attribute.strikeThrough.key);
    if (hasStrike) {
      // Remove strikethrough by formatting with the unset attribute.
      widget.quillController.formatSelection(
        quill.Attribute.strikeThrough,
      );
    } else {
      widget.quillController.formatSelection(
        quill.Attribute.strikeThrough,
      );
    }
  }

  /// Toggle inline code on the current selection.
  void _toggleInlineCode() {
    final style = widget.quillController.getSelectionStyle();
    final hasCode =
        style.attributes.containsKey(quill.Attribute.inlineCode.key);
    if (hasCode) {
      widget.quillController.formatSelection(
        quill.Attribute.inlineCode,
      );
    } else {
      widget.quillController.formatSelection(
        quill.Attribute.inlineCode,
      );
    }
  }

  /// Cycle heading level: paragraph -> h1 -> h2 -> h3 -> paragraph.
  void _cycleHeading() {
    final style = widget.quillController.getSelectionStyle();
    final headerAttr = style.attributes[quill.Attribute.header.key];
    if (headerAttr != null) {
      final level = headerAttr.value;
      if (level == 1) {
        widget.onToggleHeading(2);
      } else if (level == 2) {
        widget.onToggleHeading(3);
      } else {
        // h3 or any other level -> reset to paragraph.
        widget.onToggleHeading(0);
      }
    } else {
      widget.onToggleHeading(1);
    }
  }

  /// Open the link insertion dialog or toggle link on the current selection.
  void _insertLink() {
    // Trigger the toolbar's link button by programmatically invoking the
    // link format dialog. We use the same approach as quill toolbar.
    final controller = widget.quillController;
    final selection = controller.selection;
    if (selection.isCollapsed) {
      // No selection: select the current word.
      final text = controller.document.toPlainText();
      int start = selection.baseOffset;
      int end = selection.baseOffset;
      while (start > 0 && text[start - 1] != ' ' && text[start - 1] != '\n') {
        start--;
      }
      while (end < text.length && text[end] != ' ' && text[end] != '\n') {
        end++;
      }
      if (start != end) {
        controller.updateSelection(
          TextSelection(baseOffset: start, extentOffset: end),
          quill.ChangeSource.local,
        );
      }
    }
    // Toggle link attribute -- this triggers the quill toolbar's link dialog
    // flow if using QuillToolbarLinkButton, but since we handle it here we
    // just format with a placeholder that the user can edit.
    controller.formatSelection(const quill.LinkAttribute(''));
  }

  @override
  Widget build(BuildContext context) {
    final isMacOS = Theme.of(context).platform == TargetPlatform.macOS;
    final primaryModifier =
        isMacOS ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        // Heading shortcuts
        LogicalKeySet(primaryModifier, LogicalKeyboardKey.digit1):
            const _Heading1Intent(),
        LogicalKeySet(primaryModifier, LogicalKeyboardKey.digit2):
            const _Heading2Intent(),
        LogicalKeySet(primaryModifier, LogicalKeyboardKey.digit3):
            const _Heading3Intent(),
        // Bullet list shortcut
        LogicalKeySet(
          primaryModifier,
          LogicalKeyboardKey.shift,
          LogicalKeyboardKey.keyL,
        ): const _BulletListIntent(),
        // Undo: Ctrl+Z
        LogicalKeySet(primaryModifier, LogicalKeyboardKey.keyZ):
            const _UndoIntent(),
        // Redo: Ctrl+Y
        LogicalKeySet(primaryModifier, LogicalKeyboardKey.keyY):
            const _RedoIntent(),
        // Redo: Ctrl+Shift+Z
        LogicalKeySet(
          primaryModifier,
          LogicalKeyboardKey.shift,
          LogicalKeyboardKey.keyZ,
        ): const _RedoIntent(),
        // Strikethrough: Ctrl+Shift+S
        LogicalKeySet(
          primaryModifier,
          LogicalKeyboardKey.shift,
          LogicalKeyboardKey.keyS,
        ): const _StrikethroughIntent(),
        // Inline code: Ctrl+`
        LogicalKeySet(primaryModifier, LogicalKeyboardKey.backquote):
            const _InlineCodeIntent(),
        // Heading cycle: Ctrl+H
        LogicalKeySet(primaryModifier, LogicalKeyboardKey.keyH):
            const _HeadingCycleIntent(),
        // Insert link: Ctrl+Shift+K
        LogicalKeySet(
          primaryModifier,
          LogicalKeyboardKey.shift,
          LogicalKeyboardKey.keyK,
        ): const _InsertLinkIntent(),
        // Escape to exit zen mode
        LogicalKeySet(LogicalKeyboardKey.escape): const _ExitZenIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _Heading1Intent: CallbackAction<_Heading1Intent>(
            onInvoke: (_) => widget.onToggleHeading(1),
          ),
          _Heading2Intent: CallbackAction<_Heading2Intent>(
            onInvoke: (_) => widget.onToggleHeading(2),
          ),
          _Heading3Intent: CallbackAction<_Heading3Intent>(
            onInvoke: (_) => widget.onToggleHeading(3),
          ),
          _BulletListIntent: CallbackAction<_BulletListIntent>(
            onInvoke: (_) => widget.onToggleBulletList(),
          ),
          _UndoIntent: CallbackAction<_UndoIntent>(
            onInvoke: (_) {
              if (widget.quillController.hasUndo) {
                widget.quillController.undo();
              }
              return null;
            },
          ),
          _RedoIntent: CallbackAction<_RedoIntent>(
            onInvoke: (_) {
              if (widget.quillController.hasRedo) {
                widget.quillController.redo();
              }
              return null;
            },
          ),
          _StrikethroughIntent: CallbackAction<_StrikethroughIntent>(
            onInvoke: (_) => _toggleStrikethrough(),
          ),
          _InlineCodeIntent: CallbackAction<_InlineCodeIntent>(
            onInvoke: (_) => _toggleInlineCode(),
          ),
          _HeadingCycleIntent: CallbackAction<_HeadingCycleIntent>(
            onInvoke: (_) => _cycleHeading(),
          ),
          _InsertLinkIntent: CallbackAction<_InsertLinkIntent>(
            onInvoke: (_) => _insertLink(),
          ),
          _ExitZenIntent: CallbackAction<_ExitZenIntent>(
            onInvoke: (_) => widget.onExitZenMode(),
          ),
        },
        child: RichNoteEditor(
          controller: widget.quillController,
          focusNode: widget.focusNode,
          onSlashCommand: widget.onSlashCommand,
          readOnly: widget.readOnly,
        ),
      ),
    );
  }
}

// -- Keyboard Shortcut Intents ------------------------------------------------

class _Heading1Intent extends Intent {
  const _Heading1Intent();
}

class _Heading2Intent extends Intent {
  const _Heading2Intent();
}

class _Heading3Intent extends Intent {
  const _Heading3Intent();
}

class _BulletListIntent extends Intent {
  const _BulletListIntent();
}

/// Intent to trigger undo.
class _UndoIntent extends Intent {
  const _UndoIntent();
}

/// Intent to trigger redo.
class _RedoIntent extends Intent {
  const _RedoIntent();
}

/// Intent to toggle strikethrough formatting.
class _StrikethroughIntent extends Intent {
  const _StrikethroughIntent();
}

/// Intent to toggle inline code formatting.
class _InlineCodeIntent extends Intent {
  const _InlineCodeIntent();
}

/// Intent to cycle heading level (h1 -> h2 -> h3 -> paragraph).
class _HeadingCycleIntent extends Intent {
  const _HeadingCycleIntent();
}

/// Intent to insert a link.
class _InsertLinkIntent extends Intent {
  const _InsertLinkIntent();
}

/// Intent to exit zen / focus mode via keyboard.
class _ExitZenIntent extends Intent {
  const _ExitZenIntent();
}
