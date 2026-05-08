import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
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
  final List<Tag> allTags;

  const NotesFilterSheet({
    super.key,
    this.statusFilter,
    this.priorityFilter,
    this.tagFilter,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    this.onTagChanged,
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
                      onStatusChanged(null);
                      onPriorityChanged(null);
                      // Clear all tags by toggling each selected tag off.
                      if (tagFilter != null) {
                        for (final tagId in tagFilter!) {
                          onTagChanged?.call(tagId);
                        }
                      }
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
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
    final hasTags = tagFilter != null && tagFilter!.isNotEmpty;
    final hasFilters =
        statusFilter != null || priorityFilter != null || hasTags;

    if (!hasFilters) {
      // Show collapsed filter button when no filters are active
      return Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FilterChip(
            label: Text(l10n.filter),
            avatar: const Icon(Icons.filter_list, size: 16),
            onSelected: (_) => onFilterTap(),
            selected: false,
          ),
        ),
      );
    }

    // Show active filters
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
              ...allTags.where((tag) => tag.id == tagId).map(
                    (tag) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(tag.plainName ?? '...'),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => onTagCleared?.call(tagId),
                        avatar: const Icon(Icons.label, size: 12),
                      ),
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
