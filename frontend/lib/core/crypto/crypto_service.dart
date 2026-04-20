import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'encryptor.dart';
import 'key_storage.dart';
import 'master_key.dart';

/// Centralized crypto service that manages the encrypt key and provides
/// per-item encryption/decryption for the entire app.
///
/// Key hierarchy:
///   MasterKeyManager.deriveEncryptKey(masterKey) -> encryptKey (cached)
///   Encryptor.derivePerItemKey(encryptKey, itemId) -> per-item key
///   Encryptor.encrypt/decrypt(plaintext/ciphertext, perItemKey) -> result
class CryptoService {
  Uint8List? _cachedEncryptKey;

  /// Check whether the user has completed encryption setup (has a stored master key).
  Future<bool> isInitialized() async {
    return KeyStorage.isInitialized();
  }

  /// Initialize encryption for a new user.
  /// Derives the master key from the given password, stores it, and caches
  /// the encrypt key.
  Future<void> initialize(String password) async {
    final salt = MasterKeyManager.generateSalt();
    final masterKey = await MasterKeyManager.deriveMasterKey(password, salt);
    final encryptKey = await MasterKeyManager.deriveEncryptKey(masterKey);

    await KeyStorage.saveSalt(salt);
    await KeyStorage.saveMasterKey(masterKey);
    await KeyStorage.saveEncryptKey(encryptKey);

    _cachedEncryptKey = encryptKey;
  }

  /// Unlock the encrypt key from a stored master key.
  /// Call this after the user authenticates (login or app launch).
  /// Returns true if the key was loaded successfully.
  Future<bool> unlock() async {
    final encryptKey = await KeyStorage.loadEncryptKey();
    if (encryptKey != null) {
      _cachedEncryptKey = encryptKey;
      return true;
    }

    // Fallback: derive from stored master key if encrypt key is missing
    final masterKey = await KeyStorage.loadMasterKey();
    if (masterKey != null) {
      final derived = await MasterKeyManager.deriveEncryptKey(masterKey);
      await KeyStorage.saveEncryptKey(derived);
      _cachedEncryptKey = derived;
      return true;
    }

    return false;
  }

  /// Unlock by re-deriving from password + stored salt.
  /// Used when the master key is not cached (e.g. fresh login).
  ///
  /// Uses the stored KDF version to ensure the correct Argon2id parameters
  /// are used. Users who have not yet been migrated will use legacy params.
  Future<bool> unlockWithPassword(String password) async {
    final salt = await KeyStorage.loadSalt();
    if (salt == null) return false;

    // Use stored KDF version, defaulting to current version for new users.
    final storedVersion = await MasterKeyManager.getStoredKdfVersion();
    final kdfVersion = storedVersion ?? MasterKeyManager.currentKdfVersion;

    final masterKey = await MasterKeyManager.deriveMasterKey(
      password,
      salt,
      kdfVersion,
    );
    final encryptKey = await MasterKeyManager.deriveEncryptKey(masterKey);

    await KeyStorage.saveMasterKey(masterKey);
    await KeyStorage.saveEncryptKey(encryptKey);
    _cachedEncryptKey = encryptKey;
    return true;
  }

  /// Clear cached keys (logout).
  Future<void> lock() async {
    _cachedEncryptKey = null;
  }

  /// Clear all stored keys permanently (account deletion).
  Future<void> clearAll() async {
    _cachedEncryptKey = null;
    await KeyStorage.clearAll();
  }

  /// Whether the encrypt key is currently available in memory.
  bool get isUnlocked => _cachedEncryptKey != null;

  /// Inject an encrypt key for testing purposes.
  /// Do NOT use this in production code.
  @visibleForTesting
  void injectEncryptKey(Uint8List key) {
    _cachedEncryptKey = key;
  }

  /// Get the encrypt key, throwing if not unlocked.
  Uint8List get _encryptKey {
    final key = _cachedEncryptKey;
    if (key == null) {
      throw StateError('CryptoService is not unlocked. Call unlock() first.');
    }
    return key;
  }

  /// Encrypt a plaintext string for a specific item (note, tag, etc.).
  ///
  /// [itemId] - UUID of the item being encrypted.
  /// [plaintext] - The plaintext content to encrypt.
  /// Returns base64-encoded ciphertext.
  Future<String> encryptForItem(String itemId, String plaintext) async {
    final itemKey = await Encryptor.derivePerItemKey(_encryptKey, itemId);
    return Encryptor.encrypt(plaintext, itemKey);
  }

  /// Decrypt ciphertext for a specific item.
  ///
  /// [itemId] - UUID of the item to decrypt.
  /// [encrypted] - Base64-encoded ciphertext.
  /// Returns the decrypted plaintext string, or null if decryption fails.
  Future<String?> decryptForItem(String itemId, String encrypted) async {
    try {
      final itemKey = await Encryptor.derivePerItemKey(_encryptKey, itemId);
      return await Encryptor.decrypt(encrypted, itemKey);
    } catch (_) {
      return null;
    }
  }

  /// Encrypt binary blob data for a specific item (used for sync).
  Future<Uint8List> encryptBlobForItem(String itemId, Uint8List data) async {
    final itemKey = await Encryptor.derivePerItemKey(_encryptKey, itemId);
    return Encryptor.encryptBlob(data, itemKey);
  }

  /// Decrypt binary blob data for a specific item (used for sync).
  Future<Uint8List?> decryptBlobForItem(
    String itemId,
    Uint8List encrypted,
  ) async {
    try {
      final itemKey = await Encryptor.derivePerItemKey(_encryptKey, itemId);
      return await Encryptor.decryptBlob(encrypted, itemKey);
    } catch (_) {
      return null;
    }
  }
}

/// Riverpod provider for the CryptoService singleton.
/// The service is created once and shared across the app.
final cryptoServiceProvider = Provider<CryptoService>((ref) {
  return CryptoService();
});
