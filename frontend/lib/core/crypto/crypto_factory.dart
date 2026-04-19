import 'package:flutter/foundation.dart' show kIsWeb;

import 'crypto_factory_native.dart' if (dart.library.html) 'crypto_factory_web.dart';

/// Factory for obtaining platform-appropriate crypto primitives.
///
/// On native platforms (Android, iOS, macOS, Windows), this delegates to
/// sodium_libs (libsodium) for XChaCha20-Poly1305, Argon2id, and BLAKE2b.
///
/// On web, this provides stub implementations that throw UnsupportedError
/// until a WebCrypto-based backend is implemented.
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
  /// On web: throws UnsupportedError until WebCrypto backend is implemented.
  Future<String> encrypt(String plaintext, List<int> itemKey) {
    return encryptImpl(plaintext, itemKey);
  }

  /// Decrypt ciphertext with the given key.
  ///
  /// On native: uses XChaCha20-Poly1305 via sodium_libs.
  /// On web: throws UnsupportedError until WebCrypto backend is implemented.
  Future<String> decrypt(String encryptedBase64, List<int> itemKey) {
    return decryptImpl(encryptedBase64, itemKey);
  }

  /// Derive a per-item key from the encrypt key and item ID.
  ///
  /// On native: uses BLAKE2b keyed hash via sodium_libs.
  /// On web: throws UnsupportedError until WebCrypto backend is implemented.
  Future<List<int>> deriveItemKey(List<int> encryptKey, String itemId) {
    return deriveItemKeyImpl(encryptKey, itemId);
  }
}
