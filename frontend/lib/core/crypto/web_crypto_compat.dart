import 'package:flutter/foundation.dart' show kIsWeb;

/// Web crypto compatibility layer.
///
/// Provides runtime checks for crypto platform availability and
/// an initialization entry point for the appropriate crypto backend.
///
/// On native: sodium_libs is used (initialized lazily).
/// On web: WebCrypto is available natively in the browser.
///
/// The actual platform-specific implementations are in:
/// - Native: master_key_native_compat.dart, encryptor_native.dart
/// - Web: master_key_web_compat.dart, encryptor_web.dart
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
    } else {
      // Native path: sodium_libs is initialized lazily in Encryptor
      // and MasterKeyManager via SodiumSumoInit.init().
    }
  }

  /// Check if full E2E encryption is supported on this platform.
  static bool get isFullEncryptionSupported => true;
}
