import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure storage interface for cryptographic keys.
///
/// On native platforms (iOS, Android, macOS, Windows, Linux): uses
/// FlutterSecureStorage, which delegates to platform-specific hardware-backed
/// keystores:
///   - iOS: Keychain Services (Secure Enclave when available)
///   - Android: EncryptedSharedPreferences (backed by Android Keystore)
///   - macOS: Keychain Services
///   - Windows/Windows: libsecret / DPAPI respectively
///
/// On web: uses SharedPreferences with base64-encoded hex values stored in
/// the browser's localStorage. **This is significantly less secure than native
/// storage** because:
///   1. localStorage is accessible to any JavaScript running in the same
///      origin, meaning a successful XSS attack can exfiltrate all stored
///      keys including the master key.
///   2. The master key stored in localStorage is the single point of failure
///      on web -- any script with access to it can decrypt all user data.
///   3. Browser storage is subject to eviction under storage pressure and is
///      not encrypted at rest by the browser itself.
///
/// **Recommendation**: Users with high security requirements (e.g. storing
/// sensitive personal data, financial notes, medical information) should use
/// the native AnyNote app on iOS or Android rather than the web version.
/// The E2E encryption of synced content mitigates server-side risks, but the
/// local key storage boundary on web is fundamentally weaker.
class KeyStorage {
  static const _keyMasterKey = 'master_key';
  static const _keyEncryptKey = 'encrypt_key';
  static const _keySalt = 'argon2_salt';
  static const _keyRecoveryKey = 'recovery_key_encrypted';
  static const _keyKdfVersion = 'kdf_version';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Store the master key.
  static Future<void> saveMasterKey(Uint8List key) async {
    final encoded = _encode(key);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyMasterKey, encoded);
    } else {
      await _secureStorage.write(key: _keyMasterKey, value: encoded);
    }
  }

  /// Retrieve the master key. Returns null if not stored.
  static Future<Uint8List?> loadMasterKey() async {
    final value = await _read(_keyMasterKey);
    return value != null ? _decode(value) : null;
  }

  /// Store the encryption key.
  static Future<void> saveEncryptKey(Uint8List key) async {
    final encoded = _encode(key);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEncryptKey, encoded);
    } else {
      await _secureStorage.write(key: _keyEncryptKey, value: encoded);
    }
  }

  /// Retrieve the encryption key.
  static Future<Uint8List?> loadEncryptKey() async {
    final value = await _read(_keyEncryptKey);
    return value != null ? _decode(value) : null;
  }

  /// Store the salt.
  static Future<void> saveSalt(Uint8List salt) async {
    final encoded = _encode(salt);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySalt, encoded);
    } else {
      await _secureStorage.write(key: _keySalt, value: encoded);
    }
  }

  /// Retrieve the salt.
  static Future<Uint8List?> loadSalt() async {
    final value = await _read(_keySalt);
    return value != null ? _decode(value) : null;
  }

  /// Store encrypted recovery key.
  static Future<void> saveRecoveryKey(String encryptedRecoveryKey) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRecoveryKey, encryptedRecoveryKey);
    } else {
      await _secureStorage.write(
        key: _keyRecoveryKey,
        value: encryptedRecoveryKey,
      );
    }
  }

  /// Retrieve encrypted recovery key.
  static Future<String?> loadRecoveryKey() async {
    return _read(_keyRecoveryKey);
  }

  /// Clear all stored keys (logout).
  static Future<void> clearAll() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyMasterKey);
      await prefs.remove(_keyEncryptKey);
      await prefs.remove(_keySalt);
      await prefs.remove(_keyRecoveryKey);
      await prefs.remove(_keyKdfVersion);
    } else {
      await _secureStorage.delete(key: _keyMasterKey);
      await _secureStorage.delete(key: _keyEncryptKey);
      await _secureStorage.delete(key: _keySalt);
      await _secureStorage.delete(key: _keyRecoveryKey);
      await _secureStorage.delete(key: _keyKdfVersion);
    }
  }

  /// Check if keys are initialized (user has set up encryption).
  static Future<bool> isInitialized() async {
    final value = await _read(_keyMasterKey);
    return value != null;
  }

  // ── Internal helpers ───────────────────────────────────────────────

  /// Read a value from the appropriate storage backend.
  static Future<String?> _read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } else {
      return _secureStorage.read(key: key);
    }
  }

  static String _encode(Uint8List data) {
    return data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List _decode(String hex) {
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }
}
