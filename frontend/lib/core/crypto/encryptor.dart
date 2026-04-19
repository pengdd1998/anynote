import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium_libs/sodium_libs_sumo.dart';

/// XChaCha20-Poly1305 AEAD encryptor for E2E encryption.
///
/// Wire format: nonce (24 bytes) || ciphertext + tag (16 bytes)
/// Each item (note, tag, collection) uses a unique per-item key
/// derived from the encrypt key via BLAKE2b keyed hash.
class Encryptor {
  static Sodium? _sodiumInstance;

  /// Get or initialize the Sodium singleton.
  static Future<Sodium> get _sodium async {
    return _sodiumInstance ??= await SodiumSumoInit.init();
  }

  /// Encrypt plaintext using XChaCha20-Poly1305.
  ///
  /// [plaintext] - The data to encrypt (UTF-8 string)
  /// [itemKey] - Per-item key (32 bytes) derived via MasterKeyManager.deriveItemKey()
  ///
  /// Returns base64-encoded string: nonce (24) || ciphertext + tag (16)
  static Future<String> encrypt(String plaintext, Uint8List itemKey) async {
    final sodium = await _sodium;
    final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));
    final nonce = sodium.secureRandom(
      sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes,
    );
    final key = SecureKey.fromList(sodium, itemKey);

    final nonceBytes = nonce.extractBytes();
    final ciphertext = sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
      message: plaintextBytes,
      key: key,
      nonce: nonceBytes,
    );

    // Combine: nonce || ciphertext (includes 16-byte tag)
    final combined = Uint8List(nonceBytes.length + ciphertext.length);
    combined.setRange(0, nonceBytes.length, nonceBytes);
    combined.setRange(nonceBytes.length, combined.length, ciphertext);

    key.dispose();
    nonce.dispose();
    return base64Encode(combined);
  }

  /// Decrypt ciphertext using XChaCha20-Poly1305.
  ///
  /// [encryptedBase64] - Base64-encoded: nonce (24) + ciphertext + tag (16)
  /// [itemKey] - Per-item key (32 bytes) that was used to encrypt
  ///
  /// Returns decrypted plaintext string.
  /// Throws on tag verification failure (tampered or wrong key).
  static Future<String> decrypt(
    String encryptedBase64,
    Uint8List itemKey,
  ) async {
    final sodium = await _sodium;
    final combined = base64Decode(encryptedBase64);

    final nonceLength = sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes;
    final nonce = combined.sublist(0, nonceLength);
    final ciphertext = combined.sublist(nonceLength);
    final key = SecureKey.fromList(sodium, itemKey);

    final plaintextBytes = sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
      cipherText: ciphertext,
      key: key,
      nonce: nonce,
    );

    key.dispose();
    return utf8.decode(plaintextBytes);
  }

  /// Encrypt binary data (for blob sync).
  static Future<Uint8List> encryptBlob(Uint8List data, Uint8List itemKey) async {
    final sodium = await _sodium;
    final nonce = sodium.secureRandom(
      sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes,
    );
    final key = SecureKey.fromList(sodium, itemKey);

    final nonceBytes = nonce.extractBytes();
    final ciphertext = sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
      message: data,
      key: key,
      nonce: nonceBytes,
    );

    final combined = Uint8List(nonceBytes.length + ciphertext.length);
    combined.setRange(0, nonceBytes.length, nonceBytes);
    combined.setRange(nonceBytes.length, combined.length, ciphertext);

    key.dispose();
    nonce.dispose();
    return combined;
  }

  /// Decrypt binary data (from blob sync).
  /// Throws on tag verification failure.
  static Future<Uint8List> decryptBlob(
    Uint8List encrypted,
    Uint8List itemKey,
  ) async {
    final sodium = await _sodium;
    final nonceLength = sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes;
    final aBytes = sodium.crypto.aeadXChaCha20Poly1305IETF.aBytes;

    if (encrypted.length < nonceLength + aBytes) {
      throw ArgumentError('Encrypted data too short');
    }

    final nonce = encrypted.sublist(0, nonceLength);
    final ciphertext = encrypted.sublist(nonceLength);
    final key = SecureKey.fromList(sodium, itemKey);

    final plaintext = sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
      cipherText: ciphertext,
      key: key,
      nonce: nonce,
    );

    key.dispose();
    return plaintext;
  }

  /// Derive a per-item key from the encrypt key using BLAKE2b keyed hash.
  ///
  /// [encryptKey] - The master encrypt key (32 bytes)
  /// [itemId] - Unique item identifier (note UUID, tag UUID, etc.)
  /// Returns a 32-byte derived key unique to this item.
  static Future<Uint8List> derivePerItemKey(
    Uint8List encryptKey,
    String itemId,
  ) async {
    final sodium = await _sodium;
    final key = SecureKey.fromList(sodium, encryptKey);
    final message = Uint8List.fromList(utf8.encode(itemId));

    final derived = sodium.crypto.genericHash.call(
      message: message,
      key: key,
      outLen: 32,
    );

    key.dispose();
    return derived;
  }
}
