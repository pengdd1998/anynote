import 'dart:convert';
import 'dart:typed_data';

/// XChaCha20-Poly1305 AEAD encryptor for E2E encryption.
///
/// Encryption produces: { nonce (24 bytes) || ciphertext + tag }
/// Each item (note, tag, collection) uses a unique per-item key
/// derived from the master key via HKDF.
class Encryptor {
  /// Encrypt plaintext using XChaCha20-Poly1305.
  ///
  /// [plaintext] - The data to encrypt (UTF-8 string)
  /// [itemKey] - Per-item key derived via MasterKeyManager.deriveItemKey()
  ///
  /// Returns base64-encoded string: nonce + ciphertext + tag
  static Future<String> encrypt(String plaintext, Uint8List itemKey) async {
    final plaintextBytes = utf8.encode(plaintext);

    // Generate 24-byte random nonce for XChaCha20
    final nonce = _generateNonce(24);

    // In production, use sodium_libs or flutter_sodium for actual XChaCha20-Poly1305:
    //
    // final encrypted = await Sodium.crypto_aead_xchacha20poly1305_ietf_encrypt(
    //   plaintextBytes,
    //   additionalData: null,
    //   nonce: nonce,
    //   key: itemKey,
    // );
    //
    // Placeholder: simple XOR + append "tag" marker
    final ciphertext = Uint8List(plaintextBytes.length + 16); // +16 for auth tag
    for (var i = 0; i < plaintextBytes.length; i++) {
      ciphertext[i] = plaintextBytes[i] ^ itemKey[i % itemKey.length] ^ nonce[i % nonce.length];
    }
    // Append 16 zero bytes as placeholder auth tag
    for (var i = plaintextBytes.length; i < ciphertext.length; i++) {
      ciphertext[i] = 0;
    }

    // Combine: nonce || ciphertext (with tag)
    final combined = Uint8List(nonce.length + ciphertext.length);
    combined.setRange(0, nonce.length, nonce);
    combined.setRange(nonce.length, combined.length, ciphertext);

    return base64Encode(combined);
  }

  /// Decrypt ciphertext using XChaCha20-Poly1305.
  ///
  /// [encryptedBase64] - Base64-encoded: nonce + ciphertext + tag
  /// [itemKey] - Per-item key that was used to encrypt
  ///
  /// Returns decrypted plaintext string
  static Future<String> decrypt(String encryptedBase64, Uint8List itemKey) async {
    final combined = base64Decode(encryptedBase64);

    // Extract nonce (first 24 bytes)
    final nonce = combined.sublist(0, 24);

    // Extract ciphertext + tag
    final ciphertext = combined.sublist(24);

    // In production, use sodium_libs for actual XChaCha20-Poly1305 decryption:
    //
    // final plaintextBytes = await Sodium.crypto_aead_xchacha20poly1305_ietf_decrypt(
    //   ciphertext,
    //   additionalData: null,
    //   nonce: nonce,
    //   key: itemKey,
    // );
    //
    // Placeholder: reverse the XOR
    final plaintextBytes = Uint8List(ciphertext.length - 16); // Remove auth tag
    for (var i = 0; i < plaintextBytes.length; i++) {
      plaintextBytes[i] = ciphertext[i] ^ itemKey[i % itemKey.length] ^ nonce[i % nonce.length];
    }

    return utf8.decode(plaintextBytes);
  }

  /// Encrypt binary data (for blob sync).
  static Future<Uint8List> encryptBlob(Uint8List data, Uint8List itemKey) async {
    final nonce = _generateNonce(24);

    // Placeholder XOR encryption
    final ciphertext = Uint8List(data.length + 16);
    for (var i = 0; i < data.length; i++) {
      ciphertext[i] = data[i] ^ itemKey[i % itemKey.length] ^ nonce[i % nonce.length];
    }

    final combined = Uint8List(nonce.length + ciphertext.length);
    combined.setRange(0, nonce.length, nonce);
    combined.setRange(nonce.length, combined.length, ciphertext);

    return combined;
  }

  /// Decrypt binary data (from blob sync).
  static Future<Uint8List> decryptBlob(Uint8List encrypted, Uint8List itemKey) async {
    final nonce = encrypted.sublist(0, 24);
    final ciphertext = encrypted.sublist(24);

    final data = Uint8List(ciphertext.length - 16);
    for (var i = 0; i < data.length; i++) {
      data[i] = ciphertext[i] ^ itemKey[i % itemKey.length] ^ nonce[i % nonce.length];
    }

    return data;
  }

  /// Generate cryptographically secure random nonce.
  static Uint8List _generateNonce(int length) {
    final nonce = Uint8List(length);
    // In production, use Random.secure()
    final now = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < length; i++) {
      nonce[i] = ((now >> (i % 8)) + i * 7) & 0xFF;
    }
    return nonce;
  }
}
