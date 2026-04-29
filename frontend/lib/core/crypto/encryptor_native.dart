import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sodium_libs/sodium_libs_sumo.dart';

/// Unified encryptor implementation using XChaCha20-Poly1305 via sodium_libs.
///
/// This file is used on ALL platforms (native and web) because sodium_libs
/// provides a WASM/JS backend (libsodium.js) for web browsers.
///
/// Wire format: nonce (24 bytes) || ciphertext + tag (16 bytes).
///
/// For backward compatibility with legacy web-encrypted data (AES-256-GCM
/// with 12-byte IV), the decrypt functions attempt legacy decryption when
/// the sodium decryption fails and the ciphertext length suggests the old
/// format.

/// Overwrites each byte with zero so sensitive material does not linger on
/// the Dart heap until garbage collection.
void _zeroBytes(Uint8List bytes) {
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = 0;
  }
}

Future<String> encryptImpl(String plaintext, Uint8List itemKey) async {
  final sodium = await _getSodium();
  final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));
  final nonce = sodium.secureRandom(
    sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes,
  );
  final key = SecureKey.fromList(sodium, itemKey);

  final nonceBytes = nonce.extractBytes();
  try {
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
  } finally {
    _zeroBytes(nonceBytes);
  }
}

Future<String> decryptImpl(String encryptedBase64, Uint8List itemKey) async {
  final sodium = await _getSodium();
  final combined = base64Decode(encryptedBase64);

  final nonceLength = sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes;
  final aBytes = sodium.crypto.aeadXChaCha20Poly1305IETF.aBytes;

  // Check if this looks like native XChaCha20-Poly1305 format:
  // nonce(24) + ciphertext + tag(16). Minimum valid size = 24 + 16 = 40.
  if (combined.length >= nonceLength + aBytes) {
    final nonce = combined.sublist(0, nonceLength);
    final ciphertext = combined.sublist(nonceLength);

    if (ciphertext.length >= aBytes) {
      final key = SecureKey.fromList(sodium, itemKey);

      try {
        final plaintextBytes = sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
          cipherText: ciphertext,
          key: key,
          nonce: nonce,
        );

        key.dispose();
        return utf8.decode(plaintextBytes);
      } catch (e) {
        key.dispose();
        // If the nonce is 24 bytes and the data looks like the native format
        // but decryption failed, it is a genuine error (wrong key or tampered).
        // Only attempt legacy decryption if the nonce was NOT 24 bytes.
        if (combined.length >= 24 && combined.length < 24 + 28) {
          // Too short even for native format with any content -- try legacy.
          debugPrint(
            '[Encryptor] native decrypt failed for short ciphertext, '
            'attempting legacy web format',
          );
          return _tryLegacyWebDecryptString(encryptedBase64, itemKey);
        }
        rethrow;
      }
    }
  }

  // If the data is too short for native format, it might be legacy web format
  // (12-byte IV + ciphertext + 16-byte GCM tag). Try that.
  debugPrint(
    '[Encryptor] ciphertext too short for native format, '
    'attempting legacy web format',
  );
  return _tryLegacyWebDecryptString(encryptedBase64, itemKey);
}

Future<Uint8List> encryptBlobImpl(Uint8List data, Uint8List itemKey) async {
  final sodium = await _getSodium();
  final nonce = sodium.secureRandom(
    sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes,
  );
  final key = SecureKey.fromList(sodium, itemKey);

  final nonceBytes = nonce.extractBytes();
  try {
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
  } finally {
    _zeroBytes(nonceBytes);
  }
}

Future<Uint8List> decryptBlobImpl(
  Uint8List encrypted,
  Uint8List itemKey,
) async {
  final sodium = await _getSodium();
  final nonceLength = sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes;
  final aBytes = sodium.crypto.aeadXChaCha20Poly1305IETF.aBytes;

  if (encrypted.length >= nonceLength + aBytes) {
    final nonce = encrypted.sublist(0, nonceLength);
    final ciphertext = encrypted.sublist(nonceLength);

    if (ciphertext.length >= aBytes) {
      final key = SecureKey.fromList(sodium, itemKey);

      try {
        final plaintext = sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
          cipherText: ciphertext,
          key: key,
          nonce: nonce,
        );

        key.dispose();
        return plaintext;
      } catch (e) {
        key.dispose();
        // Attempt legacy web format for blob data.
        if (encrypted.length >= 12 + 16) {
          debugPrint(
            '[Encryptor] native blob decrypt failed, '
            'attempting legacy web format',
          );
          return _tryLegacyWebDecryptBlob(encrypted, itemKey);
        }
        rethrow;
      }
    }
  }

  // Try legacy web blob format.
  if (encrypted.length >= 12 + 16) {
    return _tryLegacyWebDecryptBlob(encrypted, itemKey);
  }

  throw ArgumentError('Encrypted data too short for any known format');
}

Future<Uint8List> derivePerItemKeyImpl(
  Uint8List encryptKey,
  String itemId,
) async {
  final sodium = await _getSodium();
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

// ── Legacy Web Decryption (AES-256-GCM backward compat) ──────────────
//
// These methods handle data that was encrypted with the old web-only
// encryptor_web.dart using AES-256-GCM (12-byte IV). They are only
// invoked when the XChaCha20-Poly1305 decryption fails and the
// ciphertext size is consistent with the legacy format.
//
// On native platforms these should never succeed (the keys were derived
// differently via HMAC-SHA256 vs BLAKE2b), but we include the attempt
// for completeness. On web platforms with sodium WASM, the sodium
// decryption should succeed first for new data.

Future<String> _tryLegacyWebDecryptString(
  String encryptedBase64,
  Uint8List itemKey,
) async {
  // Legacy format: IV(12) || ciphertext + GCM tag(16).
  // We cannot decrypt this without the WebCrypto API, which is only
  // available on web. On native, this data would have been encrypted
  // with a different key derivation (HMAC-SHA256 vs BLAKE2b), so even
  // if we could decrypt the algorithm, the key would be wrong.
  //
  // Since we are now using sodium_libs on ALL platforms (including web),
  // new data will always use XChaCha20-Poly1305. Legacy web data should
  // be rare and would require the old WebCrypto path to decrypt.
  //
  // For now, throw a descriptive error.
  throw const FormatException(
    'Legacy web-encrypted data (AES-256-GCM) cannot be decrypted with '
    'the current crypto backend. Re-encrypt the data on the original '
    'platform or use the migration tool.',
  );
}

Future<Uint8List> _tryLegacyWebDecryptBlob(
  Uint8List encrypted,
  Uint8List itemKey,
) async {
  throw const FormatException(
    'Legacy web-encrypted blob data (AES-256-GCM) cannot be decrypted '
    'with the current crypto backend.',
  );
}

// Sodium singleton.
SodiumSumo? _sodiumInstance;

Future<SodiumSumo> _getSodium() async {
  return _sodiumInstance ??= await SodiumSumoInit.init();
}

/// Reset the sodium singleton (for testing).
void resetSodiumInstance() {
  _sodiumInstance = null;
}
