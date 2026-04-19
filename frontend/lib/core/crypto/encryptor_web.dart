import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web encryptor implementation using AES-256-GCM via WebCrypto.
///
/// Wire format: iv (12 bytes) || ciphertext + tag.
///
/// **IMPORTANT**: Ciphertexts are NOT compatible with native XChaCha20-Poly1305.

/// Helper: create a JS algorithm object for AES-GCM.
JSAny _aesGcmAlgorithm(Uint8List iv) {
  return {'name': 'AES-GCM', 'iv': iv.toJS}.jsify()!;
}

/// Helper: create a JS algorithm object for AES-GCM key import.
JSAny _aesGcmKeyAlgorithm() {
  return {'name': 'AES-GCM', 'length': 256}.jsify()!;
}

/// Helper: create a JS algorithm object for HMAC key import.
JSAny _hmacKeyAlgorithm() {
  return {'name': 'HMAC', 'hash': 'SHA-256'}.jsify()!;
}

/// Helper: create a JSArray<JSString> from a list of Dart strings.
JSArray<JSString> _jsStringArray(List<String> strings) {
  return strings.map((s) => s.toJS).toList().toJS;
}

/// Helper: convert JSPromise<JSAny?> to Future<Uint8List>.
Future<Uint8List> _arrayBufferFromPromise(JSPromise<JSAny?> promise) async {
  final result = await promise.toDart;
  return (result as JSArrayBuffer).toDart.asUint8List();
}

Future<String> encryptImpl(String plaintext, Uint8List itemKey) async {
  final subtle = web.window.crypto.subtle;
  final plainBytes = Uint8List.fromList(utf8.encode(plaintext));

  // Generate a random 12-byte IV.
  final iv = Uint8List(12);
  web.window.crypto.getRandomValues(iv.toJS);

  // Import the raw key as a CryptoKey for AES-GCM.
  final cryptoKey = await subtle
      .importKey(
        'raw',
        itemKey.toJS,
        _aesGcmKeyAlgorithm(),
        false,
        _jsStringArray(['encrypt']),
      )
      .toDart;

  // Encrypt.
  final encryptedBytes = await _arrayBufferFromPromise(
    subtle.encrypt(_aesGcmAlgorithm(iv), cryptoKey, plainBytes.toJS),
  );

  // Combine: iv(12) || ciphertext+tag.
  final combined = Uint8List(iv.length + encryptedBytes.lengthInBytes);
  combined.setRange(0, iv.length, iv);
  combined.setRange(iv.length, combined.length, encryptedBytes);

  return base64Encode(combined);
}

Future<String> decryptImpl(String encryptedBase64, Uint8List itemKey) async {
  final subtle = web.window.crypto.subtle;
  final combined = base64Decode(encryptedBase64);

  if (combined.length < 28) {
    throw ArgumentError('Encrypted data too short: missing IV and/or GCM tag');
  }

  final iv = Uint8List.fromList(combined.sublist(0, 12));
  final ciphertext = Uint8List.fromList(combined.sublist(12));

  // Import key for AES-GCM decryption.
  final cryptoKey = await subtle
      .importKey(
        'raw',
        itemKey.toJS,
        _aesGcmKeyAlgorithm(),
        false,
        _jsStringArray(['decrypt']),
      )
      .toDart;

  // Decrypt.
  final decryptedBytes = await _arrayBufferFromPromise(
    subtle.decrypt(_aesGcmAlgorithm(iv), cryptoKey, ciphertext.toJS),
  );

  return utf8.decode(decryptedBytes);
}

Future<Uint8List> encryptBlobImpl(Uint8List data, Uint8List itemKey) async {
  final subtle = web.window.crypto.subtle;

  // Generate a random 12-byte IV.
  final iv = Uint8List(12);
  web.window.crypto.getRandomValues(iv.toJS);

  // Import key.
  final cryptoKey = await subtle
      .importKey(
        'raw',
        itemKey.toJS,
        _aesGcmKeyAlgorithm(),
        false,
        _jsStringArray(['encrypt']),
      )
      .toDart;

  // Encrypt.
  final encryptedBytes = await _arrayBufferFromPromise(
    subtle.encrypt(_aesGcmAlgorithm(iv), cryptoKey, data.toJS),
  );

  // Combine: iv(12) || ciphertext+tag.
  final combined = Uint8List(iv.length + encryptedBytes.lengthInBytes);
  combined.setRange(0, iv.length, iv);
  combined.setRange(iv.length, combined.length, encryptedBytes);

  return combined;
}

Future<Uint8List> decryptBlobImpl(Uint8List encrypted, Uint8List itemKey) async {
  final subtle = web.window.crypto.subtle;

  if (encrypted.length < 12 + 16) {
    throw ArgumentError('Encrypted data too short');
  }

  final iv = Uint8List.fromList(encrypted.sublist(0, 12));
  final ciphertext = Uint8List.fromList(encrypted.sublist(12));

  // Import key.
  final cryptoKey = await subtle
      .importKey(
        'raw',
        itemKey.toJS,
        _aesGcmKeyAlgorithm(),
        false,
        _jsStringArray(['decrypt']),
      )
      .toDart;

  // Decrypt.
  return _arrayBufferFromPromise(
    subtle.decrypt(_aesGcmAlgorithm(iv), cryptoKey, ciphertext.toJS),
  );
}

Future<Uint8List> derivePerItemKeyImpl(
  Uint8List encryptKey,
  String itemId,
) async {
  final subtle = web.window.crypto.subtle;
  final messageBytes = Uint8List.fromList(utf8.encode(itemId));

  // Import encrypt key as an HMAC key with SHA-256.
  final cryptoKey = await subtle
      .importKey(
        'raw',
        encryptKey.toJS,
        _hmacKeyAlgorithm(),
        false,
        _jsStringArray(['sign']),
      )
      .toDart;

  // Compute HMAC-SHA256(encryptKey, itemId).
  return _arrayBufferFromPromise(
    subtle.sign('HMAC'.toJS, cryptoKey, messageBytes.toJS),
  );
}
