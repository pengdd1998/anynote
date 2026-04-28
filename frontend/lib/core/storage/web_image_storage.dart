import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Image storage backend for the web platform.
///
/// On web there is no native filesystem, so images are persisted as base64
/// strings in SharedPreferences. A total storage budget of 5 MB is enforced;
/// attempting to exceed it throws a [StateError].
///
/// Keys follow the format `web_image_{noteId}_{hash}` so that images can be
/// looked up by note or enumerated for storage-usage reporting.
class WebImageStorage {
  /// Maximum total bytes allowed across all stored web images (5 MB).
  static const int maxTotalBytes = 5 * 1024 * 1024;

  /// Key prefix used for all SharedPreferences entries.
  static const _keyPrefix = 'web_image_';

  /// Registry key that tracks all image keys and their sizes (JSON map).
  static const _registryKey = 'web_image_registry';

  /// Save image bytes for a note, returning a synthetic path/key.
  ///
  /// The returned key can be passed to [loadWebImage] to retrieve the bytes.
  /// Throws [StateError] if storing the image would exceed [maxTotalBytes].
  static Future<String> saveWebImage(Uint8List bytes, String noteId) async {
    final prefs = await SharedPreferences.getInstance();
    final hash = md5.convert(bytes).toString().substring(0, 12);
    final key = '$_keyPrefix${noteId}_$hash';
    final base64Data = base64Encode(bytes);

    // Load registry and check storage budget
    final registry = await _loadRegistry(prefs);
    final currentUsage = registry.values.fold<int>(0, (sum, s) => sum + s);

    // If the key already exists, subtract its old size from the budget check
    final existingSize = registry[key] ?? 0;
    final newTotal = currentUsage - existingSize + bytes.length;

    if (newTotal > maxTotalBytes) {
      throw StateError(
        'Web image storage limit exceeded: '
        '$newTotal bytes > $maxTotalBytes bytes',
      );
    }

    // Store the image data
    await prefs.setString(key, base64Data);

    // Update registry
    registry[key] = bytes.length;
    await _saveRegistry(prefs, registry);

    return key;
  }

  /// Load image bytes from the given key returned by [saveWebImage].
  ///
  /// Returns null if the key does not exist or the data is corrupt.
  static Future<Uint8List?> loadWebImage(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final base64Data = prefs.getString(key);
    if (base64Data == null) return null;

    try {
      return Uint8List.fromList(base64Decode(base64Data));
    } catch (e) {
      // Corrupt data -- clean up
      await prefs.remove(key);
      return null;
    }
  }

  /// Delete a single web image by key.
  ///
  /// Returns true if the image existed and was deleted, false otherwise.
  static Future<bool> deleteWebImage(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final existed = prefs.containsKey(key);
    if (!existed) return false;

    await prefs.remove(key);

    // Remove from registry
    final registry = await _loadRegistry(prefs);
    registry.remove(key);
    await _saveRegistry(prefs, registry);

    return true;
  }

  /// Delete all web images associated with a given note ID prefix.
  ///
  /// Returns the number of images deleted.
  static Future<int> deleteWebImagesForNote(String noteId) async {
    final prefs = await SharedPreferences.getInstance();
    final registry = await _loadRegistry(prefs);
    final prefix = '$_keyPrefix${noteId}_';

    int count = 0;
    final keysToRemove =
        registry.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in keysToRemove) {
      await prefs.remove(key);
      registry.remove(key);
      count++;
    }

    await _saveRegistry(prefs, registry);
    return count;
  }

  /// Get the total storage usage in bytes across all stored web images.
  static Future<int> getStorageUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final registry = await _loadRegistry(prefs);
    return registry.values.fold<int>(0, (sum, s) => sum + s);
  }

  /// Get the number of stored web images.
  static Future<int> getImageCount() async {
    final prefs = await SharedPreferences.getInstance();
    final registry = await _loadRegistry(prefs);
    return registry.length;
  }

  /// Delete all stored web images and clear the registry.
  static Future<void> deleteAll() async {
    final prefs = await SharedPreferences.getInstance();
    final registry = await _loadRegistry(prefs);

    for (final key in registry.keys) {
      await prefs.remove(key);
    }
    await prefs.remove(_registryKey);
  }

  // ── Registry helpers ──────────────────────────────────────

  /// Load the image registry from SharedPreferences.
  /// Returns a map of key -> size in bytes.
  static Future<Map<String, int>> _loadRegistry(SharedPreferences prefs) async {
    final json = prefs.getString(_registryKey);
    if (json == null) return {};
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as int));
    } catch (e) {
      // Corrupt registry -- start fresh
      return {};
    }
  }

  /// Save the image registry to SharedPreferences.
  static Future<void> _saveRegistry(
    SharedPreferences prefs,
    Map<String, int> registry,
  ) async {
    await prefs.setString(_registryKey, jsonEncode(registry));
  }
}
