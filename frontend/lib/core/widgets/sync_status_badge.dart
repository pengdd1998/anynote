import 'package:flutter/material.dart';

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

  const SyncStatusBadge({
    super.key,
    required this.isSynced,
    this.hasConflict = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final props = _statusProperties();

    return Tooltip(
      message: props.tooltip,
      child: Semantics(
        label: semanticLabel ?? props.tooltip,
        child: Icon(props.icon, size: 16, color: props.color),
      ),
    );
  }

  ({IconData icon, Color color, String tooltip}) _statusProperties() {
    if (hasConflict) {
      return (
        icon: Icons.cloud_off,
        color: Colors.red,
        tooltip: 'Sync conflict',
      );
    }
    if (isSynced) {
      return (
        icon: Icons.cloud_done,
        color: Colors.green,
        tooltip: 'Synced',
      );
    }
    return (
      icon: Icons.cloud_upload,
      color: Colors.orange,
      tooltip: 'Pending sync',
    );
  }
}
