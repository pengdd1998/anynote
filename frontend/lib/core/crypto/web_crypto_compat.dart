import 'package:flutter/foundation.dart' show kIsWeb;

/// Web crypto compatibility layer.
///
/// The app uses `sodium_libs` for native crypto (XChaCha20-Poly1305, Argon2id,
/// BLAKE2b) which does not work on web. This class provides a runtime check
/// for whether native crypto is available and a stub initialization path for web.
///
/// Limitations on web:
/// - sodium_libs (libsodium) is not available on web
/// - Argon2id key derivation must be replaced with a WebCrypto equivalent
/// - XChaCha20-Poly1305 must be replaced with AES-256-GCM (WebCrypto native)
/// - BLAKE2b hashing must be replaced with SHA-256/SHA-384 (WebCrypto native)
///
/// These limitations mean that **web clients cannot decrypt data encrypted by
/// native clients** and vice versa. The web platform is a secondary target.
class CryptoCompat {
  /// Whether the current platform supports native crypto via sodium_libs.
  static bool get supportsNativeCrypto => !kIsWeb;

  /// Initialize the platform-appropriate crypto backend.
  ///
  /// On native platforms, this initializes sodium_libs.
  /// On web, this is a no-op (WebCrypto is available natively in the browser).
  static Future<void> init() async {
    if (kIsWeb) {
      // WebCrypto is available natively in modern browsers via
      // window.crypto.subtle. No additional initialization needed.
      // Actual crypto operations on web would use the web_crypto package
      // or dart:html/dart:js_interop for SubtleCrypto API access.
    } else {
      // Native path: sodium_libs is initialized lazily in Encryptor
      // and MasterKeyManager via SodiumSumoInit.init().
    }
  }

  /// Check if full E2E encryption is supported on this platform.
  ///
  /// Returns false on web because the crypto primitives differ from native.
  static bool get isFullEncryptionSupported => !kIsWeb;
}
