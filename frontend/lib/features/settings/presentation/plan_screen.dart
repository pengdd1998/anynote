import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/domain/plan_model.dart';
import '../../settings/providers/plan_providers.dart';

/// Plan selection and comparison screen.
///
/// Shows the user's current plan with usage stats, individual plan cards
/// for Free/Pro/Lifetime, and upgrade/restore buttons.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final planAsync = ref.watch(planInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.planTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.s4,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        // ── Current plan hero card ──────────────────────────
        _CurrentPlanCard(plan: plan),

        const SizedBox(height: AppSpacing.lg),

        // ── Plan cards ──────────────────────────────────────
        Text(
          l10n.comparePlans,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextTertiary
                : AppColors.lightTextTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),

        _PlanCard(
          icon: Icons.explore_outlined,
          title: l10n.freePlan,
          price: l10n.freePlan,
          accentBg: AppColors.accentPeachBg,
          accentText: AppColors.accentPeachText,
          features: [
            '${l10n.maxNotes}: 500',
            '${l10n.aiDailyQuota}: 50',
            '${l10n.storage}: 100 MB',
            '${l10n.maxDevices}: 2',
          ],
          isCurrent: plan.plan == PlanType.free,
        ),
        const SizedBox(height: AppSpacing.s8),

        _PlanCard(
          icon: Icons.workspace_premium_outlined,
          title: l10n.proPlan,
          price: l10n.proPrice,
          accentBg: AppColors.accentYellowBg,
          accentText: AppColors.accentYellowText,
          features: [
            '${l10n.maxNotes}: 10,000',
            '${l10n.aiDailyQuota}: 500',
            '${l10n.storage}: 5 GB',
            '${l10n.maxDevices}: 5',
            '${l10n.collaboration}: ${l10n.yes}',
          ],
          isCurrent: plan.plan == PlanType.pro,
          isRecommended: plan.plan == PlanType.free,
          onTap: plan.plan == PlanType.free
              ? () => _showUpgradeDialog(context, ref)
              : null,
        ),
        const SizedBox(height: AppSpacing.s8),

        _PlanCard(
          icon: Icons.diamond_outlined,
          title: l10n.lifetimePlan,
          price: l10n.lifetimePrice,
          accentBg: AppColors.accentMintBg,
          accentText: AppColors.accentMintText,
          features: [
            '${l10n.maxNotes}: ${l10n.unlimited}',
            '${l10n.aiDailyQuota}: ${l10n.unlimited}',
            '${l10n.storage}: ${l10n.unlimited}',
            '${l10n.maxDevices}: ${l10n.unlimited}',
            '${l10n.collaboration}: ${l10n.yes}',
            '${l10n.publishing}: ${l10n.yes}',
          ],
          isCurrent: plan.plan == PlanType.lifetime,
          onTap: plan.plan != PlanType.lifetime
              ? () => _showUpgradeDialog(context, ref)
              : null,
        ),

        const SizedBox(height: AppSpacing.lg),

        // ── Action buttons ──────────────────────────────────
        if (plan.plan != PlanType.lifetime) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _showUpgradeDialog(context, ref),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              child: Text(l10n.upgrade),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                final success =
                    await ref.read(planInfoProvider.notifier).restorePurchase();
                if (context.mounted) {
                  if (success) {
                    AppSnackBar.info(
                      context,
                      message: AppLocalizations.of(context)!.planRestored,
                    );
                  } else {
                    AppSnackBar.info(
                      context,
                      message:
                          AppLocalizations.of(context)!.noCompletedPayments,
                    );
                  }
                }
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              child: Text(l10n.restorePurchase),
            ),
          ),
        ] else ...[
          _LifetimeBadge(l10n: l10n),
        ],
      ],
    );
  }

  void _showUpgradeDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.selectPlan),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        backgroundColor: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
        contentPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          0,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _UpgradeOption(
              icon: Icons.workspace_premium_outlined,
              title: l10n.proPlan,
              subtitle: l10n.proPlanDescription,
              price: l10n.proPrice,
              accentBg: AppColors.accentYellowBg,
              accentText: AppColors.accentYellowText,
              onTap: () {
                Navigator.pop(ctx);
                ref.read(planInfoProvider.notifier).startCheckout('pro');
              },
            ),
            const SizedBox(height: AppSpacing.s8),
            _UpgradeOption(
              icon: Icons.diamond_outlined,
              title: l10n.lifetimePlan,
              subtitle: l10n.lifetimePlanDescription,
              price: l10n.lifetimePrice,
              accentBg: AppColors.accentMintBg,
              accentText: AppColors.accentMintText,
              onTap: () {
                Navigator.pop(ctx);
                ref
                    .read(planInfoProvider.notifier)
                    .startCheckout('lifetime');
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
}

// ── Current plan hero card ─────────────────────────────────────

class _CurrentPlanCard extends StatelessWidget {
  final PlanInfo plan;

  const _CurrentPlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (accentBg, accentText) = switch (plan.plan) {
      PlanType.free => (AppColors.accentPeachBg, AppColors.accentPeachText),
      PlanType.pro => (AppColors.accentYellowBg, AppColors.accentYellowText),
      PlanType.lifetime => (AppColors.accentMintBg, AppColors.accentMintText),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentBg,
            accentText.withAlpha(20),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accentText.withAlpha(40)),
        boxShadow: [
          BoxShadow(
            color: accentText.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plan name row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentText.withAlpha(20),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Icon(
                  plan.plan == PlanType.lifetime
                      ? Icons.diamond_outlined
                      : plan.plan == PlanType.pro
                          ? Icons.workspace_premium_outlined
                          : Icons.explore_outlined,
                  size: 20,
                  color: accentText,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Text(
                l10n.currentPlan(plan.displayName),
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accentText,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Usage stats
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkCardBg.withAlpha(180)
                  : AppColors.lightCardBg.withAlpha(200),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Column(
              children: [
                _UsageRow(
                  icon: Icons.note_outlined,
                  label: l10n.planNotesCount,
                  value: '${plan.noteCount}',
                  limit: plan.limits.maxNotes == -1
                      ? l10n.unlimited
                      : '${plan.limits.maxNotes}',
                  accentText: accentText,
                  progress: plan.limits.maxNotes > 0
                      ? plan.noteCount / plan.limits.maxNotes
                      : 0,
                ),
                const SizedBox(height: AppSpacing.s8),
                _UsageRow(
                  icon: Icons.auto_awesome,
                  label: l10n.aiUsage,
                  value: '${plan.aiDailyUsed}',
                  limit: plan.limits.aiDailyQuota == -1
                      ? l10n.unlimited
                      : '${plan.limits.aiDailyQuota}',
                  accentText: accentText,
                  progress: plan.limits.aiDailyQuota > 0
                      ? plan.aiDailyUsed / plan.limits.aiDailyQuota
                      : 0,
                ),
                const SizedBox(height: AppSpacing.s8),
                _UsageRow(
                  icon: Icons.storage_outlined,
                  label: l10n.storageUsed,
                  value: _formatBytes(plan.storageBytes),
                  limit: plan.limits.maxStorageBytes == -1
                      ? l10n.unlimited
                      : _formatBytes(plan.limits.maxStorageBytes),
                  accentText: accentText,
                  progress: plan.limits.maxStorageBytes > 0
                      ? plan.storageBytes / plan.limits.maxStorageBytes
                      : 0,
                ),
              ],
            ),
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

// ── Usage row with icon ────────────────────────────────────────

class _UsageRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String limit;
  final Color accentText;
  final double progress;

  const _UsageRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.limit,
    required this.accentText,
    this.progress = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark
        ? AppColors.darkTextTertiary
        : AppColors.lightTextTertiary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: subtext),
            const SizedBox(width: AppSpacing.s4),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.caption.copyWith(color: subtext),
              ),
            ),
            Text(
              '$value / $limit',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: accentText,
              ),
            ),
          ],
        ),
        if (progress > 0) ...[
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: subtext.withAlpha(30),
              valueColor: AlwaysStoppedAnimation(accentText),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Individual plan card ───────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String price;
  final Color accentBg;
  final Color accentText;
  final List<String> features;
  final bool isCurrent;
  final bool isRecommended;
  final VoidCallback? onTap;

  const _PlanCard({
    required this.icon,
    required this.title,
    required this.price,
    required this.accentBg,
    required this.accentText,
    required this.features,
    this.isCurrent = false,
    this.isRecommended = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: isCurrent
              ? accentBg
              : (isDark ? AppColors.darkCardBg : AppColors.lightCardBg),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: isCurrent
              ? Border.all(color: accentText.withAlpha(80), width: 1.5)
              : isRecommended
                  ? Border.all(color: accentText.withAlpha(40), width: 1)
                  : null,
          boxShadow: isCurrent
              ? [
                  BoxShadow(
                    color: accentText.withAlpha(20),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : AppShadows.smOf(Theme.of(context).brightness),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon + title + price + badges
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? accentText.withAlpha(20)
                        : accentBg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, size: 22, color: accentText),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isRecommended) ...[
                            const SizedBox(width: AppSpacing.s8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accentText.withAlpha(15),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                'Recommended',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: accentText,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        price,
                        style: AppTextStyles.caption.copyWith(
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Icon(Icons.check_circle, size: 20, color: accentText),
              ],
            ),

            const SizedBox(height: AppSpacing.s12),

            // Divider
            Container(
              height: 0.5,
              color: isDark
                  ? AppColors.darkDivider.withAlpha(40)
                  : AppColors.lightDivider.withAlpha(60),
            ),
            const SizedBox(height: AppSpacing.s12),

            // Features
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check,
                        size: 14,
                        color: accentText.withAlpha(180),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          f,
                          style: AppTextStyles.caption.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),),
          ],
        ),
      ),
    );
  }
}

// ── Lifetime member badge ──────────────────────────────────────

class _LifetimeBadge extends StatelessWidget {
  final AppLocalizations l10n;

  const _LifetimeBadge({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.accentMintBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.accentMintText.withAlpha(40)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accentMintText.withAlpha(20),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: const Icon(
              Icons.verified,
              size: 20,
              color: AppColors.accentMintText,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(
              l10n.lifetimeMember,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.accentMintText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Upgrade option in dialog ───────────────────────────────────

class _UpgradeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String price;
  final Color accentBg;
  final Color accentText;
  final VoidCallback onTap;

  const _UpgradeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.accentBg,
    required this.accentText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: accentBg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: accentText.withAlpha(30)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentText.withAlpha(20),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Icon(icon, size: 18, color: accentText),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w700,
                color: accentText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
