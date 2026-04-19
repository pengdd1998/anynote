import 'package:flutter/foundation.dart' show kIsWeb;

import 'crypto_factory_native.dart'
    if (dart.library.js) 'crypto_factory_web.dart';

/// Factory for obtaining platform-appropriate crypto primitives.
///
/// On native platforms (Android, iOS, macOS, Windows), this delegates to
/// sodium_libs (libsodium) for XChaCha20-Poly1305, Argon2id, and BLAKE2b.
///
/// On web, this uses WebCrypto API for AES-256-GCM, PBKDF2, and HMAC-SHA256.
///
/// **IMPORTANT**: Web and native ciphertexts are INCOMPATIBLE. Data encrypted
/// on native cannot be decrypted on web and vice versa. This is an accepted
/// limitation due to the different algorithm suites.
///
/// Usage:
///   final factory = CryptoFactory.instance;
///   final encrypted = await factory.encrypt(plaintext, key);
class CryptoFactory {
  CryptoFactory._();

  static final CryptoFactory instance = CryptoFactory._();

  /// Whether this platform uses the native (sodium_libs) backend.
  bool get isNativeBackend => !kIsWeb;

  /// Encrypt plaintext with the given key.
  ///
  /// On native: uses XChaCha20-Poly1305 via sodium_libs.
  /// On web: uses AES-256-GCM via WebCrypto.
  Future<String> encrypt(String plaintext, List<int> itemKey) {
    return encryptImpl(plaintext, itemKey);
  }

  /// Decrypt ciphertext with the given key.
  ///
  /// On native: uses XChaCha20-Poly1305 via sodium_libs.
  /// On web: uses AES-256-GCM via WebCrypto.
  Future<String> decrypt(String encryptedBase64, List<int> itemKey) {
    return decryptImpl(encryptedBase64, itemKey);
  }

  /// Derive a per-item key from the encrypt key and item ID.
  ///
  /// On native: uses BLAKE2b keyed hash via sodium_libs.
  /// On web: uses HMAC-SHA256 via WebCrypto.
  Future<List<int>> deriveItemKey(List<int> encryptKey, String itemId) {
    return deriveItemKeyImpl(encryptKey, itemId);
  }
}
