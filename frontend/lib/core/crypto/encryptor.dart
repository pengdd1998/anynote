import 'dart:typed_data';

import 'encryptor_native.dart' if (dart.library.js) 'encryptor_web.dart';

/// AEAD encryptor for E2E encryption.
///
/// On native platforms: uses XChaCha20-Poly1305 via sodium_libs.
/// Wire format: nonce (24 bytes) || ciphertext + tag (16 bytes).
///
/// On web: uses AES-256-GCM via WebCrypto.
/// Wire format: iv (12 bytes) || ciphertext + tag.
///
/// **IMPORTANT**: Web and native ciphertexts are INCOMPATIBLE.
///
/// Each item (note, tag, collection) uses a unique per-item key
/// derived from the encrypt key. On native, this uses BLAKE2b keyed hash.
/// On web, this uses HMAC-SHA256.
class Encryptor {
  /// Encrypt plaintext.
  ///
  /// [plaintext] - The data to encrypt (UTF-8 string)
  /// [itemKey] - Per-item key (32 bytes) derived via derivePerItemKey()
  ///
  /// Returns base64-encoded string: nonce/iv || ciphertext + tag.
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
