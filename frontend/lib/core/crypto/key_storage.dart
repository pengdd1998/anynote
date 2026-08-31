import 'dart:convert';
import '../storage/app_secure_storage.dart';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
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
  static const _keyMasterKey = 'anynote_master_key';
  static const _keyEncryptKey = 'anynote_encrypt_key';
  static const _keySalt = 'anynote_salt';
  static const _keyRecoveryKey = 'anynote_recovery_key_encrypted';
  static const _keyKdfVersion = 'anynote_kdf_version';

  // Legacy keys used before namespace consolidation.
  static const _legacyMasterKey = 'master_key';
  static const _legacyEncryptKey = 'encrypt_key';
  static const _legacySalt = 'argon2_salt';
  static const _legacyRecoveryKey = 'recovery_key_encrypted';
  static const _legacyKdfVersion = 'kdf_version';

  static bool _migrated = false;

  static const _secureStorage = AppSecureStorage.instance;

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
    await _ensureMigrated();
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
    await _ensureMigrated();
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
    await _ensureMigrated();
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
    await _ensureMigrated();
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
    await _ensureMigrated();
    final value = await _read(_keyMasterKey);
    return value != null;
  }

  // ── Internal helpers ───────────────────────────────────────────────

  /// One-time migration from legacy key names to the unified `anynote_` namespace.
  /// Also converts hex-encoded values (old KeyStorage format) to base64 to match
  /// MasterKeyManager's encoding.
  static Future<void> _ensureMigrated() async {
    if (_migrated) return;
    _migrated = true;

    // Migration 1: Rename legacy keys to new namespace, converting hex→base64.
    final legacyPairs = <(String, String)>[
      (_legacyMasterKey, _keyMasterKey),
      (_legacyEncryptKey, _keyEncryptKey),
      (_legacySalt, _keySalt),
      (_legacyRecoveryKey, _keyRecoveryKey),
      (_legacyKdfVersion, _keyKdfVersion),
    ];

    for (final (oldKey, newKey) in legacyPairs) {
      final value = await _read(oldKey);
      if (value != null) {
        final migrated = _tryConvertHexToBase64(value);
        await _write(newKey, migrated);
        await _delete(oldKey);
      }
    }

    // Migration 2: Convert any existing base64-keyed values that are still hex.
    for (final key in [_keyMasterKey, _keyEncryptKey, _keySalt]) {
      final value = await _read(key);
      if (value != null) {
        final converted = _tryConvertHexToBase64(value);
        if (converted != value) {
          await _write(key, converted);
        }
      }
    }
  }

  /// If [value] looks like hex-encoded bytes (all chars in [0-9a-f]), decode
  /// and re-encode as base64. Otherwise returns [value] unchanged.
  static String _tryConvertHexToBase64(String value) {
    if (value.isEmpty) return value;
    // Quick check: if it's valid base64 and not valid hex, leave it.
    // Hex strings are all lowercase hex chars with even length.
    if (value.length % 2 != 0) return value;
    final hexPattern = RegExp(r'^[0-9a-f]+$');
    if (!hexPattern.hasMatch(value)) return value;
    // It's hex — decode and re-encode as base64.
    try {
      final bytes = _decodeHex(value);
      return base64Encode(bytes);
    } catch (_) {
      return value;
    }
  }

  /// Write a value to the appropriate storage backend.
  static Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      await _secureStorage.write(key: key, value: value);
    }
  }

  /// Delete a value from the appropriate storage backend.
  static Future<void> _delete(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } else {
      await _secureStorage.delete(key: key);
    }
  }

  /// Read a value from the appropriate storage backend.
  static Future<String?> _read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } else {
      return _secureStorage.read(key: key);
    }
  }

  static String _encode(Uint8List data) => base64Encode(data);

  static Uint8List _decode(String encoded) => base64Decode(encoded);

  static Uint8List _decodeHex(String hex) {
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }
}
