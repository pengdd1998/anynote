import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/platform_utils.dart';
import '../../../../core/sync/background_sync_service.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../l10n/app_localizations.dart';

/// Sync section for the settings screen.
///
/// Provides a toggle for enabling/disabling periodic background sync.
/// The toggle is hidden on desktop and web platforms where background
/// sync is not supported.
class SyncSection extends ConsumerWidget {
  const SyncSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Background sync is only available on Android and iOS.
    if (PlatformUtils.isDesktop) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final enabledAsync = ref.watch(backgroundSyncEnabledProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsGroup(
          children: [
            _BackgroundSyncTile(
              enabled: enabledAsync.valueOrNull ?? false,
              onChanged: (value) async {
                final service = ref.read(backgroundSyncProvider);
                await service.setEnabled(value);
                ref.invalidate(backgroundSyncEnabledProvider);
              },
              theme: theme,
              l10n: l10n,
            ),
          ],
        ),
      ],
    );
  }
}

/// Single settings row with a trailing switch for the background sync toggle.
class _BackgroundSyncTile extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final ThemeData theme;
  final AppLocalizations l10n;

  const _BackgroundSyncTile({
    required this.enabled,
    required this.onChanged,
    required this.theme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: '${l10n.backgroundSync}: ${enabled ? l10n.on : l10n.off}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!enabled),
          splashColor: colorScheme.primary.withValues(alpha: 0.08),
          highlightColor: colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            child: Row(
              children: [
                const SizedBox(width: 12),
                IconCircle(icon: AppIcons.sync, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.backgroundSync,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          l10n.backgroundSyncDesc,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: enabled,
                  onChanged: onChanged,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
