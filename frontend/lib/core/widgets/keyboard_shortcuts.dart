import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../platform/platform_utils.dart';
import '../sync/sync_lifecycle.dart';
import '../../main.dart';
import '../../routing/app_router.dart';
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
/// - Ctrl/Cmd + ,         : Open settings
/// - Ctrl/Cmd + W         : Close current note / go to notes list
/// - Ctrl/Cmd + Shift + F : Toggle zen / fullscreen mode
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

  /// Register a callback for the Ctrl+Shift+F zen mode shortcut.
  static void setZenModeCallback(void Function() cb) {
    zenModeCallback = cb;
  }

  /// Clear the zen mode callback (call in dispose).
  static void clearZenModeCallback() {
    zenModeCallback = null;
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
          _navigate('/search');
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
      }
    }

    // Ctrl/Cmd + Shift + F: zen / fullscreen mode toggle.
    if (primaryMod && isShift && event.logicalKey == LogicalKeyboardKey.keyF) {
      AppKeyboardShortcuts.zenModeCallback?.call();
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
    } catch (_) {
      // SyncLifecycle not initialized yet -- ignore.
    }
  }

  void _toggleSidebar() {
    try {
      globalContainer.read(sidebarVisibleProvider.notifier).toggle();
    } catch (_) {
      // Provider not available -- ignore.
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
