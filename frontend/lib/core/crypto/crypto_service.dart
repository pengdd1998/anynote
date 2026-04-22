import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'decryption_exception.dart';
import 'encryptor.dart';
import 'key_storage.dart';
import 'master_key.dart';

/// Maximum number of per-item keys to keep in the LRU cache.
///
/// Each entry holds a 32-byte key plus the UUID string overhead. 256 entries
/// consume roughly 16 KB -- a worthwhile trade-off to avoid repeated KDF
/// operations when the same note is read/written multiple times in a session.
const _maxItemKeyCacheSize = 256;

/// Centralized crypto service that manages the encrypt key and provides
/// per-item encryption/decryption for the entire app.
///
/// Key hierarchy:
///   MasterKeyManager.deriveEncryptKey(masterKey) -> encryptKey (cached)
///   Encryptor.derivePerItemKey(encryptKey, itemId) -> per-item key
///   Encryptor.encrypt/decrypt(plaintext/ciphertext, perItemKey) -> result
///
/// Per-item keys are cached in an LRU map to avoid redundant derivations
/// when the same item is encrypted or decrypted repeatedly (e.g. during
/// auto-save or sync cycles).
class CryptoService {
  Uint8List? _cachedEncryptKey;

  /// LRU cache of per-item derived keys: itemId -> 32-byte key.
  /// Cleared on [lock] and [clearAll].
  final Map<String, Uint8List> _itemKeyCache = {};

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

    _setEncryptKey(encryptKey);
  }

  /// Unlock the encrypt key from a stored master key.
  /// Call this after the user authenticates (login or app launch).
  /// Returns true if the key was loaded successfully.
  Future<bool> unlock() async {
    final encryptKey = await KeyStorage.loadEncryptKey();
    if (encryptKey != null) {
      _setEncryptKey(encryptKey);
      return true;
    }

    // Fallback: derive from stored master key if encrypt key is missing
    final masterKey = await KeyStorage.loadMasterKey();
    if (masterKey != null) {
      final derived = await MasterKeyManager.deriveEncryptKey(masterKey);
      await KeyStorage.saveEncryptKey(derived);
      _setEncryptKey(derived);
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
    _setEncryptKey(encryptKey);
    return true;
  }

  /// Clear cached keys (logout).
  ///
  /// Overwrites the key material in memory before releasing references to
  /// minimize the window in which sensitive data is accessible in RAM.
  Future<void> lock() async {
    _zeroKey(_cachedEncryptKey);
    _cachedEncryptKey = null;
    _clearItemKeyCache();
  }

  /// Clear all stored keys permanently (account deletion).
  Future<void> clearAll() async {
    _zeroKey(_cachedEncryptKey);
    _cachedEncryptKey = null;
    _clearItemKeyCache();
    await KeyStorage.clearAll();
  }

  /// Whether the encrypt key is currently available in memory.
  bool get isUnlocked => _cachedEncryptKey != null;

  /// Inject an encrypt key for testing purposes.
  /// Do NOT use this in production code.
  @visibleForTesting
  void injectEncryptKey(Uint8List key) {
    _setEncryptKey(key);
  }

  /// Expose the current item key cache size for testing.
  @visibleForTesting
  int get itemKeyCacheSize => _itemKeyCache.length;

  /// Get the encrypt key, throwing if not unlocked.
  Uint8List get _encryptKey {
    final key = _cachedEncryptKey;
    if (key == null) {
      throw StateError('CryptoService is not unlocked. Call unlock() first.');
    }
    return key;
  }

  /// Set the cached encrypt key and clear any stale per-item keys from
  /// the previous session.
  void _setEncryptKey(Uint8List key) {
    _zeroKey(_cachedEncryptKey);
    _cachedEncryptKey = key;
    _clearItemKeyCache();
  }

  /// Derive (or retrieve from cache) a per-item key for [itemId].
  Future<Uint8List> _getOrDeriveItemKey(String itemId) async {
    final cached = _itemKeyCache[itemId];
    if (cached != null) {
      // Move to end for LRU ordering (remove and re-insert).
      _itemKeyCache.remove(itemId);
      _itemKeyCache[itemId] = cached;
      return cached;
    }

    final derived = await Encryptor.derivePerItemKey(_encryptKey, itemId);

    // Evict oldest entry if the cache is full.
    if (_itemKeyCache.length >= _maxItemKeyCacheSize) {
      final oldestKey = _itemKeyCache.keys.first;
      final oldestValue = _itemKeyCache.remove(oldestKey);
      _zeroKey(oldestValue);
    }

    _itemKeyCache[itemId] = derived;
    return derived;
  }

  /// Zero out a key buffer in place and release the reference.
  void _zeroKey(Uint8List? key) {
    if (key == null) return;
    for (var i = 0; i < key.length; i++) {
      key[i] = 0;
    }
  }

  /// Clear all cached per-item keys, zeroing them first.
  void _clearItemKeyCache() {
    for (final key in _itemKeyCache.values) {
      _zeroKey(key);
    }
    _itemKeyCache.clear();
  }

  /// Encrypt a plaintext string for a specific item (note, tag, etc.).
  ///
  /// [itemId] - UUID of the item being encrypted.
  /// [plaintext] - The plaintext content to encrypt.
  /// Returns base64-encoded ciphertext.
  Future<String> encryptForItem(String itemId, String plaintext) async {
    final itemKey = await _getOrDeriveItemKey(itemId);
    return Encryptor.encrypt(plaintext, itemKey);
  }

  /// Decrypt ciphertext for a specific item.
  ///
  /// [itemId] - UUID of the item to decrypt.
  /// [encrypted] - Base64-encoded ciphertext.
  /// Returns the decrypted plaintext string, or null if decryption fails.
  Future<String?> decryptForItem(String itemId, String encrypted) async {
    try {
      final itemKey = await _getOrDeriveItemKey(itemId);
      return await Encryptor.decrypt(encrypted, itemKey);
    } on StateError {
      // CryptoService is locked — no encrypt key available.
      return null;
    } catch (e) {
      throw DecryptionException(
        'AEAD decryption failed for item $itemId',
        cause: e,
      );
    }
  }

  /// Encrypt binary blob data for a specific item (used for sync).
  Future<Uint8List> encryptBlobForItem(String itemId, Uint8List data) async {
    final itemKey = await _getOrDeriveItemKey(itemId);
    return Encryptor.encryptBlob(data, itemKey);
  }

  /// Decrypt binary blob data for a specific item (used for sync).
  Future<Uint8List?> decryptBlobForItem(
    String itemId,
    Uint8List encrypted,
  ) async {
    try {
      final itemKey = await _getOrDeriveItemKey(itemId);
      return await Encryptor.decryptBlob(encrypted, itemKey);
    } on StateError {
      // CryptoService is locked — no encrypt key available.
      return null;
    } catch (e) {
      throw DecryptionException(
        'AEAD blob decryption failed for item $itemId',
        cause: e,
      );
    }
  }
}

/// Riverpod provider for the CryptoService singleton.
/// The service is created once and shared across the app.
final cryptoServiceProvider = Provider<CryptoService>((ref) {
  return CryptoService();
});
