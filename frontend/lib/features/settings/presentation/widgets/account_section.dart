import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/api_models.dart';

/// Account section for the settings screen.
///
/// Shows the user's email, plan tier, and a link to edit their profile.
class AccountSection extends ConsumerWidget {
  final AsyncValue<AccountInfo> accountAsync;

  const AccountSection({super.key, required this.accountAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsGroupHeader(title: l10n.account),
        SettingsGroup(
          children: [
            accountAsync.when(
              data: (account) => _buildItems(context, account, l10n),
              loading: () => _buildLoadingItems(l10n),
              error: (_, __) => _buildErrorItems(l10n),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildItems(
    BuildContext context,
    AccountInfo account,
    AppLocalizations l10n,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsItem(
          icon: AppIcons.personOutline,
          title: l10n.email,
          subtitle: account.email,
        ),
        SettingsItem(
          icon: AppIcons.badge,
          title: l10n.plan,
          subtitle: account.plan,
          trailing: FilledButton.tonal(
            onPressed: () => context.push('/settings/plan'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(l10n.upgrade),
          ),
        ),
        SettingsItem(
          icon: AppIcons.personOutline,
          title: l10n.profile,
          subtitle: l10n.editPublicProfile,
          trailing: const Icon(AppIcons.chevronRight, size: 20),
          onTap: () => context.push('/settings/profile'),
        ),
      ],
    );
  }

  Widget _buildLoadingItems(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsItem(
          icon: AppIcons.personOutline,
          title: l10n.email,
          subtitle: l10n.loading,
        ),
        SettingsItem(
          icon: AppIcons.badge,
          title: l10n.plan,
          subtitle: l10n.loading,
        ),
      ],
    );
  }

  Widget _buildErrorItems(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsItem(
          icon: AppIcons.personOutline,
          title: l10n.email,
          subtitle: l10n.unableToLoadAccountInfo,
        ),
        SettingsItem(
          icon: AppIcons.badge,
          title: l10n.plan,
          subtitle: '--',
        ),
      ],
    );
  }
}
