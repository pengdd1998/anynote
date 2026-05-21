import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/note_properties_dao.dart';
import '../../../../core/widgets/tag_chip.dart';
import '../../../../main.dart';

/// Widget displaying property badges for a note.
///
/// Shows status and priority as colored badges in the notes list.
class PropertyBadges extends ConsumerWidget {
  final String noteId;
  final VoidCallback? onStatusTap;
  final VoidCallback? onPriorityTap;

  /// Pre-loaded properties to avoid per-card database streams.
  /// When provided, the StreamBuilder is skipped entirely.
  final List<NoteProperty>? properties;

  const PropertyBadges({
    super.key,
    required this.noteId,
    this.onStatusTap,
    this.onPriorityTap,
    this.properties,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (properties != null) {
      return _buildFromList(context, properties!);
    }

    final db = ref.watch(databaseProvider);
    final propertiesStream =
        db.notePropertiesDao.watchPropertiesForNote(noteId);

    return StreamBuilder<List<NoteProperty>>(
      stream: propertiesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        return _buildFromList(context, snapshot.data!);
      },
    );
  }

  Widget _buildFromList(BuildContext context, List<NoteProperty> properties) {
    if (properties.isEmpty) return const SizedBox.shrink();

    final badges = <Widget>[];
    for (final property in properties) {
      final badge = _buildBadge(context, property);
      if (badge != null) badges.add(badge);
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: badges
          .expand((badge) => [badge, const SizedBox(width: 4)])
          .toList()
        ..removeLast(),
    );
  }

  Widget? _buildBadge(BuildContext context, NoteProperty property) {
    final info = BuiltInProperties.getInfo(property.key);
    final value = info != null ? _getBadgeText(property, info) : property.key;

    if (value == null) return null;

    switch (property.key) {
      case BuiltInProperties.status:
        return _StatusBadge(
          status: value,
          onTap: onStatusTap,
        );
      case BuiltInProperties.priority:
        return _PriorityBadge(
          priority: value,
          onTap: onPriorityTap,
        );
      case BuiltInProperties.dueDate:
        return _DateBadge(
          date: property.valueDate,
          isDue: true,
        );
      case BuiltInProperties.startDate:
        return _DateBadge(
          date: property.valueDate,
          isDue: false,
        );
      default:
        return null;
    }
  }

  String? _getBadgeText(NoteProperty property, PropertyInfo info) {
    switch (property.valueType) {
      case 'text':
        return property.valueText;
      case 'number':
        return property.valueNumber?.toString();
      case 'date':
        return null; // Handled separately
      default:
        return null;
    }
  }
}

/// Status badge with color coding.
class _StatusBadge extends StatelessWidget {
  final String status;
  final VoidCallback? onTap;

  const _StatusBadge({
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (color, label) = _getStatusInfo(context, status);

    return TagChip(
      label: label,
      color: color,
      selected: true,
      onTap: onTap,
    );
  }

  (Color, String) _getStatusInfo(BuildContext context, String status) {
    final theme = Theme.of(context);
    final lowerStatus = status.toLowerCase();

    switch (lowerStatus) {
      case 'todo':
        return (theme.colorScheme.outline, 'Todo');
      case 'in progress':
      case 'in-progress':
        return (const Color(0xFF2196F3), 'In Progress');
      case 'done':
        return (const Color(0xFF4CAF50), 'Done');
      case 'blocked':
        return (const Color(0xFFF44336), 'Blocked');
      case 'cancelled':
        return (theme.colorScheme.outline.withValues(alpha: 0.7), 'Cancelled');
      default:
        return (theme.colorScheme.outline, status);
    }
  }
}

/// Priority badge.
class _PriorityBadge extends StatelessWidget {
  final String priority;
  final VoidCallback? onTap;

  const _PriorityBadge({
    required this.priority,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _getPriorityInfo(context, priority);

    return TagChip(
      label: priority,
      color: color,
      icon: icon,
      onTap: onTap,
    );
  }

  (IconData, Color) _getPriorityInfo(BuildContext context, String priority) {
    final lowerPriority = priority.toLowerCase();

    switch (lowerPriority) {
      case 'high':
        return (Icons.arrow_upward, const Color(0xFFF44336));
      case 'medium':
        return (Icons.remove, const Color(0xFFFF9800));
      case 'low':
        return (Icons.arrow_downward, const Color(0xFF4CAF50));
      default:
        return (Icons.priority_high, Theme.of(context).colorScheme.outline);
    }
  }
}

/// Date badge for due dates and start dates.
class _DateBadge extends StatelessWidget {
  final DateTime? date;
  final bool isDue;

  const _DateBadge({
    required this.date,
    required this.isDue,
  });

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox.shrink();

    final dateValue = date!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(dateValue.year, dateValue.month, dateValue.day);

    final isOverdue = isDue && dateDay.isBefore(today);
    final isToday = dateDay.isAtSameMomentAs(today);

    final theme = Theme.of(context);
    final color = isOverdue
        ? theme.colorScheme.error
        : isToday
            ? theme.colorScheme.tertiary
            : theme.colorScheme.outline;

    final icon = isDue
        ? (isOverdue ? Icons.warning_amber : Icons.event)
        : Icons.calendar_today;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          '${dateValue.month}/${dateValue.day}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Inline property display for note detail view.
class PropertyChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const PropertyChip({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Theme.of(context).colorScheme.primary;
    return TagChip(
      label: '$label: $value',
      color: chipColor,
    );
  }
}
