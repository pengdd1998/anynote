import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/app_localizations.dart';
import '../platform/platform_utils.dart';
import '../theme/app_colors.dart';
import 'sidebar_provider.dart';

/// Desktop-only menu bar for AnyNote.
///
/// On macOS the menu is rendered natively via [PlatformMenuBar].
/// On Windows and Linux a Material [MenuBar] widget is placed at the top
/// of the screen using a [Column] layout.
/// On mobile/web this widget returns [child] unchanged.
///
/// Standard edit shortcuts (Undo, Redo, Cut, Copy, Paste, Select All) are
/// displayed in the menu for discoverability. On macOS they are dispatched to
/// the focused text field by the platform natively when `onSelected` is null.
class AppMenuBar extends ConsumerWidget {
  final Widget child;

  const AppMenuBar({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!PlatformUtils.isDesktop) return child;

    if (PlatformUtils.isMacOS) {
      return _buildPlatformMenuBar(context, ref);
    }
    return _buildMaterialMenuBar(context, ref);
  }

  // ── macOS native menu bar ──────────────────────────────

  Widget _buildPlatformMenuBar(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PlatformMenuBar(
      menus: _buildPlatformMenus(context, ref, l10n),
      child: child,
    );
  }

  // ── Material menu bar (Windows / Linux) ────────────────

  Widget _buildMaterialMenuBar(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MenuBar(
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(colorScheme.surface),
            elevation: const WidgetStatePropertyAll(0),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 4),
            ),
          ),
          children: _buildMaterialMenuItems(context, ref, l10n),
        ),
        Expanded(child: child),
      ],
    );
  }

  // ── PlatformMenu definitions (macOS) ───────────────────

  List<PlatformMenu> _buildPlatformMenus(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations? l10n,
  ) {
    return [
      // File menu
      PlatformMenu(
        label: l10n?.menuFile ?? 'File',
        menus: [
          PlatformMenuItem(
            label: l10n?.menuNewNote ?? 'New Note',
            shortcut: _shortcut(LogicalKeyboardKey.keyN),
            onSelected: () => _navigateTo(context, '/notes/new'),
          ),
          PlatformMenuItem(
            label: l10n?.menuSave ?? 'Save',
            shortcut: _shortcut(LogicalKeyboardKey.keyS),
            onSelected: () {},
          ),
          PlatformMenuItemGroup(
            members: [
              PlatformMenuItem(label: '', onSelected: () {}),
            ],
          ),
          PlatformMenuItem(
            label: l10n?.menuImport ?? 'Import...',
            onSelected: () => _navigateTo(context, '/settings/import'),
          ),
          PlatformMenuItem(
            label: l10n?.menuExport ?? 'Export...',
            shortcut: _shortcut(LogicalKeyboardKey.keyP),
            onSelected: () {},
          ),
          PlatformMenuItemGroup(
            members: [
              PlatformMenuItem(label: '', onSelected: () {}),
            ],
          ),
          PlatformMenuItem(
            label: l10n?.menuCloseTab ?? 'Close Tab',
            shortcut: _shortcut(LogicalKeyboardKey.keyW),
            onSelected: () => _closeCurrentNote(context),
          ),
          const PlatformMenuItemGroup(
            members: [
              PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
            ],
          ),
        ],
      ),

      // Edit menu
      PlatformMenu(
        label: l10n?.menuEdit ?? 'Edit',
        menus: [
          PlatformMenuItem(
            label: l10n?.menuUndo ?? 'Undo',
            shortcut: _shortcut(LogicalKeyboardKey.keyZ),
            onSelected: null,
          ),
          PlatformMenuItem(
            label: l10n?.menuRedo ?? 'Redo',
            shortcut: _shortcutShift(LogicalKeyboardKey.keyZ),
            onSelected: null,
          ),
          PlatformMenuItemGroup(
            members: [
              PlatformMenuItem(label: '', onSelected: () {}),
            ],
          ),
          PlatformMenuItem(
            label: l10n?.menuCut ?? 'Cut',
            shortcut: _shortcut(LogicalKeyboardKey.keyX),
            onSelected: null,
          ),
          PlatformMenuItem(
            label: l10n?.menuCopy ?? 'Copy',
            shortcut: _shortcut(LogicalKeyboardKey.keyC),
            onSelected: null,
          ),
          PlatformMenuItem(
            label: l10n?.menuPaste ?? 'Paste',
            shortcut: _shortcut(LogicalKeyboardKey.keyV),
            onSelected: null,
          ),
          PlatformMenuItemGroup(
            members: [
              PlatformMenuItem(label: '', onSelected: () {}),
            ],
          ),
          PlatformMenuItem(
            label: l10n?.menuSelectAll ?? 'Select All',
            shortcut: _shortcut(LogicalKeyboardKey.keyA),
            onSelected: null,
          ),
          PlatformMenuItemGroup(
            members: [
              PlatformMenuItem(label: '', onSelected: () {}),
            ],
          ),
          PlatformMenuItem(
            label: l10n?.menuFind ?? 'Find...',
            shortcut: _shortcut(LogicalKeyboardKey.keyF),
            onSelected: () => _navigateTo(context, '/search'),
          ),
        ],
      ),

      // View menu
      PlatformMenu(
        label: l10n?.menuView ?? 'View',
        menus: [
          PlatformMenuItem(
            label: l10n?.menuToggleSidebar ?? 'Toggle Sidebar',
            shortcut: _shortcut(LogicalKeyboardKey.keyB),
            onSelected: () =>
                ref.read(sidebarVisibleProvider.notifier).toggle(),
          ),
          PlatformMenuItem(
            label: l10n?.menuTogglePreview ?? 'Toggle Preview',
            shortcut: _shortcutShift(LogicalKeyboardKey.keyP),
            onSelected: () {},
          ),
          PlatformMenuItem(
            label: l10n?.menuZenMode ?? 'Zen Mode',
            onSelected: () {},
          ),
          PlatformMenuItemGroup(
            members: [
              PlatformMenuItem(label: '', onSelected: () {}),
            ],
          ),
          PlatformMenuItem(
            label: l10n?.menuFullScreen ?? 'Enter Full Screen',
            shortcut: const SingleActivator(LogicalKeyboardKey.f11),
            onSelected: () => _toggleFullScreen(),
          ),
        ],
      ),

      // Help menu
      PlatformMenu(
        label: l10n?.menuHelp ?? 'Help',
        menus: [
          PlatformMenuItem(
            label: l10n?.menuAbout ?? 'About AnyNote',
            onSelected: () => _showAboutDialog(context),
          ),
          PlatformMenuItem(
            label: l10n?.menuKeyboardShortcuts ?? 'Keyboard Shortcuts',
            shortcut: _shortcut(LogicalKeyboardKey.slash),
            onSelected: () => _showShortcutsDialog(context),
          ),
        ],
      ),
    ];
  }

  // ── Material menu items (Windows/Linux) ────────────────

  List<Widget> _buildMaterialMenuItems(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations? l10n,
  ) {
    return [
      // File menu
      SubmenuButton(
        menuChildren: [
          MenuItemButton(
            shortcut: _shortcut(LogicalKeyboardKey.keyN),
            child: Text(l10n?.menuNewNote ?? 'New Note'),
            onPressed: () => _navigateTo(context, '/notes/new'),
          ),
          MenuItemButton(
            shortcut: _shortcut(LogicalKeyboardKey.keyS),
            child: Text(l10n?.menuSave ?? 'Save'),
            onPressed: () {},
          ),
          const Divider(),
          MenuItemButton(
            child: Text(l10n?.menuImport ?? 'Import...'),
            onPressed: () => _navigateTo(context, '/settings/import'),
          ),
          MenuItemButton(
            shortcut: _shortcut(LogicalKeyboardKey.keyP),
            child: Text(l10n?.menuExport ?? 'Export...'),
            onPressed: () {},
          ),
          const Divider(),
          MenuItemButton(
            shortcut: _shortcut(LogicalKeyboardKey.keyW),
            child: Text(l10n?.menuCloseTab ?? 'Close Tab'),
            onPressed: () => _closeCurrentNote(context),
          ),
        ],
        child: Text(l10n?.menuFile ?? 'File'),
      ),

      // Edit menu
      SubmenuButton(
        menuChildren: [
          MenuItemButton(
            shortcut: _shortcut(LogicalKeyboardKey.keyZ),
            child: Text(l10n?.menuUndo ?? 'Undo'),
            onPressed: () {},
          ),
          MenuItemButton(
            shortcut: _shortcutShift(LogicalKeyboardKey.keyZ),
            child: Text(l10n?.menuRedo ?? 'Redo'),
            onPressed: () {},
          ),
          const Divider(),
          MenuItemButton(
            shortcut: _shortcut(LogicalKeyboardKey.keyX),
            child: Text(l10n?.menuCut ?? 'Cut'),
            onPressed: () {},
          ),
          MenuItemButton(
            shortcut: _shortcut(LogicalKeyboardKey.keyC),
            child: Text(l10n?.menuCopy ?? 'Copy'),
            onPressed: () {},
          ),
          MenuItemButton(
            shortcut: _shortcut(LogicalKeyboardKey.keyV),
            child: Text(l10n?.menuPaste ?? 'Paste'),
            onPressed: () {},
          ),
          const Divider(),
          MenuItemButton(
            shortcut: _shortcut(LogicalKeyboardKey.keyA),
            child: Text(l10n?.menuSelectAll ?? 'Select All'),
            onPressed: () {},
          ),
          const Divider(),
          MenuItemButton(
            shortcut: _shortcut(LogicalKeyboardKey.keyF),
            child: Text(l10n?.menuFind ?? 'Find...'),
            onPressed: () => _navigateTo(context, '/search'),
          ),
        ],
        child: Text(l10n?.menuEdit ?? 'Edit'),
      ),

      // View menu
      SubmenuButton(
        menuChildren: [
          MenuItemButton(
            shortcut: _shortcut(LogicalKeyboardKey.keyB),
            child: Text(l10n?.menuToggleSidebar ?? 'Toggle Sidebar'),
            onPressed: () => ref.read(sidebarVisibleProvider.notifier).toggle(),
          ),
          MenuItemButton(
            shortcut: _shortcutShift(LogicalKeyboardKey.keyP),
            child: Text(l10n?.menuTogglePreview ?? 'Toggle Preview'),
            onPressed: () {},
          ),
          MenuItemButton(
            child: Text(l10n?.menuZenMode ?? 'Zen Mode'),
            onPressed: () {},
          ),
          const Divider(),
          MenuItemButton(
            shortcut: const SingleActivator(LogicalKeyboardKey.f11),
            child: Text(l10n?.menuFullScreen ?? 'Enter Full Screen'),
            onPressed: () => _toggleFullScreen(),
          ),
        ],
        child: Text(l10n?.menuView ?? 'View'),
      ),

      // Help menu
      SubmenuButton(
        menuChildren: [
          MenuItemButton(
            child: Text(l10n?.menuAbout ?? 'About AnyNote'),
            onPressed: () => _showAboutDialog(context),
          ),
          MenuItemButton(
            shortcut: _shortcut(LogicalKeyboardKey.slash),
            child: Text(l10n?.menuKeyboardShortcuts ?? 'Keyboard Shortcuts'),
            onPressed: () => _showShortcutsDialog(context),
          ),
        ],
        child: Text(l10n?.menuHelp ?? 'Help'),
      ),
    ];
  }

  // ── Shortcut helpers ───────────────────────────────────

  /// Create a SingleActivator using the platform-appropriate modifier.
  /// On macOS: uses `meta: true` (Cmd key).
  /// On Windows/Linux: uses `control: true` (Ctrl key).
  SingleActivator _shortcut(LogicalKeyboardKey trigger) {
    return SingleActivator(
      trigger,
      control: !PlatformUtils.isMacOS,
      meta: PlatformUtils.isMacOS,
    );
  }

  /// Same as [_shortcut] but with Shift held.
  SingleActivator _shortcutShift(LogicalKeyboardKey trigger) {
    return SingleActivator(
      trigger,
      control: !PlatformUtils.isMacOS,
      meta: PlatformUtils.isMacOS,
      shift: true,
    );
  }

  // ── Navigation helpers ─────────────────────────────────

  void _navigateTo(BuildContext context, String path) {
    final router = GoRouter.of(context);
    router.push(path);
  }

  void _closeCurrentNote(BuildContext context) {
    final router = GoRouter.of(context);
    router.go('/notes');
  }

  Future<void> _toggleFullScreen() async {
    if (!PlatformUtils.isDesktop) return;
    try {
      final isFullScreen = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!isFullScreen);
    } catch (e) {
      // window_manager not available or not initialized.
      debugPrint('[AppMenuBar] toggle full screen failed: $e');
    }
  }

  void _showAboutDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showAboutDialog(
      context: context,
      applicationName: 'AnyNote',
      applicationVersion: '0.1.0',
      applicationIcon: const Icon(
        Icons.lock_outline,
        size: 48,
        color: AppColors.primary,
      ),
      children: [
        Text(
          l10n?.aboutDescription ??
              'Local-first, privacy-first note-taking with E2E encryption.',
        ),
      ],
    );
  }

  void _showShortcutsDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mod = PlatformUtils.modifierLabel;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.shortcutsDialogTitle ?? 'Keyboard Shortcuts'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shortcutRow('$mod+N', l10n?.shortcutNewNote ?? 'New Note', ctx),
              _shortcutRow('$mod+S', l10n?.shortcutSave ?? 'Save', ctx),
              _shortcutRow('$mod+F', l10n?.shortcutSearch ?? 'Search', ctx),
              _shortcutRow(
                '$mod+B',
                l10n?.shortcutToggleSidebar ?? 'Toggle Sidebar',
                ctx,
              ),
              _shortcutRow(
                '$mod+P',
                l10n?.shortcutExportPdf ?? 'Export to PDF',
                ctx,
              ),
              _shortcutRow(
                '$mod+,',
                l10n?.shortcutSettings ?? 'Open Settings',
                ctx,
              ),
              _shortcutRow(
                '$mod+W',
                l10n?.shortcutCloseNote ?? 'Close Note',
                ctx,
              ),
              _shortcutRow(
                '$mod+Tab',
                l10n?.shortcutNextNote ?? 'Next Note',
                ctx,
              ),
              _shortcutRow(
                'F11',
                l10n?.shortcutFullScreen ?? 'Toggle Full Screen',
                ctx,
              ),
              _shortcutRow(
                'Esc',
                l10n?.shortcutExitZen ?? 'Exit Zen Mode / Close Dialog',
                ctx,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(context)?.okButton ?? 'OK'),
          ),
        ],
      ),
    );
  }

  Widget _shortcutRow(String keys, String description, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(description)),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              keys,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
