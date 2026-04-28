import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Unified implementation for key derivation, hashing, and recovery.
// Uses sodium_libs (Argon2id, BLAKE2b) on all platforms.
// sodium_libs provides JS/WASM backend (libsodium.js) for web browsers.
import 'master_key_native_compat.dart';

import 'bip39_wordlist.dart';

/// Current KDF version (Argon2id with OWASP-aligned parameters).
const int _currentKdfVersion = 2;

/// Master key management for E2E encryption.
///
/// Key hierarchy (unified across all platforms via sodium_libs):
///   User Password
///       |
///       v
///   Argon2id(password, salt) -> Master Key
///       |
///       +---> BLAKE2b(master_key, "anynote-auth-key")    -> Auth Key
///       |
///       +---> BLAKE2b(master_key, "anynote-encrypt-key") -> Encrypt Key
///                 |
///                 +---> BLAKE2b(encrypt_key, item_id) -> Per-Item Key
///
/// All platforms (Android, iOS, macOS, Windows, Linux, Web) use the same
/// algorithms: Argon2id for password hashing, BLAKE2b for key derivation,
/// XChaCha20-Poly1305 for AEAD encryption. This ensures cross-platform
/// crypto compatibility -- data encrypted on any platform can be decrypted
/// on any other platform.
///
/// **Legacy note**: Prior to Phase 142, web used PBKDF2 + HMAC-SHA256 +
/// AES-256-GCM which was incompatible with native. Data encrypted with the
/// old web format cannot be decrypted with the current unified backend.
class MasterKeyManager {
  static const _masterKeyKey = 'anynote_master_key';
  static const _saltKey = 'anynote_salt';
  static const _kdfVersionKey = 'anynote_kdf_version';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Generate a new 32-byte salt for key derivation.
  static Uint8List generateSalt() {
    // Delegates to platform-specific implementation.
    return generateSaltImpl();
  }

  /// Derive master key from password.
  ///
  /// On native: uses Argon2id via sodium_libs (crypto_pwhash).
  /// On web: uses PBKDF2-SHA256 with 600,000 iterations via WebCrypto.
  ///
  /// When [kdfVersion] is provided, uses the KDF parameters for that version.
  /// This is used during migration: existing users whose keys were derived with
  /// an older KDF version can be re-derived with legacy parameters, then
  /// upgraded to the current version.
  static Future<Uint8List> deriveMasterKey(
    String password,
    Uint8List salt, [
    int? kdfVersion,
  ]) {
    return deriveMasterKeyImpl(password, salt, kdfVersion);
  }

  /// Derive Auth Key from master key.
  /// Used for server authentication (hashed before sending).
  static Future<Uint8List> deriveAuthKey(Uint8List masterKey) {
    return deriveAuthKeyImpl(masterKey);
  }

  /// Derive Encrypt Key from master key.
  /// Root key for all data encryption.
  static Future<Uint8List> deriveEncryptKey(Uint8List masterKey) {
    return deriveEncryptKeyImpl(masterKey);
  }

  /// Derive per-item key.
  /// Each note/tag/collection gets its own unique 32-byte key.
  static Future<Uint8List> deriveItemKey(
    Uint8List encryptKey,
    String itemId,
  ) {
    return deriveItemKeyImpl(encryptKey, itemId);
  }

  /// One-way hash of the auth key for sending to the server.
  /// Returns hex-encoded string.
  static Future<String> hashAuthKey(Uint8List authKey) {
    return hashAuthKeyImpl(authKey);
  }

  /// Generate a 12-word recovery key (BIP-39 mnemonic encoding 128-bit entropy).
  /// Used to recover the master key if the password is lost.
  static Future<String> generateRecoveryKey() {
    return generateRecoveryKeyImpl();
  }

  /// Convert a 12-word recovery key back to the 128-bit entropy.
  /// Throws if the checksum is invalid.
  static Future<Uint8List> entropyFromRecoveryKey(String recoveryKey) {
    return entropyFromRecoveryKeyImpl(recoveryKey);
  }

  /// Recover the master key from a BIP-39 mnemonic.
  ///
  /// When [serverSalt] is provided (fetched from the backend recovery-salt
  /// endpoint), it is used directly as the KDF salt, making the derivation
  /// non-deterministic and resistant to precomputation attacks.
  ///
  /// When [serverSalt] is null (legacy accounts that registered before this
  /// field existed), falls back to deriving a deterministic salt from the
  /// entropy itself, preserving backward compatibility.
  static Future<Uint8List> recoverMasterKeyFromMnemonic(
    String mnemonic, [
    Uint8List? serverSalt,
  ]) async {
    final entropy = await entropyFromRecoveryKey(mnemonic);
    final entropyHex =
        entropy.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    // Use server-provided random salt if available, otherwise fall back to
    // the legacy deterministic derivation for backward compatibility.
    final Uint8List recoverySalt;
    if (serverSalt != null && serverSalt.isNotEmpty) {
      recoverySalt = serverSalt;
    } else {
      recoverySalt = await hashForRecoverySaltImpl(entropy);
    }
    return deriveMasterKey(entropyHex, recoverySalt);
  }

  /// Store master key securely.
  static Future<void> storeMasterKey(Uint8List masterKey) async {
    final encoded = base64Encode(masterKey);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_masterKeyKey, encoded);
    } else {
      await _secureStorage.write(key: _masterKeyKey, value: encoded);
    }
  }

  /// Retrieve stored master key.
  static Future<Uint8List?> getStoredMasterKey() async {
    String? encoded;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      encoded = prefs.getString(_masterKeyKey);
    } else {
      encoded = await _secureStorage.read(key: _masterKeyKey);
    }
    if (encoded == null) return null;
    return base64Decode(encoded);
  }

  /// Store salt (needed for re-derivation on login).
  static Future<void> storeSalt(Uint8List salt) async {
    final encoded = base64Encode(salt);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_saltKey, encoded);
    } else {
      await _secureStorage.write(key: _saltKey, value: encoded);
    }
  }

  /// Retrieve stored salt.
  static Future<Uint8List?> getStoredSalt() async {
    String? encoded;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      encoded = prefs.getString(_saltKey);
    } else {
      encoded = await _secureStorage.read(key: _saltKey);
    }
    if (encoded == null) return null;
    return base64Decode(encoded);
  }

  /// Clear all stored keys (logout / account deletion).
  static Future<void> clearAll() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_masterKeyKey);
      await prefs.remove(_saltKey);
      await prefs.remove(_kdfVersionKey);
    } else {
      await _secureStorage.delete(key: _masterKeyKey);
      await _secureStorage.delete(key: _saltKey);
      await _secureStorage.delete(key: _kdfVersionKey);
    }
  }

  /// Store the KDF version used to derive the current master key.
  ///
  /// This enables future parameter migrations: when the KDF parameters are
  /// upgraded, the app can detect that a user's key was derived with an older
  /// version and perform a one-time migration at login.
  static Future<void> storeKdfVersion(int version) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kdfVersionKey, version);
    } else {
      await _secureStorage.write(
        key: _kdfVersionKey,
        value: version.toString(),
      );
    }
  }

  /// Retrieve the stored KDF version.
  ///
  /// Returns null if no version has been stored (pre-migration users).
  /// Version 2 is the current default (OWASP-aligned Argon2id parameters).
  static Future<int?> getStoredKdfVersion() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_kdfVersionKey);
    } else {
      final value = await _secureStorage.read(key: _kdfVersionKey);
      if (value == null) return null;
      return int.tryParse(value);
    }
  }

  /// Get the current KDF version for the active platform.
  static int get currentKdfVersion => _currentKdfVersion;

  /// Check if a stored KDF version needs migration to the current version.
  ///
  /// Returns true if:
  /// - No KDF version is stored (pre-migration user), or
  /// - The stored version is less than the current version.
  static Future<bool> needsKdfMigration() async {
    final stored = await getStoredKdfVersion();
    if (stored == null) return true; // Pre-migration user.
    return stored < _currentKdfVersion;
  }

  // ── Shared helpers ─────────────────────────────────────────────────

  /// Encode 132 bits (17 bytes) as 12 BIP-39 words.
  static String encodeMnemonic(Uint8List combined) {
    final words = <String>[];
    int bitIndex = 0;
    for (int i = 0; i < 12; i++) {
      int index = 0;
      for (int j = 0; j < 11; j++) {
        final byteIdx = (bitIndex + j) ~/ 8;
        final bitIdx = 7 - ((bitIndex + j) % 8);
        final bit = (combined[byteIdx] >> bitIdx) & 1;
        index = (index << 1) | bit;
      }
      words.add(bip39Wordlist[index]);
      bitIndex += 11;
    }
    return words.join(' ');
  }

  /// Extract indices from a 12-word mnemonic.
  static List<int> mnemonicToIndices(String recoveryKey) {
    final words = recoveryKey.split(' ');
    if (words.length != 12) {
      throw ArgumentError(
        'Recovery key must have 12 words, got ${words.length}',
      );
    }
    return words.map((w) {
      final idx = bip39Wordlist.indexOf(w.toLowerCase().trim());
      if (idx < 0) {
        throw ArgumentError('Unknown word in recovery key: "$w"');
      }
      return idx;
    }).toList();
  }

  /// Reconstruct 132-bit combined array from 11-bit indices.
  static Uint8List indicesToBits(List<int> indices) {
    final bits = Uint8List(17);
    int bitIndex = 0;
    for (final index in indices) {
      for (int j = 10; j >= 0; j--) {
        final bit = (index >> j) & 1;
        final byteIdx = bitIndex ~/ 8;
        final bitIdx = 7 - (bitIndex % 8);
        bits[byteIdx] |= (bit << bitIdx);
        bitIndex++;
      }
    }
    return bits;
  }
}
