import 'package:flutter/material.dart';

import '../../../core/platform/platform_utils.dart';
import '../../../l10n/app_localizations.dart';

/// A screen that displays all available keyboard shortcuts grouped by category.
///
/// Shows platform-appropriate modifier key labels (Ctrl on Windows/Linux, Cmd
/// on macOS) and groups shortcuts into General, Editor, and Navigation
/// categories.
class KeyboardShortcutsScreen extends StatelessWidget {
  const KeyboardShortcutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mod = PlatformUtils.modifierLabel;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.keyboardShortcuts)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ..._buildGeneralShortcuts(l10n, mod),
          ..._buildEditorShortcuts(l10n, mod),
          ..._buildNavigationShortcuts(l10n),
        ],
      ),
    );
  }

  List<Widget> _buildGeneralShortcuts(AppLocalizations l10n, String mod) {
    return [
      _CategoryHeader(title: l10n.general),
      _ShortcutTile(shortcut: '$mod+N', description: l10n.shortcutNewNote),
      _ShortcutTile(shortcut: '$mod+S', description: l10n.shortcutSave),
      _ShortcutTile(shortcut: '$mod+F', description: l10n.shortcutSearch),
      _ShortcutTile(
          shortcut: '$mod+K', description: l10n.shortcutCommandPalette,),
      _ShortcutTile(shortcut: '$mod+,', description: l10n.shortcutSettings),
      _ShortcutTile(shortcut: '$mod+W', description: l10n.shortcutCloseNote),
      _ShortcutTile(shortcut: '$mod+P', description: l10n.shortcutPrint),
      _ShortcutTile(
          shortcut: '$mod+B', description: l10n.shortcutToggleSidebar,),
      _ShortcutTile(
          shortcut: '$mod+Shift+F', description: l10n.shortcutFocusMode,),
      if (!PlatformUtils.isMacOS)
        _ShortcutTile(shortcut: 'F11', description: l10n.shortcutFullScreen),
      _ShortcutTile(shortcut: 'Esc', description: l10n.shortcutExitZen),
    ];
  }

  List<Widget> _buildEditorShortcuts(AppLocalizations l10n, String mod) {
    return [
      _CategoryHeader(title: l10n.editor),
      _ShortcutTile(shortcut: '$mod+B', description: l10n.shortcutBold),
      _ShortcutTile(shortcut: '$mod+I', description: l10n.shortcutItalic),
      _ShortcutTile(
          shortcut: '$mod+Shift+S', description: l10n.shortcutStrikethrough,),
      _ShortcutTile(shortcut: '$mod+Z', description: l10n.shortcutUndo),
      _ShortcutTile(shortcut: '$mod+Y', description: l10n.shortcutRedo),
      _ShortcutTile(shortcut: '$mod+Shift+K', description: l10n.shortcutLink),
      _ShortcutTile(shortcut: '$mod+`', description: l10n.shortcutCode),
      _ShortcutTile(shortcut: '$mod+H', description: l10n.shortcutHeading),
      _ShortcutTile(
        shortcut: '$mod+1 / 2 / 3',
        description:
            '${l10n.slashHeading1} / ${l10n.slashHeading2} / ${l10n.slashHeading3}',
      ),
      _ShortcutTile(
          shortcut: '$mod+Shift+L', description: l10n.slashBulletList,),
    ];
  }

  List<Widget> _buildNavigationShortcuts(AppLocalizations l10n) {
    return [
      _CategoryHeader(title: l10n.navigation),
      _ShortcutTile(shortcut: 'Alt+Left', description: l10n.back),
      _ShortcutTile(shortcut: 'Alt+Right', description: l10n.next),
    ];
  }
}

/// A section header for a shortcut category.
class _CategoryHeader extends StatelessWidget {
  final String title;
  const _CategoryHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// A single row showing a keyboard shortcut and its description.
class _ShortcutTile extends StatelessWidget {
  final String shortcut;
  final String description;

  const _ShortcutTile({
    required this.shortcut,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Keyboard shortcut badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF44403C)
                    : const Color(0xFFD5CDC3),
              ),
            ),
            child: Text(
              shortcut,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Description
          Expanded(
            child: Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
