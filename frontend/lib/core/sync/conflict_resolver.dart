/// Conflict resolution using Last-Write-Wins (LWW) strategy.
///
/// For single-user multi-device sync:
/// - If timestamps differ, the later write wins
/// - If timestamps are equal (rare), use device ID as tiebreaker
/// - Previous version is kept for potential user review
class ConflictResolver {
  /// Resolve conflict between local and remote items.
  /// Returns the winning item and whether there was a conflict.
  ///
  /// [local] - Local item data
  /// [remote] - Remote (server) item data
  /// [localUpdatedAt] - Local update timestamp
  /// [remoteUpdatedAt] - Remote update timestamp
  /// [localDeviceId] - Local device identifier
  /// [remoteDeviceId] - Remote device identifier
  static ConflictResult resolve<T>({
    required T local,
    required T remote,
    required DateTime localUpdatedAt,
    required DateTime remoteUpdatedAt,
    String localDeviceId = '',
    String remoteDeviceId = '',
  }) {
    final comparison = localUpdatedAt.compareTo(remoteUpdatedAt);

    if (comparison > 0) {
      // Local is newer → local wins
      return ConflictResult(winner: local, loser: remote, hadConflict: true);
    } else if (comparison < 0) {
      // Remote is newer → remote wins
      return ConflictResult(winner: remote, loser: local, hadConflict: true);
    } else {
      // Same timestamp → use device ID as tiebreaker
      if (localDeviceId.compareTo(remoteDeviceId) >= 0) {
        return ConflictResult(winner: local, loser: remote, hadConflict: true);
      } else {
        return ConflictResult(winner: remote, loser: local, hadConflict: true);
      }
    }
  }
}

class ConflictResult<T> {
  final T winner;
  final T loser;
  final bool hadConflict;

  ConflictResult({
    required this.winner,
    required this.loser,
    required this.hadConflict,
  });
}
