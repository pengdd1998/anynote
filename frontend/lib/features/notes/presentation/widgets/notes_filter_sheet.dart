import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

/// Property filter bottom sheet.
///
/// Allows the user to filter notes by status, priority, and tags.
class NotesFilterSheet extends StatelessWidget {
  final String? statusFilter;
  final String? priorityFilter;
  final Set<String>? tagFilter;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPriorityChanged;
  final ValueChanged<String>? onTagChanged;
  final VoidCallback? onClearAll;
  final List<Tag> allTags;

  const NotesFilterSheet({
    super.key,
    this.statusFilter,
    this.priorityFilter,
    this.tagFilter,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    this.onTagChanged,
    this.onClearAll,
    this.allTags = const [],
  });

  static const List<String> statusOptions = [
    'Todo',
    'In Progress',
    'Done',
    'Blocked',
    'Cancelled',
  ];

  static const List<String> priorityOptions = [
    'High',
    'Medium',
    'Low',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.filter_list),
                const SizedBox(width: 12),
                Text(
                  l10n.filterByProperties,
                  style: theme.textTheme.titleLarge,
                ),
                const Spacer(),
                if (statusFilter != null ||
                    priorityFilter != null ||
                    (tagFilter != null && tagFilter!.isNotEmpty))
                  TextButton(
                    onPressed: () {
                      onClearAll?.call();
                      Navigator.pop(context);
                    },
                    child: Text(l10n.clearAll),
                  ),
              ],
            ),
          ),
          const Divider(),
          // Status filter section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.status,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: statusOptions.map((status) {
                    final isSelected = statusFilter == status;
                    return FilterChip(
                      label: Text(status),
                      selected: isSelected,
                      onSelected: (selected) {
                        onStatusChanged(selected ? status : null);
                      },
                      selectedColor: theme.colorScheme.primaryContainer,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const Divider(),
          // Priority filter section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.priority,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: priorityOptions.map((priority) {
                    final isSelected = priorityFilter == priority;
                    return FilterChip(
                      label: Text(priority),
                      selected: isSelected,
                      onSelected: (selected) {
                        onPriorityChanged(selected ? priority : null);
                      },
                      selectedColor: theme.colorScheme.secondaryContainer,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const Divider(),
          // Tags filter section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.tagsFilter,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                if (allTags.isEmpty)
                  Text(
                    l10n.noTagsAvailable,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allTags.map((tag) {
                      final isSelected = tagFilter?.contains(tag.id) == true;
                      return FilterChip(
                        label: Text(tag.plainName ?? '...'),
                        selected: isSelected,
                        onSelected: (selected) {
                          onTagChanged?.call(tag.id);
                        },
                        selectedColor: theme.colorScheme.tertiaryContainer,
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Convenience method to show this sheet as a modal bottom sheet.
  static void show({
    required BuildContext context,
    String? statusFilter,
    String? priorityFilter,
    Set<String>? tagFilter,
    List<Tag> allTags = const [],
    required ValueChanged<String?> onStatusChanged,
    required ValueChanged<String?> onPriorityChanged,
    ValueChanged<String>? onTagChanged,
    VoidCallback? onClearAll,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.topXl,
      ),
      builder: (ctx) => NotesFilterSheet(
        statusFilter: statusFilter,
        priorityFilter: priorityFilter,
        tagFilter: tagFilter,
        allTags: allTags,
        onStatusChanged: (status) {
          onStatusChanged(status);
          Navigator.pop(ctx);
        },
        onPriorityChanged: (priority) {
          onPriorityChanged(priority);
          Navigator.pop(ctx);
        },
        onTagChanged: onTagChanged != null
            ? (tagId) {
                onTagChanged(tagId);
                // Do NOT pop — user may want to select multiple tags.
              }
            : null,
        onClearAll: onClearAll,
      ),
    );
  }
}

/// Builds the property filter bar with filter chips displayed in the notes list.
///
/// Shows a collapsed filter button when no filters are active, or active
/// filter chips with clear-all when filters are set.
class NotesFilterBar extends StatelessWidget {
  final String? statusFilter;
  final String? priorityFilter;
  final Set<String>? tagFilter;
  final List<Tag> allTags;
  final VoidCallback onFilterTap;
  final VoidCallback onStatusCleared;
  final VoidCallback onPriorityCleared;
  final ValueChanged<String>? onTagCleared;
  final VoidCallback onClearAll;

  const NotesFilterBar({
    super.key,
    this.statusFilter,
    this.priorityFilter,
    this.tagFilter,
    this.allTags = const [],
    required this.onFilterTap,
    required this.onStatusCleared,
    required this.onPriorityCleared,
    this.onTagCleared,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tagById = {for (final tag in allTags) tag.id: tag};
    final hasTags = tagFilter != null && tagFilter!.isNotEmpty;
    final hasFilters =
        statusFilter != null || priorityFilter != null || hasTags;

    if (!hasFilters) {
      // Show collapsed filter button when no filters are active.
      // Uses a subtle outline and tinted background so the chip stands out
      // against the surface background even when no filters are selected.
      final colorScheme = Theme.of(context).colorScheme;
      return Container(
        height: 40,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s4,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FilterChip(
            label: Text(l10n.filter),
            avatar: Icon(
              Icons.filter_list,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            onSelected: (_) => onFilterTap(),
            selected: false,
            side: BorderSide(
              color: colorScheme.outlineVariant,
            ),
            backgroundColor: colorScheme.surfaceContainerLow,
          ),
        ),
      );
    }

    // Show active filters
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s4,
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (statusFilter != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(l10n.statusLabel(statusFilter!)),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: onStatusCleared,
                avatar: const Icon(Icons.fiber_manual_record, size: 12),
              ),
            ),
          if (priorityFilter != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(l10n.priorityLabel(priorityFilter!)),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: onPriorityCleared,
                avatar: const Icon(Icons.priority_high, size: 12),
              ),
            ),
          if (tagFilter != null)
            for (final tagId in tagFilter!)
              if (tagById[tagId] case final tag?)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Chip(
                    label: Text(tag.plainName ?? '...'),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => onTagCleared?.call(tagId),
                    avatar: const Icon(Icons.label, size: 12),
                  ),
                ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: TextButton.icon(
              onPressed: onClearAll,
              icon: const Icon(Icons.clear_all, size: 16),
              label: Text(l10n.clearAll),
            ),
          ),
        ],
      ),
    );
  }
}
