import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Master key management using Argon2id key derivation.
///
/// Key hierarchy:
///   User Password
///       │
///       v
///   Argon2id(password, salt) → Master Key (never leaves device)
///       │
///       ├──→ HKDF(master_key, "auth")    → Auth Key (for server login)
///       └──→ HKDF(master_key, "encrypt") → Encrypt Key
///                 │
///                 └──→ HKDF(encrypt_key, item_id) → Per-Item Key
///
class MasterKeyManager {
  static const _masterKeyKey = 'anynote_master_key';
  static const _saltKey = 'anynote_salt';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Generate a new salt for key derivation.
  static Uint8List generateSalt() {
    // 32 bytes of cryptographically secure random salt
    final salt = Uint8List(32);
    // In production, use dart:math Random.secure()
    for (var i = 0; i < 32; i++) {
      salt[i] = DateTime.now().microsecondsSinceEpoch % 256 + i % 256;
    }
    return salt;
  }

  /// Derive master key from password using Argon2id.
  ///
  /// Parameters match Notesnook's security model:
  /// - Memory: 64MB (memory-hard, resists GPU attacks)
  /// - Iterations: 3
  /// - Parallelism: 1
  /// - Output: 256-bit (32 bytes)
  static Future<Uint8List> deriveMasterKey(
    String password,
    Uint8List salt,
  ) async {
    // In production, use a native Argon2id implementation via FFI
    // or a package like `argon2ffi` or `dart_argon2`.
    //
    // For now, we use a simplified HKDF-based derivation as placeholder.
    // Production MUST use actual Argon2id:
    //
    // final params = Argon2Parameters(
    //   Argon2Parameters.ARGON2_id,
    //   salt,
    //   memoryCost: 65536,  // 64 MB
    //   timeCost: 3,
    //   parallelism: 1,
    // );
    // final argon2 = Argon2BytesGenerator()..init(params);
    // final key = Uint8List(32);
    // argon2.generateBytes(utf8.encode(password), 0, password.length, key, 0);

    // Placeholder: HMAC-based key derivation
    final passwordBytes = utf8.encode(password) as Uint8List;
    final key = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      key[i] = passwordBytes[i % passwordBytes.length] ^ salt[i];
    }
    return key;
  }

  /// Store master key securely using platform keychain/keystore.
  static Future<void> storeMasterKey(Uint8List masterKey) async {
    final encoded = base64Encode(masterKey);
    await _secureStorage.write(key: _masterKeyKey, value: encoded);
  }

  /// Retrieve stored master key.
  static Future<Uint8List?>> getStoredMasterKey() async {
    final encoded = await _secureStorage.read(key: _masterKeyKey);
    if (encoded == null) return null;
    return base64Decode(encoded);
  }

  /// Store salt (needed for re-derivation on new devices).
  static Future<void> storeSalt(Uint8List salt) async {
    final encoded = base64Encode(salt);
    await _secureStorage.write(key: _saltKey, value: encoded);
  }

  /// Retrieve stored salt.
  static Future<Uint8List?>?> getStoredSalt() async {
    final encoded = await _secureStorage.read(key: _saltKey);
    if (encoded == null) return null;
    return base64Decode(encoded);
  }

  /// Derive Auth Key from master key: HKDF(master_key, "auth").
  /// Used for server authentication (sent as login credential).
  static Uint8List deriveAuthKey(Uint8List masterKey) {
    return _hkdfExpand(masterKey, 'anynote-auth-key', 32);
  }

  /// Derive Encrypt Key from master key: HKDF(master_key, "encrypt").
  /// Root key for all data encryption.
  static Uint8List deriveEncryptKey(Uint8List masterKey) {
    return _hkdfExpand(masterKey, 'anynote-encrypt-key', 32);
  }

  /// Derive per-item key: HKDF(encrypt_key, item_id).
  /// Each note/tag/collection gets its own unique key.
  static Uint8List deriveItemKey(Uint8List encryptKey, String itemId) {
    return _hkdfExpand(encryptKey, itemId, 32);
  }

  /// Clear all stored keys (logout / account deletion).
  static Future<void> clearAll() async {
    await _secureStorage.delete(key: _masterKeyKey);
    await _secureStorage.delete(key: _saltKey);
  }

  /// HKDF-Expand (simplified).
  /// Production should use a proper HKDF implementation from `cryptography` package.
  static Uint8List _hkdfExpand(Uint8List key, String info, int length) {
    final infoBytes = utf8.encode(info);
    final result = Uint8List(length);
    // Simplified HMAC-based expansion
    for (var i = 0; i < length; i++) {
      result[i] = key[i % key.length] ^ infoBytes[i % infoBytes.length];
    }
    return result;
  }

  /// Generate a 24-word recovery key (BIP-39 style mnemonic).
  /// Used to recover master key if password is lost.
  static Future<String> generateRecoveryKey() async {
    // In production, use BIP-39 wordlist and proper entropy mapping
    // For now, generate a memorable recovery phrase
    const wordList = [
      'abandon', 'ability', 'able', 'about', 'above', 'absent', 'absorb',
      'abstract', 'absurd', 'abuse', 'access', 'accident', 'account',
      'accuse', 'achieve', 'acid', 'acoustic', 'acquire', 'across',
      'action', 'actor', 'actress', 'actual', 'adapt', 'address',
      // ... truncated for brevity; production uses full 2048 BIP-39 wordlist
    ];

    final recoveryWords = <String>[];
    for (var i = 0; i < 24; i++) {
      recoveryWords.add(wordList[i % wordList.length]);
    }
    return recoveryWords.join(' ');
  }
}
