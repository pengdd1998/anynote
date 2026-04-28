import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'bip39_wordlist.dart';

// Web implementation of platform-specific crypto functions for MasterKeyManager.
// Uses WebCrypto API for PBKDF2, HMAC-SHA256, SHA-256.

/// KDF version for web platform (PBKDF2 with 600k iterations).
/// This version does not change; only the native Argon2id parameters are
/// being upgraded. The web version constant exists for API compatibility.
const int kdfVersionNative = 1;

// ── Helpers ─────────────────────────────────────────────────────────

/// Helper: create a JSArray<JSString> from a list of Dart strings.
JSArray<JSString> _jsStringArray(List<String> strings) {
  return strings.map((s) => s.toJS).toList().toJS;
}

/// Helper: convert JSPromise<JSAny?> to Future<Uint8List>.
Future<Uint8List> _arrayBufferFromPromise(JSPromise<JSAny?> promise) async {
  final result = await promise.toDart;
  return (result as JSArrayBuffer).toDart.asUint8List();
}

/// Helper: create a JS algorithm object for HMAC key import.
JSAny _hmacKeyAlgorithm() {
  return {'name': 'HMAC', 'hash': 'SHA-256'}.jsify()!;
}

/// Generate a 32-byte salt using WebCrypto getRandomValues.
Uint8List generateSaltImpl() {
  final salt = Uint8List(32);
  web.window.crypto.getRandomValues(salt.toJS);
  return salt;
}

/// Derive master key using PBKDF2-SHA256 with 600,000 iterations.
/// The [kdfVersion] parameter is accepted for API compatibility with the
/// native implementation but is ignored -- web PBKDF2 parameters are not
/// being changed (600k iterations is above OWASP recommendations).
Future<Uint8List> deriveMasterKeyImpl(
  String password,
  Uint8List salt, [
  int? kdfVersion,
]) async {
  final subtle = web.window.crypto.subtle;
  final passwordBytes = Uint8List.fromList(utf8.encode(password));

  // Import password as a raw key for PBKDF2.
  final baseKey = await subtle
      .importKey(
        'raw',
        passwordBytes.toJS,
        'PBKDF2'.toJS,
        false,
        _jsStringArray(['deriveBits']),
      )
      .toDart;

  // Derive 256 bits using PBKDF2-SHA256 with 600,000 iterations.
  final algorithm = {
    'name': 'PBKDF2',
    'hash': 'SHA-256',
    'salt': salt.toJS,
    'iterations': 600000,
  }.jsify()!;

  final derivedBits = await subtle.deriveBits(algorithm, baseKey, 256).toDart;

  return derivedBits.toDart.asUint8List();
}

/// Derive auth key using HMAC-SHA256(masterKey, "anynote-auth-key").
Future<Uint8List> deriveAuthKeyImpl(Uint8List masterKey) async {
  return _hmacSha256(masterKey, 'anynote-auth-key');
}

/// Derive encrypt key using HMAC-SHA256(masterKey, "anynote-encrypt-key").
Future<Uint8List> deriveEncryptKeyImpl(Uint8List masterKey) async {
  return _hmacSha256(masterKey, 'anynote-encrypt-key');
}

/// Derive per-item key using HMAC-SHA256(encryptKey, itemId).
Future<Uint8List> deriveItemKeyImpl(
  Uint8List encryptKey,
  String itemId,
) async {
  return _hmacSha256(encryptKey, itemId);
}

/// Hash auth key using HMAC-SHA256 for server verification.
Future<String> hashAuthKeyImpl(Uint8List authKey) async {
  final subtle = web.window.crypto.subtle;
  final emptyMessage = Uint8List(0);

  final cryptoKey = await subtle
      .importKey(
        'raw',
        authKey.toJS,
        _hmacKeyAlgorithm(),
        false,
        _jsStringArray(['sign']),
      )
      .toDart;

  final hashBuffer = await _arrayBufferFromPromise(
    subtle.sign('HMAC'.toJS, cryptoKey, emptyMessage.toJS),
  );

  return hashBuffer.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Generate a 12-word BIP-39 recovery key using WebCrypto random bytes.
Future<String> generateRecoveryKeyImpl() async {
  final entropy = Uint8List(16);
  web.window.crypto.getRandomValues(entropy.toJS);

  final checksumHash = await _sha256(entropy);
  final checksum = checksumHash[0] >> 4;

  final combined = Uint8List(17);
  combined.setRange(0, 16, entropy);
  combined[16] = (checksum << 4);

  return _encodeMnemonic(combined);
}

/// Extract entropy from a 12-word recovery key.
/// Uses SHA-256 checksum verification.
Future<Uint8List> entropyFromRecoveryKeyImpl(String recoveryKey) async {
  final words = recoveryKey.split(' ');
  if (words.length != 12) {
    throw ArgumentError(
      'Recovery key must have 12 words, got ${words.length}',
    );
  }

  final indices = words.map((w) {
    final idx = bip39Wordlist.indexOf(w.toLowerCase().trim());
    if (idx < 0) {
      throw ArgumentError('Unknown word in recovery key: "$w"');
    }
    return idx;
  }).toList();

  final bits = _indicesToBits(indices);
  final entropy = Uint8List.fromList(bits.sublist(0, 16));

  // Verify checksum using SHA-256.
  final checksumHash = await _sha256(entropy);
  final expectedChecksum = checksumHash[0] >> 4;
  final actualChecksum = (bits[16] >> 4) & 0x0F;

  if (actualChecksum != expectedChecksum) {
    throw ArgumentError('Invalid recovery key: checksum mismatch');
  }

  return entropy;
}

/// Hash for recovery salt using SHA-256.
Future<Uint8List> hashForRecoverySaltImpl(Uint8List data) async {
  return _sha256(data);
}

// ── Private helpers ────────────────────────────────────────────────

/// HMAC-SHA256(key, message) -> 32-byte result.
Future<Uint8List> _hmacSha256(Uint8List key, String info) async {
  final subtle = web.window.crypto.subtle;
  final messageBytes = Uint8List.fromList(utf8.encode(info));

  final cryptoKey = await subtle
      .importKey(
        'raw',
        key.toJS,
        _hmacKeyAlgorithm(),
        false,
        _jsStringArray(['sign']),
      )
      .toDart;

  return _arrayBufferFromPromise(
    subtle.sign('HMAC'.toJS, cryptoKey, messageBytes.toJS),
  );
}

/// SHA-256 hash.
Future<Uint8List> _sha256(Uint8List data) async {
  final subtle = web.window.crypto.subtle;
  final hashBuffer = await subtle.digest('SHA-256'.toJS, data.toJS).toDart;
  return (hashBuffer as JSArrayBuffer).toDart.asUint8List();
}

/// Encode 132 bits (17 bytes) as 12 BIP-39 words.
String _encodeMnemonic(Uint8List combined) {
  final words = <String>[];
  int bitIndex = 0;
  for (int i = 0; i < 12; i++) {
    int index = 0;
    for (int j = 0; j < 11; j++) {
      final byteIdx = (bitIndex + j) ~/ 8;
      final bitIdx = 7 - ((bitIndex + j) % 8);
      final bit = (combined[byteIdx] >> bitIdx) & 1;
      index = (index << 1) | bit;
    }
    words.add(bip39Wordlist[index]);
    bitIndex += 11;
  }
  return words.join(' ');
}

/// Reconstruct 132-bit combined array from 11-bit indices.
Uint8List _indicesToBits(List<int> indices) {
  final bits = Uint8List(17);
  int bitIndex = 0;
  for (final index in indices) {
    for (int j = 10; j >= 0; j--) {
      final bit = (index >> j) & 1;
      final byteIdx = bitIndex ~/ 8;
      final bitIdx = 7 - (bitIndex % 8);
      bits[byteIdx] |= (bit << bitIdx);
      bitIndex++;
    }
  }
  return bits;
}
