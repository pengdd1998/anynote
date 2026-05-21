import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/ai_agent_providers.dart';

/// AI Agent action screen.
/// Allows users to execute AI-powered autonomous actions on their notes.
class AIAgentScreen extends ConsumerWidget {
  const AIAgentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final agentState = ref.watch(aiAgentProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiAgent),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.s4,
          AppSpacing.md,
          96,
        ),
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s12),
            child: Text(
              l10n.selectAction,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
            ),
          ),

          // Action cards
          _ActionCard(
            icon: Icons.folder_outlined,
            title: l10n.organizeNotes,
            accentBg: AppColors.accentLavenderBg,
            accentIcon: AppColors.accentLavenderText,
            onTap: () => _executeAction(context, ref, 'organize'),
            enabled: !agentState.isLoading,
          ),
          const SizedBox(height: AppSpacing.s8),
          _ActionCard(
            icon: Icons.summarize_outlined,
            title: l10n.summarizeNotes,
            accentBg: AppColors.accentYellowBg,
            accentIcon: AppColors.accentYellowText,
            onTap: () => _executeAction(context, ref, 'summarize'),
            enabled: !agentState.isLoading,
          ),
          const SizedBox(height: AppSpacing.s8),
          _ActionCard(
            icon: Icons.add_circle_outline,
            title: l10n.createNote,
            accentBg: AppColors.accentMintBg,
            accentIcon: AppColors.accentMintText,
            onTap: () => _executeAction(context, ref, 'create_note'),
            enabled: !agentState.isLoading,
          ),

          const SizedBox(height: AppSpacing.lg),

          // Result area
          if (agentState.isLoading)
            _buildLoadingState(context, isDark)
          else if (agentState.error != null)
            _ResultCard(
              status: l10n.agentFailed,
              detail: agentState.error!,
              isSuccess: false,
            )
          else if (agentState.result != null)
            _ResultCard(
              status: l10n.agentComplete,
              detail: _formatResult(agentState.result!),
              isSuccess: true,
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.smOf(Theme.of(context).brightness),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accentLavenderBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.accentLavenderText,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            'Processing...',
            style: AppTextStyles.body.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _executeAction(BuildContext context, WidgetRef ref, String action) {
    ref.read(aiAgentProvider.notifier).execute(action: action);
  }

  String _formatResult(Map<String, dynamic> result) {
    final parts = <String>[];
    result.forEach((key, value) {
      parts.add('$key: $value');
    });
    return parts.join('\n');
  }
}

/// A warm action card with icon badge, title, subtitle, and chevron.
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accentBg;
  final Color accentIcon;
  final VoidCallback onTap;
  final bool enabled;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.accentBg,
    required this.accentIcon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.smOf(Theme.of(context).brightness),
          ),
          child: Row(
            children: [
              // Icon badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: accentIcon,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              // Text content
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Chevron
              Icon(
                Icons.chevron_right,
                size: 20,
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Result card with success/error styling.
class _ResultCard extends StatelessWidget {
  final String status;
  final String detail;
  final bool isSuccess;

  const _ResultCard({
    required this.status,
    required this.detail,
    required this.isSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isSuccess
        ? AppColors.accentMintBg
        : AppColors.lightErrorBg;
    final iconColor = isSuccess
        ? AppColors.accentMintText
        : AppColors.error;
    final icon = isSuccess
        ? Icons.check_circle_outline
        : Icons.error_outline;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  status,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              detail,
              style: AppTextStyles.caption.copyWith(
                height: 1.5,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
