import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sodium_libs/sodium_libs_sumo.dart';

import 'bip39_wordlist.dart';

// Native implementation of platform-specific crypto functions for MasterKeyManager.
// Uses sodium_libs (libsodium) for Argon2id, BLAKE2b.
// Uses package:crypto SHA-256 for BIP-39 recovery key checksums.

/// Current KDF version for native (Argon2id) key derivation.
///
/// Version history:
///   1 - opsLimitModerate (2 ops) + memLimitInteractive (32MB). Below OWASP.
///   2 - opsLimitSensitive (4 ops) + memLimitModerate (256MB). Meets OWASP
///       recommendations: 64MB+ memory, 3+ iterations, parallelism=1.
const int kdfVersionNative = 2;

/// Generate a 32-byte salt using cryptographically secure random.
Uint8List generateSaltImpl() {
  final random = Random.secure();
  final salt = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    salt[i] = random.nextInt(256);
  }
  return salt;
}

/// Derive master key using Argon2id (libsodium crypto_pwhash).
///
/// Uses OWASP-recommended parameters:
///   - opsLimit: opsLimitSensitive (4 iterations, >= OWASP minimum of 3)
///   - memLimit: memLimitModerate (256MB, >= OWASP minimum of 64MB)
///   - algorithm: Argon2id v1.3
///   - parallelism: 1 (libsodium default)
/// See: https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
Future<Uint8List> deriveMasterKeyImpl(
  String password,
  Uint8List salt, [
  int? kdfVersion,
]) async {
  final sodium = await _getSodium();

  final Uint8List pwhashSalt;
  if (salt.length == sodium.crypto.pwhash.saltBytes) {
    pwhashSalt = salt;
  } else {
    pwhashSalt = sodium.crypto.genericHash.call(
      message: salt,
      outLen: sodium.crypto.pwhash.saltBytes,
    );
  }

  final passwordBytes = Int8List.fromList(utf8.encode(password));

  // Select KDF parameters based on version.
  // Version 1 (legacy): opsLimitModerate + memLimitInteractive.
  // Version 2 (current): opsLimitSensitive + memLimitModerate (OWASP-aligned).
  final int opsLimit;
  final int memLimit;
  if (kdfVersion == null || kdfVersion >= kdfVersionNative) {
    // Current default: OWASP-aligned parameters.
    opsLimit = sodium.crypto.pwhash.opsLimitSensitive;
    memLimit = sodium.crypto.pwhash.memLimitModerate;
  } else {
    // Legacy fallback for migrating existing users.
    opsLimit = sodium.crypto.pwhash.opsLimitModerate;
    memLimit = sodium.crypto.pwhash.memLimitInteractive;
  }

  final key = sodium.crypto.pwhash.call(
    password: passwordBytes,
    salt: pwhashSalt,
    outLen: 32,
    opsLimit: opsLimit,
    memLimit: memLimit,
    alg: CryptoPwhashAlgorithm.argon2id13,
  );

  final result = key.extractBytes();
  key.dispose();
  return result;
}

/// Derive auth key using BLAKE2b(masterKey, "anynote-auth-key").
Future<Uint8List> deriveAuthKeyImpl(Uint8List masterKey) async {
  return _blake2bKeyed(masterKey, 'anynote-auth-key');
}

/// Derive encrypt key using BLAKE2b(masterKey, "anynote-encrypt-key").
Future<Uint8List> deriveEncryptKeyImpl(Uint8List masterKey) async {
  return _blake2bKeyed(masterKey, 'anynote-encrypt-key');
}

/// Derive per-item key using BLAKE2b(encryptKey, itemId).
Future<Uint8List> deriveItemKeyImpl(
  Uint8List encryptKey,
  String itemId,
) async {
  return _blake2bKeyed(encryptKey, itemId);
}

/// Hash auth key using BLAKE2b for server verification.
Future<String> hashAuthKeyImpl(Uint8List authKey) async {
  final sodium = await _getSodium();
  final key = SecureKey.fromList(sodium, authKey);

  final hash = sodium.crypto.genericHash.call(
    message: Uint8List(0),
    key: key,
    outLen: 32,
  );

  key.dispose();
  return hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Generate a 12-word BIP-39 recovery key using sodium random bytes.
///
/// Uses SHA-256 checksum per BIP-39 standard for 128-bit entropy.
/// For 128-bit entropy the checksum is the first 4 bits of SHA-256(entropy).
Future<String> generateRecoveryKeyImpl() async {
  final sodium = await _getSodium();

  final entropy = sodium.randombytes.buf(16);

  // BIP-39: checksum = first ENT/32 bits of SHA-256(entropy).
  // For 128-bit entropy: checksum = first 4 bits (high nibble of byte 0).
  final checksumHash = sha256.convert(entropy).bytes;
  final checksum = checksumHash[0] >> 4;

  final combined = Uint8List(17);
  combined.setRange(0, 16, entropy);
  combined[16] = (checksum << 4);

  return _encodeMnemonic(combined);
}

/// Extract entropy from a 12-word recovery key.
///
/// Validates the checksum using SHA-256 (BIP-39 standard).
/// Falls back to BLAKE2b (legacy) for keys generated before this fix,
/// ensuring backward compatibility with existing native recovery keys.
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
  final actualChecksum = (bits[16] >> 4) & 0x0F;

  // Verify checksum: try SHA-256 first (BIP-39 standard), then legacy BLAKE2b.
  if (!_verifyChecksum(entropy, actualChecksum)) {
    throw ArgumentError('Invalid recovery key: checksum mismatch');
  }

  return entropy;
}

/// Hash for recovery salt using BLAKE2b.
Future<Uint8List> hashForRecoverySaltImpl(Uint8List data) async {
  final sodium = await _getSodium();
  return sodium.crypto.genericHash.call(
    message: data,
    outLen: 32,
  );
}

// ── Private helpers ────────────────────────────────────────────────

/// Verify BIP-39 recovery key checksum with backward compatibility.
///
/// Tries SHA-256 first (BIP-39 standard), then falls back to BLAKE2b
/// for legacy recovery keys generated by earlier app versions that
/// used BLAKE2b instead of SHA-256.
bool _verifyChecksum(Uint8List entropy, int actualChecksum) {
  // Primary: SHA-256 checksum (BIP-39 standard).
  final sha256Checksum = sha256.convert(entropy).bytes[0] >> 4;
  if (actualChecksum == sha256Checksum) return true;

  // Legacy fallback: BLAKE2b checksum (pre-fix native keys).
  // This is synchronous but requires sodium to be already initialized
  // (it will be, since entropyFromRecoveryKeyImpl is async and the sodium
  // instance is cached after first init).
  final sodium = _sodiumInstance;
  if (sodium != null) {
    final blake2bHash = sodium.crypto.genericHash.call(
      message: entropy,
      outLen: 32,
    );
    final blake2bChecksum = blake2bHash[0] >> 4;
    if (actualChecksum == blake2bChecksum) return true;
  }

  return false;
}

/// BLAKE2b keyed hash for key derivation.
Future<Uint8List> _blake2bKeyed(
  Uint8List inputKey,
  String info,
) async {
  final sodium = await _getSodium();
  final key = SecureKey.fromList(sodium, inputKey);
  final message = Uint8List.fromList(utf8.encode(info));

  final result = sodium.crypto.genericHash.call(
    message: message,
    key: key,
    outLen: 32,
  );

  key.dispose();
  return result;
}

/// Sodium singleton.
SodiumSumo? _sodiumInstance;

Future<SodiumSumo> _getSodium() async {
  return _sodiumInstance ??= await SodiumSumoInit.init();
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
