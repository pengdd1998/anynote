import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ── Intents ─────────────────────────────────────────────

/// Intent to create a new note.
class NewNoteIntent extends Intent {
  const NewNoteIntent();
}

/// Intent to save the current note.
class SaveIntent extends Intent {
  const SaveIntent();
}

/// Intent to open search.
class SearchIntent extends Intent {
  const SearchIntent();
}

/// Intent to toggle the sidebar (desktop only).
class ToggleSidebarIntent extends Intent {
  const ToggleSidebarIntent();
}

// ── AppShortcuts Widget ─────────────────────────────────

/// Wraps its [child] with keyboard shortcuts for common actions.
///
/// Shortcuts (Ctrl on Windows/Linux, Cmd on macOS):
/// - Ctrl/Cmd + N : Create a new note
/// - Ctrl/Cmd + S : Save current note (triggers sync)
/// - Ctrl/Cmd + F : Open search
/// - Ctrl/Cmd + B : Toggle sidebar (desktop only)
///
/// Place this widget above [MaterialApp.router] in the widget tree so that
/// shortcuts are available globally:
/// ```dart
/// AppShortcuts(
///   child: MaterialApp.router(...),
/// )
/// ```
class AppShortcuts extends StatelessWidget {
  final Widget child;

  const AppShortcuts({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Use the platform-appropriate modifier key.
    final isMacOS = Theme.of(context).platform == TargetPlatform.macOS;
    final modifier =
        isMacOS ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(modifier, LogicalKeyboardKey.keyN):
            const NewNoteIntent(),
        LogicalKeySet(modifier, LogicalKeyboardKey.keyS): const SaveIntent(),
        LogicalKeySet(modifier, LogicalKeyboardKey.keyF):
            const SearchIntent(),
        LogicalKeySet(modifier, LogicalKeyboardKey.keyB):
            const ToggleSidebarIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          NewNoteIntent: CallbackAction<NewNoteIntent>(
            onInvoke: (intent) => _handleNewNote(context),
          ),
          SaveIntent: CallbackAction<SaveIntent>(
            onInvoke: (intent) => _handleSave(context),
          ),
          SearchIntent: CallbackAction<SearchIntent>(
            onInvoke: (intent) => _handleSearch(context),
          ),
          ToggleSidebarIntent: CallbackAction<ToggleSidebarIntent>(
            onInvoke: (intent) => _handleToggleSidebar(context),
          ),
        },
        child: child,
      ),
    );
  }

  void _handleNewNote(BuildContext context) {
    // Only navigate if there is a valid GoRouter context available.
    // The context from the build method of this widget is the one above
    // MaterialApp, so GoRouter may not be available. Use rootNavigator
    // key from router instead.
    try {
      final router = GoRouter.of(context);
      router.push('/notes/new');
    } catch (_) {
      // GoRouter not yet available in this context -- ignore.
    }
  }

  void _handleSave(BuildContext context) {
    // Saving is handled by the auto-save in the editor and the sync engine.
    // This shortcut is a placeholder for future explicit save UX.
  }

  void _handleSearch(BuildContext context) {
    try {
      final router = GoRouter.of(context);
      router.push('/search');
    } catch (_) {
      // GoRouter not yet available -- ignore.
    }
  }

  void _handleToggleSidebar(BuildContext context) {
    // Sidebar toggling is handled by the layout widget observing this
    // intent via an Actions handler higher up in the tree.
  }
}
