import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium_libs/sodium_libs_sumo.dart';

/// Native encryptor implementation using XChaCha20-Poly1305 via sodium_libs.
///
/// Wire format: nonce (24 bytes) || ciphertext + tag (16 bytes).

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

// Sodium singleton.
SodiumSumo? _sodiumInstance;

Future<SodiumSumo> _getSodium() async {
  return _sodiumInstance ??= await SodiumSumoInit.init();
}
