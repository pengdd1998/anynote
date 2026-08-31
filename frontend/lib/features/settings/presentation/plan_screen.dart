import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/domain/plan_model.dart';
import '../../settings/providers/plan_providers.dart';

/// Plan selection and comparison screen.
///
/// Shows the user's current plan with usage stats, compact Free/Pro cards
/// side by side, a Lifetime card, and upgrade/restore actions.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final planAsync = ref.watch(planInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.planTitle),
        centerTitle: true,
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
        _CurrentPlanCard(
          plan: plan,
          onManagePlan: plan.plan != PlanType.lifetime
              ? () => _showUpgradeDialog(context, ref)
              : null,
        ),

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

        // Free and Pro side by side. IntrinsicHeight bounds the row height
        // (a vertical ListView gives its children unbounded height, which
        // CrossAxisAlignment.stretch requires to be finite).
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MiniPlanCard(
                  title: l10n.freePlan,
                  price: '\$0',
                  caption: l10n.freePlanCaption,
                  isCurrent: plan.plan == PlanType.free,
                  onTap: null,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: _MiniPlanCard(
                  title: l10n.proPlan,
                  price: l10n.proPrice,
                  caption: l10n.proPlanCaption,
                  isCurrent: plan.plan == PlanType.pro,
                  highlight: true,
                  onTap: plan.plan == PlanType.free
                      ? () => _showUpgradeDialog(context, ref)
                      : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),

        // Lifetime full width.
        _MiniPlanCard(
          title: l10n.lifetimePlan,
          price: l10n.lifetimePrice,
          caption: l10n.lifetimePlanDescription,
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
                  borderRadius: BorderRadius.circular(AppRadius.xs),
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
                  borderRadius: BorderRadius.circular(AppRadius.xs),
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

/// Soft periwinkle hero card with the current plan name, description, usage
/// stats, and an optional "Manage Plan" action.
class _CurrentPlanCard extends StatelessWidget {
  final PlanInfo plan;
  final VoidCallback? onManagePlan;

  const _CurrentPlanCard({
    required this.plan,
    this.onManagePlan,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final labelColor =
        isDark ? AppColors.secondary : AppColors.primaryText;
    final headlineColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final subtextColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:
            isDark ? AppColors.primary.withAlpha(38) : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withAlpha(60)
              : AppColors.primarySoftBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Small "Current Plan" label.
          Text(
            l10n.currentPlanLabel,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),

          // Plan name in the handwritten voice.
          Text(
            plan.displayName,
            style: AppTextStyles.handwritingTitle.copyWith(
              color: headlineColor,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            _planDescription(l10n),
            style: AppTextStyles.caption.copyWith(color: subtextColor),
          ),
          const SizedBox(height: AppSpacing.s16),

          // Usage stats panel.
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkCardBg.withAlpha(160)
                  : AppColors.lightCardBg,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
              ),
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
                  accent: labelColor,
                  subtext: subtextColor,
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
                  accent: labelColor,
                  subtext: subtextColor,
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
                  accent: labelColor,
                  subtext: subtextColor,
                  progress: plan.limits.maxStorageBytes > 0
                      ? plan.storageBytes / plan.limits.maxStorageBytes
                      : 0,
                ),
              ],
            ),
          ),

          // Manage plan action.
          if (onManagePlan != null) ...[
            const SizedBox(height: AppSpacing.s16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onManagePlan,
                style: TextButton.styleFrom(
                  backgroundColor: isDark
                      ? AppColors.darkCardBg
                      : AppColors.lightCardBg,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.s12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
                child: Text(
                  l10n.managePlan,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _planDescription(AppLocalizations l10n) {
    return switch (plan.plan) {
      PlanType.pro => l10n.proPlanDescription,
      PlanType.lifetime => l10n.lifetimePlanDescription,
      PlanType.free => l10n.freePlanDescription,
    };
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
  final Color accent;
  final Color subtext;
  final double progress;

  const _UsageRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.limit,
    required this.accent,
    required this.subtext,
    this.progress = 0,
  });

  @override
  Widget build(BuildContext context) {
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
                color: accent,
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
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Compact plan card ──────────────────────────────────────────

/// Compact plan card: title, large price, caption, and a check indicator.
/// [highlight] renders the card on the periwinkle accent (Pro in the mockup).
class _MiniPlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String caption;
  final bool isCurrent;
  final bool highlight;
  final VoidCallback? onTap;

  const _MiniPlanCard({
    required this.title,
    required this.price,
    required this.caption,
    required this.isCurrent,
    this.highlight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tertiary = isDark
        ? AppColors.darkTextTertiary
        : AppColors.lightTextTertiary;

    final titleColor = highlight
        ? Colors.white
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    final priceColor = highlight
        ? Colors.white
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    final captionColor = highlight
        ? Colors.white70
        : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary);

    return Material(
      color: highlight
          ? AppColors.primary
          : (isDark ? AppColors.darkCardBg : AppColors.lightCardBg),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: highlight
                ? null
                : Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title + current-plan check.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s4),
                  // Check indicator: filled when current, outline otherwise.
                  Icon(
                    isCurrent
                        ? AppIcons.checkCircleFilled
                        : AppIcons.checkCircle,
                    size: 18,
                    color: highlight
                        ? Colors.white
                        : (isCurrent
                            ? (isDark
                                ? AppColors.secondary
                                : AppColors.primaryText)
                            : tertiary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),

              // Large price.
              Text(
                price,
                style: AppTextStyles.headline.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: priceColor,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),

              // Caption.
              Text(
                caption,
                style: AppTextStyles.caption.copyWith(color: captionColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
        borderRadius: BorderRadius.circular(AppRadius.sm),
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
