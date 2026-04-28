import 'dart:typed_data';

import 'encryptor.dart';

/// Factory for obtaining platform-appropriate crypto primitives.
///
/// Since Phase 142, all platforms use the same sodium_libs-based crypto
/// backend (XChaCha20-Poly1305, Argon2id, BLAKE2b). This class provides
/// a convenience wrapper for callers that prefer a factory pattern over
/// static Encryptor methods.
///
/// Usage:
///   final factory = CryptoFactory.instance;
///   final encrypted = await factory.encrypt(plaintext, key);
class CryptoFactory {
  CryptoFactory._();

  static final CryptoFactory instance = CryptoFactory._();

  /// Whether this platform uses the native (sodium_libs) backend.
  /// Always true since Phase 142 (unified crypto across all platforms).
  bool get isNativeBackend => true;

  /// Encrypt plaintext with the given key using XChaCha20-Poly1305.
  Future<String> encrypt(String plaintext, List<int> itemKey) async {
    final key = Uint8List.fromList(itemKey);
    return Encryptor.encrypt(plaintext, key);
  }

  /// Decrypt ciphertext with the given key.
  Future<String> decrypt(String encryptedBase64, List<int> itemKey) async {
    final key = Uint8List.fromList(itemKey);
    return Encryptor.decrypt(encryptedBase64, key);
  }

  /// Derive a per-item key from the encrypt key and item ID using BLAKE2b.
  Future<List<int>> deriveItemKey(List<int> encryptKey, String itemId) async {
    final key = Uint8List.fromList(encryptKey);
    return Encryptor.derivePerItemKey(key, itemId);
  }
}
