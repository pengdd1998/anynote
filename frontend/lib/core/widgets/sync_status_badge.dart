import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// Visual indicator for the sync status of a single item (note, tag, etc.).
///
/// States:
/// - **synced** -- green cloud_done icon
/// - **pending** -- orange cloud_upload icon (unsynced local change)
/// - **conflict** -- red cloud_off icon (sync conflict detected)
class SyncStatusBadge extends StatelessWidget {
  /// Whether the item has been successfully synced to the server.
  final bool isSynced;

  /// Whether a sync conflict has been detected for this item.
  final bool hasConflict;

  /// Optional semantic label for accessibility.
  final String? semanticLabel;

  /// Icon size in logical pixels. Defaults to 16.
  final double iconSize;

  const SyncStatusBadge({
    super.key,
    required this.isSynced,
    this.hasConflict = false,
    this.semanticLabel,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final props = _statusProperties(context);

    return Tooltip(
      message: props.tooltip,
      child: Semantics(
        label: semanticLabel ?? props.tooltip,
        child: Icon(props.icon, size: iconSize, color: props.color),
      ),
    );
  }

  ({IconData icon, Color color, String tooltip}) _statusProperties(
    BuildContext context,
  ) {
    // Status ink: the fill colours were 2.0–2.5:1 on paper.
    final brightness = Theme.of(context).brightness;
    if (hasConflict) {
      return (
        icon: AppIcons.cloudOff,
        color: AppColors.statusErrorOf(brightness),
        tooltip: 'Sync conflict',
      );
    }
    if (isSynced) {
      return (
        icon: AppIcons.cloudDone,
        color: AppColors.statusSuccessOf(brightness),
        tooltip: 'Synced',
      );
    }
    return (
      icon: AppIcons.cloudUpload,
      color: AppColors.statusWarningOf(brightness),
      tooltip: 'Pending sync',
    );
  }
}
