/// Web crypto compatibility layer.
///
/// Since Phase 142, all platforms use sodium_libs (libsodium) for crypto
/// operations. sodium_libs provides a JS/WASM backend (libsodium.js) for
/// web browsers, enabling the same algorithms on all platforms:
///   - XChaCha20-Poly1305 for AEAD encryption
///   - Argon2id for password hashing
///   - BLAKE2b for key derivation
///
/// This class exists primarily for backward compatibility with callers
/// that reference it, and for platform capability introspection.
class CryptoCompat {
  /// Whether the current platform supports native crypto via sodium_libs.
  /// Always true since Phase 142 (sodium_libs WASM/JS on web).
  static bool get supportsNativeCrypto => true;

  /// Initialize the crypto backend.
  ///
  /// On all platforms, this is a no-op because sodium_libs is initialized
  /// lazily on first use by the Encryptor and MasterKeyManager classes.
  static Future<void> init() async {
    // No-op: sodium_libs initializes lazily via SodiumSumoInit.init()
    // the first time it is needed.
  }

  /// Check if full E2E encryption is supported on this platform.
  /// Always true since all platforms use sodium_libs.
  static bool get isFullEncryptionSupported => true;
}
