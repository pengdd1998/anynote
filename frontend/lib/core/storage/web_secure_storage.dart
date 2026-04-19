import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Web-compatible secure storage fallback.
///
/// On native platforms, `flutter_secure_storage` uses the platform keychain
/// (iOS Keychain / Android Keystore) for truly secure storage.
///
/// On web, `flutter_secure_storage` falls back to `SharedPreferences` with
/// base64-encoded values stored in `localStorage`. This is NOT cryptographically
/// secure -- the browser's localStorage is accessible to any JavaScript running
/// in the same origin. This is a known limitation.
///
/// For production web use, consider:
/// 1. Using IndexedDB with a user-derived encryption key
/// 2. Using the Web Cryptography API to encrypt values before storage
/// 3. Keeping sensitive keys only in memory (with a re-authentication flow)
///
/// This class provides a unified interface that abstracts over the platform
/// difference, with the security tradeoff clearly documented.
class WebSecureStorage {
  static const _prefix = 'anynote_secure_';

  /// Read a value from secure storage.
  ///
  /// On native: uses FlutterSecureStorage (Keychain/Keystore).
  /// On web: uses SharedPreferences (localStorage), which is NOT secure.
  static Future<String?> read(String key) async {
    if (kIsWeb) {
      return _readWeb(key);
    }
    return _readNative(key);
  }

  /// Write a value to secure storage.
  ///
  /// On native: uses FlutterSecureStorage (Keychain/Keystore).
  /// On web: uses SharedPreferences (localStorage), which is NOT secure.
  static Future<void> write(String key, String value) async {
    if (kIsWeb) {
      return _writeWeb(key, value);
    }
    return _writeNative(key, value);
  }

  /// Delete a value from secure storage.
  static Future<void> delete(String key) async {
    if (kIsWeb) {
      return _deleteWeb(key);
    }
    return _deleteNative(key);
  }

  /// Check if a key exists in secure storage.
  static Future<bool> containsKey(String key) async {
    if (kIsWeb) {
      return _containsKeyWeb(key);
    }
    return _containsKeyNative(key);
  }

  // --- Native implementation (flutter_secure_storage) ---

  static const _nativeStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<String?> _readNative(String key) async {
    return _nativeStorage.read(key: key);
  }

  static Future<void> _writeNative(String key, String value) async {
    await _nativeStorage.write(key: key, value: value);
  }

  static Future<void> _deleteNative(String key) async {
    await _nativeStorage.delete(key: key);
  }

  static Future<bool> _containsKeyNative(String key) async {
    return _nativeStorage.containsKey(key: key);
  }

  // --- Web implementation (SharedPreferences / localStorage) ---

  static Future<String?> _readWeb(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix$key');
  }

  static Future<void> _writeWeb(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$key', value);
  }

  static Future<void> _deleteWeb(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
  }

  static Future<bool> _containsKeyWeb(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('$_prefix$key');
  }
}
