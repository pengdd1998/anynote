import 'dart:typed_data';

// Unified implementation using sodium_libs on all platforms.
// sodium_libs provides a JS/WASM backend (libsodium.js) for web browsers,
// so the same XChaCha20-Poly1305 + BLAKE2b code works everywhere.
import 'encryptor_native.dart';

/// AEAD encryptor for E2E encryption.
///
/// On all platforms: uses XChaCha20-Poly1305 via sodium_libs.
/// Wire format (current): nonce (24 bytes) || ciphertext + tag (16 bytes).
///
/// For backward compatibility with data encrypted on web using the old
/// AES-256-GCM format, this encryptor can detect and decrypt the legacy
/// format (iv 12 bytes || ciphertext + tag) when sodium_libs fails.
///
/// Each item (note, tag, collection) uses a unique per-item key
/// derived from the encrypt key via BLAKE2b keyed hash.
class Encryptor {
  /// Encrypt plaintext.
  ///
  /// [plaintext] - The data to encrypt (UTF-8 string)
  /// [itemKey] - Per-item key (32 bytes) derived via derivePerItemKey()
  ///
  /// Returns base64-encoded string: nonce (24) || ciphertext + tag (16).
  static Future<String> encrypt(String plaintext, Uint8List itemKey) {
    return encryptImpl(plaintext, itemKey);
  }

  /// Decrypt ciphertext.
  ///
  /// [encryptedBase64] - Base64-encoded: nonce/iv + ciphertext + tag
  /// [itemKey] - Per-item key (32 bytes) that was used to encrypt
  ///
  /// Returns decrypted plaintext string.
  /// Throws on tag verification failure (tampered or wrong key).
  static Future<String> decrypt(
    String encryptedBase64,
    Uint8List itemKey,
  ) {
    return decryptImpl(encryptedBase64, itemKey);
  }

  /// Encrypt binary data (for blob sync).
  static Future<Uint8List> encryptBlob(Uint8List data, Uint8List itemKey) {
    return encryptBlobImpl(data, itemKey);
  }

  /// Decrypt binary data (from blob sync).
  /// Throws on tag verification failure.
  static Future<Uint8List> decryptBlob(
    Uint8List encrypted,
    Uint8List itemKey,
  ) {
    return decryptBlobImpl(encrypted, itemKey);
  }

  /// Derive a per-item key from the encrypt key.
  ///
  /// [encryptKey] - The master encrypt key (32 bytes)
  /// [itemId] - Unique item identifier (note UUID, tag UUID, etc.)
  /// Returns a 32-byte derived key unique to this item.
  static Future<Uint8List> derivePerItemKey(
    Uint8List encryptKey,
    String itemId,
  ) {
    return derivePerItemKeyImpl(encryptKey, itemId);
  }
}
