import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_engine.dart';
import '../../../l10n/app_localizations.dart';

/// Resolution strategy chosen by the user for a sync conflict.
enum ConflictResolution {
  keepLocal,
  keepServer,
  keepBoth,
}

/// Screen displaying sync conflicts and allowing the user to resolve them.
///
/// Since the server is zero-knowledge, we can only show local item info.
/// The user decides whether to keep their local version, accept the server
/// version, or keep both (creating a duplicate).
class ConflictResolutionScreen extends ConsumerWidget {
  final List<SyncConflict> conflicts;

  const ConflictResolutionScreen({super.key, required this.conflicts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.syncConflicts),
      ),
      body: conflicts.isEmpty
          ? Center(child: Text(l10n.noConflicts))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: conflicts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final conflict = conflicts[index];
                return _ConflictCard(
                  conflict: conflict,
                  index: index,
                  theme: theme,
                  l10n: l10n,
                );
              },
            ),
    );
  }
}

class _ConflictCard extends StatelessWidget {
  final SyncConflict conflict;
  final int index;
  final ThemeData theme;
  final AppLocalizations l10n;

  const _ConflictCard({
    required this.conflict,
    required this.index,
    required this.theme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sync_problem, color: colorScheme.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.conflictItem(
                      conflict.itemId.length > 8
                          ? conflict.itemId.substring(0, 8)
                          : conflict.itemId,
                    ),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.serverVersion(conflict.serverVersion),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _resolve(context, ConflictResolution.keepLocal),
                    icon: const Icon(Icons.phone_android, size: 16),
                    label: Text(l10n.keepLocal),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _resolve(context, ConflictResolution.keepServer),
                    icon: const Icon(Icons.cloud_outlined, size: 16),
                    label: Text(l10n.keepServer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _resolve(context, ConflictResolution.keepBoth),
                icon: const Icon(Icons.copy, size: 16),
                label: Text(l10n.keepBoth),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _resolve(BuildContext context, ConflictResolution resolution) {
    // Pop with the resolution decision. The caller (SyncLifecycle or
    // whatever navigated here) will handle the actual resolution.
    Navigator.pop(
        context,
        _ConflictResolutionResult(
          conflict: conflict,
          resolution: resolution,
        ));
  }
}

/// Result of resolving a single conflict.
class ConflictResolutionResult {
  final List<SyncConflict> conflicts;
  final Map<String, ConflictResolution> resolutions;

  ConflictResolutionResult({
    required this.conflicts,
    required this.resolutions,
  });
}

/// Internal result for a single conflict resolution from the card.
class _ConflictResolutionResult {
  final SyncConflict conflict;
  final ConflictResolution resolution;

  _ConflictResolutionResult({
    required this.conflict,
    required this.resolution,
  });
}

/// Provider holding pending sync conflicts awaiting user resolution.
final pendingConflictsProvider = StateProvider<List<SyncConflict>>((ref) => []);
