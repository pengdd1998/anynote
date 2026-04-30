import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_info_provider.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../l10n/app_localizations.dart';

/// About section for the settings screen.
///
/// Displays app version, privacy policy, and terms of service links.
class AboutSection extends ConsumerWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final appInfoAsync = ref.watch(appInfoProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsGroupHeader(title: l10n.about),
        SettingsGroup(
          children: [
            SettingsItem(
              icon: AppIcons.infoOutline,
              title: l10n.version,
              subtitle: appInfoAsync.when(
                data: (info) => '${info.version} (${info.buildNumber})',
                loading: () => '...',
                error: (_, __) => 'Unknown',
              ),
            ),
            SettingsItem(
              icon: AppIcons.privacyTip,
              title: l10n.privacyPolicy,
              trailing: const Icon(AppIcons.chevronRight, size: 20),
              onTap: () => _showPrivacyPolicy(context),
            ),
            SettingsItem(
              icon: AppIcons.description,
              title: l10n.termsOfService,
              trailing: const Icon(AppIcons.chevronRight, size: 20),
              onTap: () => _showTermsOfService(context),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showPrivacyPolicy(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    String content;
    try {
      content = await rootBundle.loadString('doc/legal/privacy-policy.md');
    } catch (e) {
      debugPrint('[AboutSection] failed to load privacy policy asset: $e');
      content = l10n.privacyPolicy;
    }
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.privacyPolicy),
        scrollable: true,
        content: SizedBox(
          width: MediaQuery.of(ctx).size.width * 0.8,
          child: MarkdownBody(data: content, selectable: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.dismiss),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.termsOfService),
        content: Text(l10n.termsOfServiceContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.dismiss),
          ),
        ],
      ),
    );
  }
}
