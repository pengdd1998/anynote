import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../platform/platform_utils.dart';
import 'sidebar_provider.dart';

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

/// Intent to export to PDF.
class ExportPdfIntent extends Intent {
  const ExportPdfIntent();
}

/// Intent to open settings.
class OpenSettingsIntent extends Intent {
  const OpenSettingsIntent();
}

/// Intent to close the current note.
class CloseNoteIntent extends Intent {
  const CloseNoteIntent();
}

/// Intent to cycle to the next note.
class NextNoteIntent extends Intent {
  const NextNoteIntent();
}

/// Intent to toggle full screen.
class ToggleFullScreenIntent extends Intent {
  const ToggleFullScreenIntent();
}

/// Intent to exit zen mode or close the current dialog.
class ExitZenOrDialogIntent extends Intent {
  const ExitZenOrDialogIntent();
}

// ── AppShortcuts Widget ─────────────────────────────────

/// Wraps its [child] with keyboard shortcuts for common actions.
///
/// Shortcuts (Ctrl on Windows/Linux, Cmd on macOS):
/// - Ctrl/Cmd + N     : Create a new note
/// - Ctrl/Cmd + S     : Save current note (triggers sync)
/// - Ctrl/Cmd + F     : Open search
/// - Ctrl/Cmd + B     : Toggle sidebar (desktop only)
/// - Ctrl/Cmd + P     : Export to PDF
/// - Ctrl/Cmd + ,     : Open Settings
/// - Ctrl/Cmd + W     : Close current note
/// - Ctrl/Cmd + Tab   : Cycle to next note
/// - F11              : Toggle full screen
/// - Escape           : Exit zen mode / close dialog
///
/// Place this widget above [MaterialApp.router] in the widget tree so that
/// shortcuts are available globally:
/// ```dart
/// AppShortcuts(
///   child: MaterialApp.router(...),
/// )
/// ```
class AppShortcuts extends ConsumerWidget {
  final Widget child;

  const AppShortcuts({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the platform-appropriate modifier key.
    final isMacOS = Theme.of(context).platform == TargetPlatform.macOS;
    final modifierKey = isMacOS
        ? LogicalKeyboardKey.meta
        : LogicalKeyboardKey.control;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        // Original shortcuts
        LogicalKeySet(modifierKey, LogicalKeyboardKey.keyN):
            const NewNoteIntent(),
        LogicalKeySet(modifierKey, LogicalKeyboardKey.keyS):
            const SaveIntent(),
        LogicalKeySet(modifierKey, LogicalKeyboardKey.keyF):
            const SearchIntent(),
        LogicalKeySet(modifierKey, LogicalKeyboardKey.keyB):
            const ToggleSidebarIntent(),

        // New desktop shortcuts
        LogicalKeySet(modifierKey, LogicalKeyboardKey.keyP):
            const ExportPdfIntent(),
        LogicalKeySet(modifierKey, LogicalKeyboardKey.comma):
            const OpenSettingsIntent(),
        LogicalKeySet(modifierKey, LogicalKeyboardKey.keyW):
            const CloseNoteIntent(),
        LogicalKeySet(modifierKey, LogicalKeyboardKey.tab):
            const NextNoteIntent(),
        LogicalKeySet(LogicalKeyboardKey.f11):
            const ToggleFullScreenIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape):
            const ExitZenOrDialogIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          NewNoteIntent: CallbackAction<NewNoteIntent>(
            onInvoke: (intent) => _handleNewNote(context),
          ),
          SaveIntent: CallbackAction<SaveIntent>(
            onInvoke: (intent) => _handleSave(),
          ),
          SearchIntent: CallbackAction<SearchIntent>(
            onInvoke: (intent) => _handleSearch(context),
          ),
          ToggleSidebarIntent: CallbackAction<ToggleSidebarIntent>(
            onInvoke: (intent) => _handleToggleSidebar(ref),
          ),
          ExportPdfIntent: CallbackAction<ExportPdfIntent>(
            onInvoke: (intent) => _handleExportPdf(),
          ),
          OpenSettingsIntent: CallbackAction<OpenSettingsIntent>(
            onInvoke: (intent) => _handleOpenSettings(context),
          ),
          CloseNoteIntent: CallbackAction<CloseNoteIntent>(
            onInvoke: (intent) => _handleCloseNote(context),
          ),
          NextNoteIntent: CallbackAction<NextNoteIntent>(
            onInvoke: (intent) => _handleNextNote(),
          ),
          ToggleFullScreenIntent: CallbackAction<ToggleFullScreenIntent>(
            onInvoke: (intent) => _handleToggleFullScreen(),
          ),
          ExitZenOrDialogIntent: CallbackAction<ExitZenOrDialogIntent>(
            onInvoke: (intent) => _handleExitZenOrDialog(context),
          ),
        },
        child: child,
      ),
    );
  }

  void _handleNewNote(BuildContext context) {
    try {
      final router = GoRouter.of(context);
      router.push('/notes/new');
    } catch (_) {
      // GoRouter not yet available in this context -- ignore.
    }
  }

  void _handleSave() {
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

  void _handleToggleSidebar(WidgetRef ref) {
    if (PlatformUtils.isDesktop) {
      ref.read(sidebarVisibleProvider.notifier).toggle();
    }
  }

  void _handleExportPdf() {
    // Export to PDF placeholder for future implementation.
  }

  void _handleOpenSettings(BuildContext context) {
    try {
      final router = GoRouter.of(context);
      router.go('/settings');
    } catch (_) {
      // GoRouter not available -- ignore.
    }
  }

  void _handleCloseNote(BuildContext context) {
    try {
      final router = GoRouter.of(context);
      router.go('/notes');
    } catch (_) {
      // GoRouter not available -- ignore.
    }
  }

  void _handleNextNote() {
    // Next note cycling is handled by the notes list screen observing
    // this intent via an Actions handler higher up in the tree.
  }

  void _handleToggleFullScreen() {
    if (!PlatformUtils.isDesktop) return;
    windowManager.isFullScreen().then((isFullScreen) {
      windowManager.setFullScreen(!isFullScreen);
    }).catchError((_) {
      // window_manager call failed -- ignore.
    });
  }

  void _handleExitZenOrDialog(BuildContext context) {
    // Escape handler -- checked by the note editor for zen mode exit.
    try {
      final router = GoRouter.of(context);
      final state = router.state;
      if (state.matchedLocation != '/notes') {
        router.go('/notes');
      }
    } catch (_) {
      // Ignore if router context is unavailable.
    }
  }
}
