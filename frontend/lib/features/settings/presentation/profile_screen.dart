import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/keyboard_scroll_mixin.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/plan_providers.dart';

/// Profile screen.
///
/// Shows the user's avatar, display name, email, and account info cards,
/// with an inline editor for display name, bio, and public profile visibility.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with WidgetsBindingObserver, KeyboardScrollMixin {
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  final _displayNameFocus = FocusNode();
  final _bioFocus = FocusNode();
  late bool _publicProfileEnabled;
  bool _initialized = false;
  bool _saving = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _displayNameController.dispose();
    _bioController.dispose();
    _displayNameFocus.dispose();
    _bioFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    onKeyboardMetricsChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(l10n.profile),
        centerTitle: true,
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
          return _buildBody(context, l10n, profile);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.unableToLoadProfile)),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    Map<String, dynamic> profile,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initial = _displayNameController.text.trim().isNotEmpty
        ? _displayNameController.text.trim().substring(0, 1).toUpperCase()
        : '?';
    final email = profile['email'] as String? ?? '';
    final createdAtRaw = profile['created_at'] as String?;
    final createdAt =
        createdAtRaw == null ? null : DateTime.tryParse(createdAtRaw);

    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.s4,
            AppSpacing.md,
            200,
          ),
          children: [
            // ── Avatar hero ─────────────────────────────────────
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? AppColors.primary.withAlpha(45)
                      : AppColors.primarySoft,
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: AppTextStyles.headline.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.secondary
                          : AppColors.primaryText,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s8),

            // Display name in the handwritten voice.
            Center(
              child: Text(
                _displayNameController.text.trim().isNotEmpty
                    ? _displayNameController.text.trim()
                    : l10n.displayNameHint,
                style: AppTextStyles.handwritingBody.copyWith(
                  fontSize: 26,
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

            // Email caption.
            if (email.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s4),
              Center(
                child: Text(
                  email,
                  style: AppTextStyles.caption.copyWith(
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s4),

            // "Edit Profile" link toggles the inline editor.
            Center(
              child: TextButton(
                onPressed: () => setState(() => _editing = !_editing),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: AppSpacing.s4,
                  ),
                ),
                child: Text(
                  l10n.profileTitle,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.secondary : AppColors.primaryText,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Account info cards ──────────────────────────────
            _SectionLabel(
              label: l10n.account,
              isDark: isDark,
            ),
            const SizedBox(height: AppSpacing.s8),
            if (email.isNotEmpty)
              _InfoCard(
                isDark: isDark,
                icon: Icons.alternate_email,
                title: l10n.email,
                value: email,
                iconBg: isDark
                    ? AppColors.accentLavenderText.withAlpha(36)
                    : AppColors.accentLavenderBg,
                iconColor: isDark
                    ? AppColors.accentLavender
                    : AppColors.accentLavenderText,
              ),
            if (email.isNotEmpty) const SizedBox(height: AppSpacing.s12),
            if (createdAt != null)
              _InfoCard(
                isDark: isDark,
                icon: Icons.calendar_today_outlined,
                title: l10n.joined,
                value: _formatJoinedDate(createdAt),
                iconBg: isDark
                    ? AppColors.accentPeachText.withAlpha(36)
                    : AppColors.accentPeachBg,
                iconColor: isDark
                    ? AppColors.accentPeach
                    : AppColors.accentPeachText,
              ),

            // ── Inline editor (toggled by "Edit Profile") ───────
            if (_editing) ...[
              const SizedBox(height: AppSpacing.lg),
              _SectionLabel(
                label: l10n.edit,
                isDark: isDark,
              ),
              const SizedBox(height: AppSpacing.s8),

              // Name + bio card.
              Container(
                padding: const EdgeInsets.all(AppSpacing.s16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
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
                      focusNode: _displayNameFocus,
                      maxLength: 100,
                      scrollPadding: const EdgeInsets.only(bottom: 120),
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
                      focusNode: _bioFocus,
                      maxLength: 500,
                      maxLines: 4,
                      scrollPadding: const EdgeInsets.only(bottom: 120),
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

              const SizedBox(height: AppSpacing.s12),

              // ── Public profile toggle card ────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: AppSpacing.s8,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _publicProfileEnabled
                            ? (isDark
                                ? AppColors.accentMintText.withAlpha(36)
                                : AppColors.accentMintBg)
                            : (isDark
                                ? AppColors.darkTextTertiary.withAlpha(12)
                                : AppColors.lightInputFill),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Icon(
                        Icons.public,
                        size: 18,
                        color: _publicProfileEnabled
                            ? (isDark
                                ? AppColors.accentMint
                                : AppColors.accentMintText)
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
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
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
            ],
          ],
        );
      },
    );
  }

  /// Formats a join date as a compact "Mar 5, 2025" label.
  static String _formatJoinedDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
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

/// Small tertiary section label used above card groups.
class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;

  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.caption.copyWith(
        fontWeight: FontWeight.w600,
        color:
            isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
      ),
    );
  }
}

/// A read-only info row-card (icon tile, label, value).
class _InfoCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String value;
  final Color iconBg;
  final Color iconColor;

  const _InfoCard({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.value,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Icon(icon, size: 20, color: iconColor),
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
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.caption.copyWith(
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
