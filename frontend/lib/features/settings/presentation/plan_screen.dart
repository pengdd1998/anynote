import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../settings/domain/plan_model.dart';
import '../../settings/providers/plan_providers.dart';

/// Plan selection and comparison screen.
///
/// Shows the user's current plan with usage stats, a comparison table
/// for Free/Pro/Lifetime plans, and upgrade/restore buttons.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final planAsync = ref.watch(planInfoProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.planTitle)),
      body: planAsync.when(
        data: (plan) => _PlanContent(plan: plan),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.unableToLoadPlan)),
      ),
    );
  }
}

class _PlanContent extends ConsumerWidget {
  final PlanInfo plan;

  const _PlanContent({required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Current plan banner
        Card(
          color: colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.workspace_premium_outlined,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.currentPlan(plan.displayName),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _UsageRow(
                  label: l10n.planNotesCount,
                  value: '${plan.noteCount}',
                  limit: plan.limits.maxNotes == -1
                      ? l10n.unlimited
                      : '${plan.limits.maxNotes}',
                ),
                _UsageRow(
                  label: l10n.aiUsage,
                  value: '${plan.aiDailyUsed}',
                  limit: plan.limits.aiDailyQuota == -1
                      ? l10n.unlimited
                      : '${plan.limits.aiDailyQuota}',
                ),
                _UsageRow(
                  label: l10n.storageUsed,
                  value: _formatBytes(plan.storageBytes),
                  limit: plan.limits.maxStorageBytes == -1
                      ? l10n.unlimited
                      : _formatBytes(plan.limits.maxStorageBytes),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Plan comparison table
        Text(
          l10n.comparePlans,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),

        _PlanComparisonCard(
          currentPlan: plan.plan,
        ),

        const SizedBox(height: 24),

        // Action buttons
        if (plan.plan != PlanType.lifetime) ...[
          FilledButton(
            onPressed: () => _showUpgradeDialog(context, ref),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(l10n.upgrade),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              // Restore purchase stub -- will be connected to store later.
              AppSnackBar.info(
                context,
                message: l10n.restorePurchaseComingSoon,
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(l10n.restorePurchase),
          ),
        ] else ...[
          Card(
            color: colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.verified, color: colorScheme.onTertiaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.lifetimeMember,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showUpgradeDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.selectPlan),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.proPlan),
              subtitle: Text(l10n.proPlanDescription),
              trailing: Text(l10n.proPrice),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(planInfoProvider.notifier).upgrade(PlanType.pro);
              },
            ),
            ListTile(
              title: Text(l10n.lifetimePlan),
              subtitle: Text(l10n.lifetimePlanDescription),
              trailing: Text(l10n.lifetimePrice),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(planInfoProvider.notifier).upgrade(PlanType.lifetime);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _UsageRow extends StatelessWidget {
  final String label;
  final String value;
  final String limit;

  const _UsageRow({
    required this.label,
    required this.value,
    required this.limit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(
            '$value / $limit',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// Plan comparison table showing Free vs Pro vs Lifetime.
class _PlanComparisonCard extends StatelessWidget {
  final PlanType currentPlan;

  const _PlanComparisonCard({required this.currentPlan});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    // Feature rows: label, free value, pro value, lifetime value
    final features = [
      _FeatureRow(l10n.maxNotes, '500', '10,000', l10n.unlimited),
      _FeatureRow(l10n.aiDailyQuota, '50', '500', l10n.unlimited),
      _FeatureRow(l10n.storage, '100 MB', '5 GB', l10n.unlimited),
      _FeatureRow(l10n.maxDevices, '2', '5', l10n.unlimited),
      _FeatureRow(l10n.collaboration, l10n.no, l10n.yes, l10n.yes),
      _FeatureRow(l10n.publishing, l10n.yes, l10n.yes, l10n.yes),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1.2),
          2: FlexColumnWidth(1.2),
          3: FlexColumnWidth(1.2),
        },
        children: [
          // Header row
          TableRow(
            decoration: BoxDecoration(color: colorScheme.surfaceContainerHigh),
            children: [
              const _HeaderCell(''),
              _HeaderCell(l10n.freePlan,
                  highlight: currentPlan == PlanType.free),
              _HeaderCell(l10n.proPlan, highlight: currentPlan == PlanType.pro),
              _HeaderCell(
                l10n.lifetimePlan,
                highlight: currentPlan == PlanType.lifetime,
              ),
            ],
          ),
          ...features.map(
            (f) => TableRow(
              children: [
                _DataCell(f.label, bold: false),
                _DataCell(f.free),
                _DataCell(f.pro),
                _DataCell(f.lifetime),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow {
  final String label;
  final String free;
  final String pro;
  final String lifetime;

  const _FeatureRow(this.label, this.free, this.pro, this.lifetime);
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final bool highlight;

  const _HeaderCell(this.text, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: highlight
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String text;
  final bool bold;

  const _DataCell(this.text, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
