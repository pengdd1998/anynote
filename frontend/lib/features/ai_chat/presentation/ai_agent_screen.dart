import 'package:flutter/material.dart';

import '../../../core/error/error_display.dart';
import '../../../core/error/exceptions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
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
        centerTitle: true,
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
          // Section heading
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s12),
            child: Text(
              l10n.iCanHelpWith,
              style: AppTextStyles.title.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ),

          // Capability cards
          _ActionCard(
            icon: AppIcons.folder,
            title: l10n.organizeNotes,
            description: 'Group related notes into tidy collections.',
            accentBg: AppColors.accentYellowBg,
            accentIcon: AppColors.accentYellowText,
            onTap: () => _executeAction(context, ref, 'organize'),
            enabled: !agentState.isLoading,
          ),
          const SizedBox(height: AppSpacing.s12),
          _ActionCard(
            icon: AppIcons.summarize,
            title: l10n.summarizeNotes,
            description: 'Distill long notes into the key points.',
            accentBg: AppColors.accentLavenderBg,
            accentIcon: AppColors.accentLavenderText,
            onTap: () => _executeAction(context, ref, 'summarize'),
            enabled: !agentState.isLoading,
          ),
          const SizedBox(height: AppSpacing.s12),
          _ActionCard(
            icon: AppIcons.noteAdd,
            title: l10n.createNote,
            description: 'Draft a fresh note from a quick prompt.',
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
              detail: ErrorDisplay.userMessage(
                agentState.error is AppException
                    ? agentState.error! as AppException
                    : UnknownException(
                        message:
                            agentState.error?.toString() ?? 'Unknown error',
                      ),
                l10n,
              ),
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
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primaryText,
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

/// A pastel capability card with a white icon square, title, description,
/// and chevron.
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color accentBg;
  final Color accentIcon;
  final VoidCallback onTap;
  final bool enabled;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
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
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardBg : accentBg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: isDark ? Border.all(color: AppColors.darkBorder) : null,
          ),
          child: Row(
            children: [
              // Leading white rounded icon square
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.darkInputFill : AppColors.lightCardBg,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: accentIcon,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              // Title + description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Icon(
                AppIcons.chevronRight,
                size: 16,
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
    final bgColor = isSuccess ? AppColors.accentMintBg : AppColors.lightErrorBg;
    final iconColor = isSuccess
        ? (isDark ? AppColors.success : AppColors.accentMintText)
        : AppColors.error;
    final icon = isSuccess ? Icons.check_circle_outline : Icons.error_outline;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: isDark
            ? (isSuccess ? AppColors.darkSuccessBg : AppColors.darkErrorBg)
            : bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
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
