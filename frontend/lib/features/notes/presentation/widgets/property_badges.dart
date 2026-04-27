import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/note_properties_dao.dart';
import '../../../../main.dart';

/// Widget displaying property badges for a note.
///
/// Shows status and priority as colored badges in the notes list.
class PropertyBadges extends ConsumerWidget {
  final String noteId;
  final VoidCallback? onStatusTap;
  final VoidCallback? onPriorityTap;

  const PropertyBadges({
    super.key,
    required this.noteId,
    this.onStatusTap,
    this.onPriorityTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final propertiesStream =
        db.notePropertiesDao.watchPropertiesForNote(noteId);

    return StreamBuilder<List<NoteProperty>>(
      stream: propertiesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final properties = snapshot.data!;
        final badges = <Widget>[];

        for (final property in properties) {
          final badge = _buildBadge(context, property);
          if (badge != null) {
            badges.add(badge);
          }
        }

        if (badges.isEmpty) {
          return const SizedBox.shrink();
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: badges
              .expand((badge) => [badge, const SizedBox(width: 4)])
              .toList()
            ..removeLast(),
        );
      },
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

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: badge,
      );
    }
    return badge;
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

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            priority,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: badge,
      );
    }
    return badge;
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
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: chipColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.labelSmall?.copyWith(
              color: chipColor.withValues(alpha: 0.8),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.labelSmall?.copyWith(
              color: chipColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
