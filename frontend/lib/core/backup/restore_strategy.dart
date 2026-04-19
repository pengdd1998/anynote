/// Strategy for handling conflicts when a backup item matches an existing
/// local item by UUID.
enum ConflictStrategy {
  /// Keep the local version, ignore the backup version for this item.
  skip,

  /// Replace the local version with the backup version.
  overwrite,

  /// Keep both: the backup item is imported with a new UUID and "(restored)"
  /// suffix appended to the title.
  keepBoth,
}

/// Summary of a restore operation.
class RestoreResult {
  /// Number of items successfully restored.
  final int restored;

  /// Number of items skipped (duplicate found, strategy = skip).
  final int skipped;

  /// Number of conflicts detected (items that existed locally with same UUID).
  final int conflicts;

  /// Errors encountered during restore (per-item failures).
  final List<String> errors;

  const RestoreResult({
    this.restored = 0,
    this.skipped = 0,
    this.conflicts = 0,
    this.errors = const [],
  });

  /// Total items processed.
  int get total => restored + skipped + conflicts;

  /// Whether the restore had any errors.
  bool get hasErrors => errors.isNotEmpty;

  @override
  String toString() =>
      'RestoreResult(restored: $restored, skipped: $skipped, '
      'conflicts: $conflicts, errors: ${errors.length})';
}

/// Progress callback data during a restore operation.
class RestoreProgress {
  /// Current item index being processed.
  final int current;

  /// Total number of items to process.
  final int total;

  /// Human-readable description of the current step.
  final String step;

  const RestoreProgress({
    required this.current,
    required this.total,
    required this.step,
  });

  /// Progress as a value between 0.0 and 1.0.
  double get fraction => total > 0 ? current / total : 0.0;
}
