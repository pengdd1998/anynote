import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../../../routing/app_router.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

/// Type of item displayed in the command palette.
enum CommandPaletteItemType { note, action, recent }

/// A single selectable item in the command palette list.
class CommandPaletteItem {
  final String id;
  final String title;
  final String? subtitle;
  final IconData icon;
  final CommandPaletteItemType type;
  final VoidCallback onTap;

  const CommandPaletteItem({
    required this.id,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.type,
    required this.onTap,
  });
}

// ---------------------------------------------------------------------------
// Provider: recently opened notes (in-memory, max 20)
// ---------------------------------------------------------------------------

/// Tracks note IDs that the user has recently opened (most recent first).
final recentlyOpenedProvider = StateProvider<List<String>>((ref) => []);

/// Adds a note ID to the recently-opened list (deduped, max 20).
void addRecentlyOpened(WidgetRef ref, String noteId) {
  final list = List<String>.from(ref.read(recentlyOpenedProvider));
  list.remove(noteId);
  list.insert(0, noteId);
  if (list.length > 20) {
    list.removeRange(20, list.length);
  }
  ref.read(recentlyOpenedProvider.notifier).state = list;
}

// ---------------------------------------------------------------------------
// Provider: visibility toggle
// ---------------------------------------------------------------------------

/// Whether the command palette overlay is currently visible.
final commandPaletteVisibleProvider = StateProvider<bool>((ref) => false);

// ---------------------------------------------------------------------------
// Show helper
// ---------------------------------------------------------------------------

/// Opens the command palette overlay using the global navigator context.
void showCommandPalette() {
  final ctx = rootNavigatorKey.currentContext;
  if (ctx == null || !ctx.mounted) return;
  final container = ProviderScope.containerOf(ctx);
  container.read(commandPaletteVisibleProvider.notifier).state = true;
}

// ---------------------------------------------------------------------------
// Command Palette Overlay
// ---------------------------------------------------------------------------

class CommandPaletteOverlay extends ConsumerStatefulWidget {
  const CommandPaletteOverlay({super.key});

  @override
  ConsumerState<CommandPaletteOverlay> createState() =>
      _CommandPaletteOverlayState();
}

class _CommandPaletteOverlayState extends ConsumerState<CommandPaletteOverlay> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  Timer? _debounce;
  List<CommandPaletteItem> _results = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query.isEmpty) {
      _debounce?.cancel();
      setState(() {
        _results = _buildRecentItems();
        _selectedIndex = 0;
      });
      return;
    }

    // Actions are instant (no debounce).
    final actionResults = _matchActions(query);

    setState(() {
      _selectedIndex = 0;
    });

    // Debounce note search at 300ms.
    _debounce?.cancel();
    _debounce = Timer(AppDurations.animation, () async {
      if (!mounted) return;
      final noteResults = await _searchNotes(query);
      if (!mounted) return;
      setState(() {
        _results = [...actionResults, ...noteResults];
        _selectedIndex = 0;
      });
    });
  }

  // -- Build items from recently opened notes --
  List<CommandPaletteItem> _buildRecentItems() {
    final l10n = AppLocalizations.of(context);
    final recentIds = ref.read(recentlyOpenedProvider);
    if (recentIds.isEmpty) return [];

    return recentIds.map((id) {
      return CommandPaletteItem(
        id: 'recent_$id',
        title: _noteTitleFromId(id) ?? id.substring(0, 8),
        subtitle: l10n?.commandRecentNotes ?? 'Recent',
        icon: Icons.history,
        type: CommandPaletteItemType.recent,
        onTap: () => _navigateToNote(id),
      );
    }).toList();
  }

  // -- Match actions against query (prefix/contains) --
  List<CommandPaletteItem> _matchActions(String query) {
    final l10n = AppLocalizations.of(context);
    final q = query.toLowerCase();
    final actions = _allActions(l10n);

    return actions.where((item) {
      final titleLower = item.title.toLowerCase();
      return titleLower.startsWith(q) || titleLower.contains(q);
    }).toList();
  }

  // -- Full list of available actions --
  List<CommandPaletteItem> _allActions(AppLocalizations? l10n) {
    return [
      CommandPaletteItem(
        id: 'action_new_note',
        title: l10n?.commandCreateNewNote ?? 'Create New Note',
        icon: Icons.note_add_outlined,
        type: CommandPaletteItemType.action,
        onTap: () => _navigate('/notes/new'),
      ),
      CommandPaletteItem(
        id: 'action_daily',
        title: l10n?.commandOpenDailyNotes ?? 'Open Daily Notes',
        icon: Icons.calendar_today_outlined,
        type: CommandPaletteItemType.action,
        onTap: () => _navigate('/notes/daily'),
      ),
      CommandPaletteItem(
        id: 'action_graph',
        title: l10n?.commandOpenGraph ?? 'Open Graph View',
        icon: Icons.account_tree_outlined,
        type: CommandPaletteItemType.action,
        onTap: () => _navigate('/notes/graph'),
      ),
      CommandPaletteItem(
        id: 'action_dashboard',
        title: l10n?.commandOpenDashboard ?? 'Open Dashboard',
        icon: Icons.dashboard_outlined,
        type: CommandPaletteItemType.action,
        onTap: () => _navigate('/notes/dashboard'),
      ),
      CommandPaletteItem(
        id: 'action_trash',
        title: l10n?.commandOpenTrash ?? 'Open Trash',
        icon: Icons.delete_outline,
        type: CommandPaletteItemType.action,
        onTap: () => _navigate('/trash'),
      ),
      CommandPaletteItem(
        id: 'action_settings',
        title: l10n?.commandOpenSettings ?? 'Open Settings',
        icon: Icons.settings_outlined,
        type: CommandPaletteItemType.action,
        onTap: () => _navigate('/settings'),
      ),
    ];
  }

  // -- Search notes via DAO --
  Future<List<CommandPaletteItem>> _searchNotes(String query) async {
    final l10n = AppLocalizations.of(context);
    try {
      final db = ref.read(databaseProvider);
      final notes = await db.notesDao.searchNotes(query);
      return notes.take(20).map((note) {
        final title = note.plainTitle ?? l10n?.untitled ?? 'Untitled';
        final updated = _formatDate(note.updatedAt);
        return CommandPaletteItem(
          id: 'note_${note.id}',
          title: title,
          subtitle: updated,
          icon: Icons.note_outlined,
          type: CommandPaletteItemType.note,
          onTap: () => _navigateToNote(note.id),
        );
      }).toList();
    } catch (e) {
      debugPrint('[CommandPalette] failed to load recent notes: $e');
      return [];
    }
  }

  // -- Cache for note titles (lightweight, avoids extra DB lookups) --
  final Map<String, String> _titleCache = {};

  String? _noteTitleFromId(String id) {
    return _titleCache[id];
  }

  // -- Navigation helpers --
  void _navigate(String route) {
    _close();
    final ctx = rootNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      GoRouter.of(ctx).push(route);
    }
  }

  void _navigateToNote(String noteId) {
    _close();
    final ctx = rootNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      GoRouter.of(ctx).push('/notes/$noteId');
    }
  }

  void _close() {
    ref.read(commandPaletteVisibleProvider.notifier).state = false;
  }

  // -- Keyboard handling --
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _close();
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(0, _results.length - 1);
      });
      _scrollToSelected();
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1).clamp(0, _results.length - 1);
      });
      _scrollToSelected();
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_results.isNotEmpty && _selectedIndex < _results.length) {
        _results[_selectedIndex].onTap();
      }
      return;
    }
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    // Approximate: each item is ~56px. Scroll to keep selected visible.
    const itemHeight = 56.0;
    final targetOffset = _selectedIndex * itemHeight - 100;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: AppDurations.veryShortAnimation,
      curve: Curves.easeOut,
    );
  }

  // -- Date formatting --
  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  // -- Build grouped results --
  List<Widget> _buildResultItems() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final widgets = <Widget>[];

    if (_results.isEmpty && _searchController.text.isNotEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              l10n?.commandNoResultsFound ?? 'No results found',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ];
    }

    // Group by type
    final actionItems =
        _results.where((i) => i.type == CommandPaletteItemType.action).toList();
    final noteItems =
        _results.where((i) => i.type == CommandPaletteItemType.note).toList();
    final recentItems =
        _results.where((i) => i.type == CommandPaletteItemType.recent).toList();

    int globalIndex = 0;

    if (recentItems.isNotEmpty) {
      widgets.add(
        _buildSectionHeader(
          l10n?.commandRecentNotes ?? 'Recent',
          theme,
        ),
      );
      for (final item in recentItems) {
        widgets.add(_buildItemTile(item, globalIndex, theme));
        globalIndex++;
      }
    }

    if (actionItems.isNotEmpty) {
      widgets.add(
        _buildSectionHeader(
          l10n?.commandActions ?? 'Actions',
          theme,
        ),
      );
      for (final item in actionItems) {
        widgets.add(_buildItemTile(item, globalIndex, theme));
        globalIndex++;
      }
    }

    if (noteItems.isNotEmpty) {
      widgets.add(
        _buildSectionHeader(
          l10n?.commandNotesSection ?? 'Notes',
          theme,
        ),
      );
      for (final item in noteItems) {
        widgets.add(_buildItemTile(item, globalIndex, theme));
        globalIndex++;
      }
    }

    return widgets;
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildItemTile(CommandPaletteItem item, int index, ThemeData theme) {
    final isSelected = index == _selectedIndex;
    return _CommandPaletteResultTile(
      item: item,
      isSelected: isSelected,
      onTap: () => item.onTap(),
      onHover: (hovered) {
        if (hovered) {
          setState(() => _selectedIndex = index);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVisible = ref.watch(commandPaletteVisibleProvider);
    if (!isVisible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDesktop = PlatformUtils.isDesktop;
    final shortcutHint = isDesktop ? '${PlatformUtils.modifierLabel}+K' : '';

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyEvent,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Dimmed backdrop -- tap to dismiss
            Positioned.fill(
              child: GestureDetector(
                onTap: _close,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ),
            // Centered panel
            Center(
              child: Container(
                constraints:
                    const BoxConstraints(maxWidth: 600, maxHeight: 480),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search field
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _focusNode,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: l10n?.commandSearchHint ??
                                    'Type to search notes and commands...',
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                          if (shortcutHint.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                shortcutHint,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Results list
                    Flexible(
                      child: _results.isEmpty && _searchController.text.isEmpty
                          ? _buildEmptyState(theme, l10n)
                          : Scrollbar(
                              controller: _scrollController,
                              child: ListView(
                                controller: _scrollController,
                                padding: const EdgeInsets.only(bottom: 8),
                                shrinkWrap: true,
                                children: _buildResultItems(),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, AppLocalizations? l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search,
            size: 32,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            l10n?.commandSearchHint ?? 'Type to search notes and commands...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual result tile
// ---------------------------------------------------------------------------

class _CommandPaletteResultTile extends StatelessWidget {
  final CommandPaletteItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  const _CommandPaletteResultTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bgColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
        : Colors.transparent;
    final fgColor =
        isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      onHover: onHover,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: bgColor,
        child: Row(
          children: [
            Icon(item.icon, size: 20, color: fgColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: fgColor,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.subtitle != null)
                    Text(
                      item.subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (item.type == CommandPaletteItemType.note)
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
          ],
        ),
      ),
    );
  }
}
