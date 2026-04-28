import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/note_properties_dao.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';

/// Provider for dashboard data.
final dashboardDataProvider =
    FutureProvider.family<DashboardData, void>((ref, _) async {
  final db = ref.read(databaseProvider);
  final notes = await db.notesDao.getAllNotes();
  final properties = await db.notePropertiesDao.getAllProperties();

  return DashboardData.fromNotes(notes, properties);
});

/// Data structure for the dashboard.
class DashboardData {
  final Map<String, List<Note>> notesByStatus;
  final Map<String, int> priorityDistribution;
  final int totalNotes;
  final int notesWithProperties;

  DashboardData({
    required this.notesByStatus,
    required this.priorityDistribution,
    required this.totalNotes,
    required this.notesWithProperties,
  });

  factory DashboardData.fromNotes(
    List<Note> notes,
    List<NoteProperty> properties,
  ) {
    // Get status values from BuiltInProperties to avoid duplication
    final statusOptions =
        BuiltInProperties.properties[BuiltInProperties.status]?.options ??
            ['Todo', 'In Progress', 'Done', 'Blocked', 'Cancelled'];

    final statusMap = <String, List<Note>>{
      for (final s in statusOptions) s: <Note>[],
      'None': [],
    };

    // Get priority values from BuiltInProperties to avoid duplication
    final priorityOptions =
        BuiltInProperties.properties[BuiltInProperties.priority]?.options ??
            ['High', 'Medium', 'Low'];

    final priorityMap = <String, int>{
      for (final p in priorityOptions) p: 0,
      'None': 0,
    };

    // Create a lookup map for note properties
    final propsMap = <String, List<NoteProperty>>{};
    for (final prop in properties) {
      propsMap.putIfAbsent(prop.noteId, () => []).add(prop);
    }

    int notesWithProps = 0;

    for (final note in notes) {
      if (note.deletedAt != null) continue;

      final noteProps = propsMap[note.id] ?? [];
      if (noteProps.isNotEmpty) notesWithProps++;

      String? status;
      String? priority;

      for (final prop in noteProps) {
        if (prop.key == BuiltInProperties.status) {
          status = prop.valueText;
        } else if (prop.key == BuiltInProperties.priority) {
          priority = prop.valueText;
        }
      }

      // Add to status group
      final statusKey = status ?? 'None';
      statusMap.update(
        statusKey,
        (list) => [...list, note],
        ifAbsent: () => [note],
      );

      // Count priority
      final priorityKey = priority ?? 'None';
      priorityMap.update(priorityKey, (count) => count + 1);
    }

    return DashboardData(
      notesByStatus: statusMap,
      priorityDistribution: priorityMap,
      totalNotes: notes.where((n) => n.deletedAt == null).length,
      notesWithProperties: notesWithProps,
    );
  }
}

/// Properties dashboard screen showing notes grouped by status
/// and priority distribution.
class PropertiesDashboard extends ConsumerStatefulWidget {
  const PropertiesDashboard({super.key});

  @override
  ConsumerState<PropertiesDashboard> createState() =>
      _PropertiesDashboardState();
}

class _PropertiesDashboardState extends ConsumerState<PropertiesDashboard> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dashboardAsync = ref.watch(dashboardDataProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.propertiesDashboard ?? 'Properties Dashboard'),
      ),
      body: dashboardAsync.when(
        data: (data) {
          if (data.totalNotes == 0) {
            return _EmptyState(l10n: l10n);
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatsSection(data: data, l10n: l10n),
                const SizedBox(height: 24),
                _PriorityDistributionSection(
                  distribution: data.priorityDistribution,
                  l10n: l10n,
                ),
                const SizedBox(height: 24),
                _StatusKanbanSection(
                  notesByStatus: data.notesByStatus,
                  l10n: l10n,
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => ErrorStateWidget(
          message: '$err',
          onRetry: () => ref.invalidate(dashboardDataProvider(null)),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations? l10n;

  const _EmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dashboard_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            l10n?.noNotesYet ?? 'No notes yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.createFirstNoteHint ??
                'Create your first note to see the dashboard',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  final DashboardData data;
  final AppLocalizations? l10n;

  const _StatsSection({required this.data, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final coverage = data.totalNotes > 0
        ? (data.notesWithProperties / data.totalNotes * 100).toStringAsFixed(0)
        : '0';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              icon: Icons.note_outlined,
              label: l10n?.totalNotes ?? 'Total Notes',
              value: data.totalNotes.toString(),
            ),
            _StatItem(
              icon: Icons.settings_outlined,
              label: l10n?.withProperties ?? 'With Properties',
              value: '$coverage%',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 32, color: colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withAlpha(150),
              ),
        ),
      ],
    );
  }
}

class _PriorityDistributionSection extends StatelessWidget {
  final Map<String, int> distribution;
  final AppLocalizations? l10n;

  const _PriorityDistributionSection({
    required this.distribution,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = distribution.values.fold<int>(0, (sum, count) => sum + count);

    final priorityColors = {
      'High': colorScheme.error,
      'Medium': colorScheme.tertiary,
      'Low': colorScheme.primary,
      'None': colorScheme.onSurface.withAlpha(50),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.priorityDistribution ?? 'Priority Distribution',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            if (total == 0)
              Text(
                l10n?.noPrioritiesSet ?? 'No priorities set',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withAlpha(100),
                    ),
              )
            else
              ...distribution.entries.map((entry) {
                final count = entry.value;
                if (count == 0) return const SizedBox.shrink();

                final percent = (count / total * 100).toStringAsFixed(0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(entry.key),
                          Text('$count ($percent%)'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: count / total,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            priorityColors[entry.key] ??
                                colorScheme.onSurface.withAlpha(100),
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _StatusKanbanSection extends StatelessWidget {
  final Map<String, List<Note>> notesByStatus;
  final AppLocalizations? l10n;

  const _StatusKanbanSection({
    required this.notesByStatus,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final statusColors = {
      'Todo': colorScheme.primary,
      'In Progress': colorScheme.tertiary,
      'Done': colorScheme.onSurface.withAlpha(100),
      'Blocked': colorScheme.error,
      'Cancelled': colorScheme.onSurface.withAlpha(50),
      'None': colorScheme.onSurface.withAlpha(30),
    };

    final statusIcons = {
      'Todo': Icons.radio_button_unchecked,
      'In Progress': Icons.pending,
      'Done': Icons.check_circle,
      'Blocked': Icons.block,
      'Cancelled': Icons.cancel,
      'None': Icons.help_outline,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            l10n?.notesByStatus ?? 'Notes by Status',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: 12),
        ...notesByStatus.entries.map((entry) {
          final notes = entry.value;
          return _StatusColumn(
            status: entry.key,
            notes: notes,
            color: statusColors[entry.key] ?? Colors.grey,
            icon: statusIcons[entry.key] ?? Icons.help_outline,
            l10n: l10n,
          );
        }),
      ],
    );
  }
}

class _StatusColumn extends StatelessWidget {
  final String status;
  final List<Note> notes;
  final Color color;
  final IconData icon;
  final AppLocalizations? l10n;

  const _StatusColumn({
    required this.status,
    required this.notes,
    required this.color,
    required this.icon,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: notes.isEmpty
            ? null
            : () {
                // Navigate back to notes list with status filter applied
                context.pop();
                // The filter will be applied via the filter state
                AppSnackBar.info(
                  context,
                  message:
                      '${l10n?.filterByStatus ?? 'Filter by status'}: $status',
                );
              },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${notes.length} ${notes.length == 1 ? 'note' : 'notes'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withAlpha(150),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurface.withAlpha(100),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
