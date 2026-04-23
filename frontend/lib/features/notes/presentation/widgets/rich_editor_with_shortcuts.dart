import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../rich_note_editor.dart';

/// Rich text editor wrapped with additional keyboard shortcuts.
///
/// flutter_quill handles Ctrl+B/I natively. This widget adds:
/// - Ctrl+1: Heading level 1
/// - Ctrl+2: Heading level 2
/// - Ctrl+3: Heading level 3
/// - Ctrl+Shift+L: Toggle bullet list
/// - Escape: Exit zen mode
///
/// Extracted from `NoteEditorScreen._buildRichEditorWithShortcuts`.
class RichEditorWithShortcuts extends StatelessWidget {
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

  const RichEditorWithShortcuts({
    super.key,
    required this.quillController,
    required this.focusNode,
    required this.onExitZenMode,
    required this.onToggleHeading,
    required this.onToggleBulletList,
  });

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
        // Escape to exit zen mode
        LogicalKeySet(LogicalKeyboardKey.escape): const _ExitZenIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _Heading1Intent: CallbackAction<_Heading1Intent>(
            onInvoke: (_) => onToggleHeading(1),
          ),
          _Heading2Intent: CallbackAction<_Heading2Intent>(
            onInvoke: (_) => onToggleHeading(2),
          ),
          _Heading3Intent: CallbackAction<_Heading3Intent>(
            onInvoke: (_) => onToggleHeading(3),
          ),
          _BulletListIntent: CallbackAction<_BulletListIntent>(
            onInvoke: (_) => onToggleBulletList(),
          ),
          _ExitZenIntent: CallbackAction<_ExitZenIntent>(
            onInvoke: (_) => onExitZenMode(),
          ),
        },
        child: RichNoteEditor(
          controller: quillController,
          focusNode: focusNode,
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

/// Intent to exit zen / focus mode via keyboard.
class _ExitZenIntent extends Intent {
  const _ExitZenIntent();
}
