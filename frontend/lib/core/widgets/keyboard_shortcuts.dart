import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../platform/platform_utils.dart';
import '../sync/sync_lifecycle.dart';
import '../../main.dart';
import '../../routing/app_router.dart';
import '../../features/notes/presentation/widgets/command_palette.dart';
import 'sidebar_provider.dart';

/// Desktop keyboard shortcuts for AnyNote.
///
/// Uses [HardwareKeyboard] to intercept key events globally. This approach
/// is simpler and more reliable than the [Shortcuts]/[Actions] widget tree
/// because it does not depend on focus state.
///
/// Registered shortcuts (Ctrl on Windows/Linux, Cmd on macOS):
/// - Ctrl/Cmd + N         : Create a new note
/// - Ctrl/Cmd + S         : Force sync now
/// - Ctrl/Cmd + F         : Open search
/// - Ctrl/Cmd + B         : Toggle sidebar (desktop only)
/// - Ctrl/Cmd + K         : Toggle command palette
/// - Ctrl/Cmd + ,         : Open settings
/// - Ctrl/Cmd + W         : Close current note / go to notes list
/// - Ctrl/Cmd + P         : Print current note (if editor/preview open)
/// - Ctrl/Cmd + H         : Cycle heading level (h1->h2->h3->p)
/// - Ctrl/Cmd + `         : Toggle inline code
/// - Ctrl/Cmd + Shift + F : Toggle zen / fullscreen mode
/// - Ctrl/Cmd + Shift + K : Insert/toggle link
/// - Ctrl/Cmd + Shift + S : Toggle strikethrough
/// - F11                  : Toggle full screen
///
/// Place this widget above [AppMenuBar] and [MaterialApp.router] so that
/// shortcuts are available globally:
/// ```dart
/// AppKeyboardShortcuts(
///   child: AppMenuBar(
///     child: MaterialApp.router(...),
///   ),
/// )
/// ```
class AppKeyboardShortcuts extends StatefulWidget {
  final Widget child;

  const AppKeyboardShortcuts({super.key, required this.child});

  @override
  State<AppKeyboardShortcuts> createState() => _AppKeyboardShortcutsState();

  // ── Static callback registration ──────────────────────────

  /// Optional callback invoked by Ctrl+Shift+F (zen / fullscreen toggle).
  /// Screens that host a zen mode UI can set this at init time.
  static void Function()? zenModeCallback;

  /// Optional callback invoked by Ctrl+P (print current note).
  /// Screens that host a note editor or preview can set this at init time.
  static void Function()? printCallback;

  /// Optional callback invoked by Ctrl+Shift+K (insert/toggle link).
  /// The editor forwards this to the quill controller.
  static void Function()? insertLinkCallback;

  /// Optional callback invoked by Ctrl+Shift+S (toggle strikethrough).
  static void Function()? strikethroughCallback;

  /// Optional callback invoked by Ctrl+` (toggle inline code).
  static void Function()? inlineCodeCallback;

  /// Optional callback invoked by Ctrl+H (cycle heading h1->h2->h3->p).
  static void Function()? headingCycleCallback;

  /// Optional callback invoked by Ctrl+F when the editor is active.
  /// When set, Ctrl+F opens the in-editor find/replace bar instead of
  /// navigating to the global search page.
  static void Function()? findCallback;

  /// Register a callback for the Ctrl+Shift+F zen mode shortcut.
  static void setZenModeCallback(void Function() cb) {
    zenModeCallback = cb;
  }

  /// Clear the zen mode callback (call in dispose).
  static void clearZenModeCallback() {
    zenModeCallback = null;
  }

  /// Register a callback for the Ctrl+P print shortcut.
  static void setPrintCallback(void Function() cb) {
    printCallback = cb;
  }

  /// Clear the print callback (call in dispose).
  static void clearPrintCallback() {
    printCallback = null;
  }

  /// Register a callback for the Ctrl+Shift+K insert link shortcut.
  static void setInsertLinkCallback(void Function() cb) {
    insertLinkCallback = cb;
  }

  /// Clear the insert link callback.
  static void clearInsertLinkCallback() {
    insertLinkCallback = null;
  }

  /// Register a callback for the Ctrl+Shift+S strikethrough shortcut.
  static void setStrikethroughCallback(void Function() cb) {
    strikethroughCallback = cb;
  }

  /// Clear the strikethrough callback.
  static void clearStrikethroughCallback() {
    strikethroughCallback = null;
  }

  /// Register a callback for the Ctrl+` inline code shortcut.
  static void setInlineCodeCallback(void Function() cb) {
    inlineCodeCallback = cb;
  }

  /// Clear the inline code callback.
  static void clearInlineCodeCallback() {
    inlineCodeCallback = null;
  }

  /// Register a callback for the Ctrl+H heading cycle shortcut.
  static void setHeadingCycleCallback(void Function() cb) {
    headingCycleCallback = cb;
  }

  /// Clear the heading cycle callback.
  static void clearHeadingCycleCallback() {
    headingCycleCallback = null;
  }

  /// Register a callback for the Ctrl+F find shortcut in the editor.
  static void setFindCallback(void Function() cb) {
    findCallback = cb;
  }

  /// Clear the find callback (call in dispose).
  static void clearFindCallback() {
    findCallback = null;
  }
}

class _AppKeyboardShortcutsState extends State<AppKeyboardShortcuts> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    // Only act on key-down and key-repeat events.
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;

    final isDesktop = PlatformUtils.isDesktop;
    if (!isDesktop) return false;

    // Determine the platform-appropriate modifier.
    final isMacOS = PlatformUtils.isMacOS;
    final primaryMod = isMacOS
        ? HardwareKeyboard.instance.isMetaPressed
        : HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    if (primaryMod && !isShift) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyN:
          _navigate('/notes/new');
          return true;
        case LogicalKeyboardKey.keyS:
          _triggerSync();
          return true;
        case LogicalKeyboardKey.keyF:
          if (AppKeyboardShortcuts.findCallback != null) {
            AppKeyboardShortcuts.findCallback!();
          } else {
            _navigate('/search');
          }
          return true;
        case LogicalKeyboardKey.keyB:
          _toggleSidebar();
          return true;
        case LogicalKeyboardKey.comma:
          _navigate('/settings');
          return true;
        case LogicalKeyboardKey.keyW:
          _navigate('/notes');
          return true;
        case LogicalKeyboardKey.keyK:
          _toggleCommandPalette();
          return true;
        // Ctrl/Cmd + P: Print current note (forward to editor/preview).
        case LogicalKeyboardKey.keyP:
          AppKeyboardShortcuts.printCallback?.call();
          return true;
        // Ctrl/Cmd + H: Cycle heading level h1->h2->h3->p.
        case LogicalKeyboardKey.keyH:
          AppKeyboardShortcuts.headingCycleCallback?.call();
          return true;
        // Ctrl/Cmd + `: Toggle inline code.
        case LogicalKeyboardKey.backquote:
          AppKeyboardShortcuts.inlineCodeCallback?.call();
          return true;
      }
    }

    // Ctrl/Cmd + Shift + F: zen / fullscreen mode toggle.
    if (primaryMod && isShift && event.logicalKey == LogicalKeyboardKey.keyF) {
      AppKeyboardShortcuts.zenModeCallback?.call();
      return true;
    }

    // Ctrl/Cmd + Shift + K: Insert/toggle link (forward to editor).
    if (primaryMod && isShift && event.logicalKey == LogicalKeyboardKey.keyK) {
      AppKeyboardShortcuts.insertLinkCallback?.call();
      return true;
    }

    // Ctrl/Cmd + Shift + S: Toggle strikethrough (forward to editor).
    if (primaryMod && isShift && event.logicalKey == LogicalKeyboardKey.keyS) {
      AppKeyboardShortcuts.strikethroughCallback?.call();
      return true;
    }

    // F11: toggle full screen (Windows/Linux only; macOS uses Ctrl+Cmd+F).
    if (!isMacOS && event.logicalKey == LogicalKeyboardKey.f11) {
      _toggleFullScreen();
      return true;
    }

    return false;
  }

  void _navigate(String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        GoRouter.of(ctx).go(route);
      }
    });
  }

  void _triggerSync() {
    try {
      final lifecycle = globalContainer.read(syncLifecycleProvider);
      lifecycle.syncNow();
    } catch (e) {
      // SyncLifecycle not initialized yet -- ignore.
      debugPrint('[AppKeyboardShortcuts] sync trigger failed: $e');
    }
  }

  void _toggleSidebar() {
    try {
      globalContainer.read(sidebarVisibleProvider.notifier).toggle();
    } catch (e) {
      // Provider not available -- ignore.
      debugPrint('[AppKeyboardShortcuts] sidebar toggle failed: $e');
    }
  }

  void _toggleCommandPalette() {
    try {
      final current = globalContainer.read(commandPaletteVisibleProvider);
      globalContainer.read(commandPaletteVisibleProvider.notifier).state =
          !current;
    } catch (e) {
      // Provider not available -- ignore.
      debugPrint('[AppKeyboardShortcuts] command palette toggle failed: $e');
    }
  }

  void _toggleFullScreen() {
    if (!PlatformUtils.isDesktop) return;
    windowManager.isFullScreen().then((isFullScreen) {
      windowManager.setFullScreen(!isFullScreen);
    }).catchError((_) {
      // window_manager call failed -- ignore.
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
