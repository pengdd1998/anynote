import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/plan_providers.dart';

/// Profile editing screen.
///
/// Allows the user to set a display name, bio, and toggle public profile.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  late bool _publicProfileEnabled;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          profileAsync.when(
            data: (_) => _saving
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: _save,
                    child: Text(l10n.save),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (!_initialized) {
            _displayNameController = TextEditingController(
              text: profile['display_name'] as String? ?? '',
            );
            _bioController = TextEditingController(
              text: profile['bio'] as String? ?? '',
            );
            _publicProfileEnabled =
                profile['public_profile_enabled'] as bool? ?? false;
            _initialized = true;
          }
          return _buildForm(context, l10n);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.unableToLoadProfile)),
      ),
    );
  }

  Widget _buildForm(BuildContext context, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initial = _displayNameController.text.trim().isNotEmpty
        ? _displayNameController.text.trim().substring(0, 1).toUpperCase()
        : '?';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.s4,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        // ── Avatar hero ─────────────────────────────────────
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.accentLavenderBg,
                  AppColors.accentMintBg.withAlpha(180),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(30),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: AppTextStyles.headline.copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentLavenderText,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),

        // Name preview below avatar
        Center(
          child: Text(
            _displayNameController.text.trim().isNotEmpty
                ? _displayNameController.text.trim()
                : l10n.displayNameHint,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              color: _displayNameController.text.trim().isNotEmpty
                  ? (isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary)
                  : (isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Form card ───────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.smOf(Theme.of(context).brightness),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display name label
              Text(
                l10n.displayName,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              TextField(
                controller: _displayNameController,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: l10n.displayNameHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Bio label
              Text(
                l10n.bio,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              TextField(
                controller: _bioController,
                maxLength: 500,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: l10n.bioHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  counterStyle: AppTextStyles.caption.copyWith(
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // ── Public profile toggle card ──────────────────────
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s4,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.smOf(Theme.of(context).brightness),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s4,
                  AppSpacing.s12,
                  AppSpacing.s4,
                  0,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _publicProfileEnabled
                            ? AppColors.accentMintBg
                            : AppColors.darkTextTertiary.withAlpha(12),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Icon(
                        Icons.public,
                        size: 18,
                        color: _publicProfileEnabled
                            ? AppColors.accentMintText
                            : (isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.publicProfile,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            l10n.publicProfileDesc,
                            style: AppTextStyles.caption.copyWith(
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.lightTextTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      hint: l10n.publicProfile,
                      child: Switch(
                        value: _publicProfileEnabled,
                        onChanged: (value) {
                          setState(() => _publicProfileEnabled = value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);

    try {
      await ref.read(profileProvider.notifier).updateProfile(
            displayName: _displayNameController.text.trim(),
            bio: _bioController.text.trim(),
            publicProfileEnabled: _publicProfileEnabled,
          );
      if (mounted) {
        AppSnackBar.info(context, message: l10n.profileSaved);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, message: l10n.profileSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
