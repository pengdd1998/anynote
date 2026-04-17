import 'dart:typed_data';

/// Version vector for sync conflict resolution.
///
/// Each device maintains a version counter per item type.
/// When syncing, the server assigns a global monotonically increasing version.
/// Conflicts are resolved using Last-Write-Wins (LWW) based on timestamps.
class VersionVector {
  /// Map of item_id → version number
  final Map<String, int> _versions = {};

  /// Get the version for an item.
  int get(String itemId) => _versions[itemId] ?? 0;

  /// Set the version for an item (only if higher than current).
  void set(String itemId, int version) {
    final current = _versions[itemId] ?? 0;
    if (version > current) {
      _versions[itemId] = version;
    }
  }

  /// Increment version for an item and return new version.
  int increment(String itemId) {
    final newVersion = (_versions[itemId] ?? 0) + 1;
    _versions[itemId] = newVersion;
    return newVersion;
  }

  /// Get the maximum version across all items.
  int get maxVersion {
    if (_versions.isEmpty) return 0;
    return _versions.values.reduce((a, b) => a > b ? a : b);
  }

  /// Merge with another version vector (take max for each item).
  void merge(VersionVector other) {
    for (final entry in other._versions.entries) {
      set(entry.key, entry.value);
    }
  }

  /// Get all item IDs that are newer than the given version vector.
  List<String> getNewerItemIds(VersionVector other) {
    final result = <String>[];
    for (final entry in _versions.entries) {
      if (entry.value > other.get(entry.key)) {
        result.add(entry.key);
      }
    }
    return result;
  }

  /// Serialize to JSON-compatible map.
  Map<String, dynamic> toJson() => {'versions': Map<String, int>.from(_versions)};

  /// Deserialize from JSON map.
  factory VersionVector.fromJson(Map<String, dynamic> json) {
    final vv = VersionVector();
    final versions = json['versions'] as Map<String, dynamic>?;
    if (versions != null) {
      for (final entry in versions.entries) {
        vv._versions[entry.key] = entry.value as int;
      }
    }
    return vv;
  }
}
