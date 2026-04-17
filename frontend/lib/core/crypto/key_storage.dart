import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage interface for cryptographic keys.
/// Uses platform-specific secure storage (Keychain on iOS, Keystore on Android).
class KeyStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _keyMasterKey = 'master_key';
  static const _keyEncryptKey = 'encrypt_key';
  static const _keySalt = 'argon2_salt';
  static const _keyRecoveryKey = 'recovery_key_encrypted';

  /// Store the master key.
  static Future<void> saveMasterKey(Uint8List key) async {
    await _storage.write(key: _keyMasterKey, value: _encode(key));
  }

  /// Retrieve the master key. Returns null if not stored.
  static Future<Uint8List?> loadMasterKey() async {
    final value = await _storage.read(key: _keyMasterKey);
    return value != null ? _decode(value) : null;
  }

  /// Store the encryption key.
  static Future<void> saveEncryptKey(Uint8List key) async {
    await _storage.write(key: _keyEncryptKey, value: _encode(key));
  }

  /// Retrieve the encryption key.
  static Future<Uint8List?> loadEncryptKey() async {
    final value = await _storage.read(key: _keyEncryptKey);
    return value != null ? _decode(value) : null;
  }

  /// Store the Argon2id salt.
  static Future<void> saveSalt(Uint8List salt) async {
    await _storage.write(key: _keySalt, value: _encode(salt));
  }

  /// Retrieve the salt.
  static Future<Uint8List?> loadSalt() async {
    final value = await _storage.read(key: _keySalt);
    return value != null ? _decode(value) : null;
  }

  /// Store encrypted recovery key.
  static Future<void> saveRecoveryKey(String encryptedRecoveryKey) async {
    await _storage.write(key: _keyRecoveryKey, value: encryptedRecoveryKey);
  }

  /// Retrieve encrypted recovery key.
  static Future<String?> loadRecoveryKey() async {
    return await _storage.read(key: _keyRecoveryKey);
  }

  /// Clear all stored keys (logout).
  static Future<void> clearAll() async {
    await _storage.delete(key: _keyMasterKey);
    await _storage.delete(key: _keyEncryptKey);
    await _storage.delete(key: _keySalt);
    await _storage.delete(key: _keyRecoveryKey);
  }

  /// Check if keys are initialized (user has set up encryption).
  static Future<bool> isInitialized() async {
    final masterKey = await _storage.read(key: _keyMasterKey);
    return masterKey != null;
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
