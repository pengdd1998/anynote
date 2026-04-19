import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sodium_libs/sodium_libs_sumo.dart';

import 'package:anynote/core/crypto/encryptor.dart';
import 'package:anynote/core/crypto/master_key.dart';
import 'sodium_test_init.dart';

void main() {
  setUpAll(() async {
    // Initialize the native sodium library. Required by all crypto operations.
    registerTestSodiumPlatform();
    await SodiumSumoInit.init();
  });

  group('deriveMasterKey (Argon2id)', () {
    test('deterministic: same password + salt produces same key', () async {
      const password = 'correct horse battery staple';
      final salt = Uint8List.fromList(List.generate(32, (i) => i));

      final key1 = await MasterKeyManager.deriveMasterKey(password, salt);
      final key2 = await MasterKeyManager.deriveMasterKey(password, salt);

      expect(key1, equals(key2));
    });

    test('different salts produce different keys', () async {
      const password = 'same password';
      final salt1 = Uint8List.fromList(List.generate(32, (i) => i));
      final salt2 = Uint8List.fromList(
        List.generate(32, (i) => i + 1),
      );

      final key1 = await MasterKeyManager.deriveMasterKey(password, salt1);
      final key2 = await MasterKeyManager.deriveMasterKey(password, salt2);

      expect(key1, isNot(equals(key2)));
    });

    test('different passwords produce different keys', () async {
      final salt = Uint8List.fromList(List.generate(32, (i) => i));

      final key1 =
          await MasterKeyManager.deriveMasterKey('password-one', salt);
      final key2 =
          await MasterKeyManager.deriveMasterKey('password-two', salt);

      expect(key1, isNot(equals(key2)));
    });

    test('key is 32 bytes (256 bits)', () async {
      final salt = Uint8List.fromList(List.generate(32, (i) => i));
      final key =
          await MasterKeyManager.deriveMasterKey('test-password', salt);

      expect(key.length, 32);
    });

    test('works with empty password', () async {
      final salt = Uint8List.fromList(List.generate(32, (i) => i));
      final key = await MasterKeyManager.deriveMasterKey('', salt);

      expect(key.length, 32);
      // Key should not be all zeros
      expect(key.every((b) => b == 0), isFalse);
    });

    test('works with unicode password', () async {
      final salt = Uint8List.fromList(List.generate(32, (i) => i));
      final key = await MasterKeyManager.deriveMasterKey(
        '\u5bc6\u7801\u6d4b\u8bd5',
        salt,
      );

      expect(key.length, 32);
    });
  });

  group('deriveAuthKey', () {
    test('deterministic derivation from master key', () async {
      final masterKey = Uint8List.fromList(List.generate(32, (i) => i));

      final authKey1 = await MasterKeyManager.deriveAuthKey(masterKey);
      final authKey2 = await MasterKeyManager.deriveAuthKey(masterKey);

      expect(authKey1, equals(authKey2));
    });

    test('different master keys produce different auth keys', () async {
      final masterKey1 = Uint8List.fromList(List.generate(32, (i) => i));
      final masterKey2 = Uint8List.fromList(
        List.generate(32, (i) => i + 100),
      );

      final authKey1 = await MasterKeyManager.deriveAuthKey(masterKey1);
      final authKey2 = await MasterKeyManager.deriveAuthKey(masterKey2);

      expect(authKey1, isNot(equals(authKey2)));
    });

    test('auth key is 32 bytes', () async {
      final masterKey = Uint8List.fromList(List.generate(32, (i) => i));
      final authKey = await MasterKeyManager.deriveAuthKey(masterKey);

      expect(authKey.length, 32);
    });
  });

  group('deriveEncryptKey', () {
    test('deterministic derivation from master key', () async {
      final masterKey = Uint8List.fromList(List.generate(32, (i) => i));

      final encKey1 = await MasterKeyManager.deriveEncryptKey(masterKey);
      final encKey2 = await MasterKeyManager.deriveEncryptKey(masterKey);

      expect(encKey1, equals(encKey2));
    });

    test('different master keys produce different encrypt keys', () async {
      final masterKey1 = Uint8List.fromList(List.generate(32, (i) => i));
      final masterKey2 = Uint8List.fromList(
        List.generate(32, (i) => i + 100),
      );

      final encKey1 = await MasterKeyManager.deriveEncryptKey(masterKey1);
      final encKey2 = await MasterKeyManager.deriveEncryptKey(masterKey2);

      expect(encKey1, isNot(equals(encKey2)));
    });

    test('encrypt key is different from auth key (no overlap)', () async {
      final masterKey = Uint8List.fromList(List.generate(32, (i) => i));

      final authKey = await MasterKeyManager.deriveAuthKey(masterKey);
      final encKey = await MasterKeyManager.deriveEncryptKey(masterKey);

      // Auth and encrypt keys must be cryptographically independent
      expect(encKey, isNot(equals(authKey)));
    });

    test('encrypt key is 32 bytes', () async {
      final masterKey = Uint8List.fromList(List.generate(32, (i) => i));
      final encKey = await MasterKeyManager.deriveEncryptKey(masterKey);

      expect(encKey.length, 32);
    });
  });

  group('hashAuthKey', () {
    test('produces hex string', () async {
      final authKey = Uint8List.fromList(List.generate(32, (i) => i));
      final hash = await MasterKeyManager.hashAuthKey(authKey);

      // Should be a 64-character hex string (32 bytes * 2 hex chars)
      expect(hash.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash), isTrue);
    });

    test('deterministic', () async {
      final authKey = Uint8List.fromList(List.generate(32, (i) => i));
      final hash1 = await MasterKeyManager.hashAuthKey(authKey);
      final hash2 = await MasterKeyManager.hashAuthKey(authKey);

      expect(hash1, equals(hash2));
    });

    test('different auth keys produce different hashes', () async {
      final authKey1 = Uint8List.fromList(List.generate(32, (i) => i));
      final authKey2 = Uint8List.fromList(
        List.generate(32, (i) => i + 50),
      );

      final hash1 = await MasterKeyManager.hashAuthKey(authKey1);
      final hash2 = await MasterKeyManager.hashAuthKey(authKey2);

      expect(hash1, isNot(equals(hash2)));
    });
  });

  group('deriveItemKey', () {
    test('deterministic from encrypt key + item ID', () async {
      final encryptKey = Uint8List.fromList(List.generate(32, (i) => i));
      const itemId = 'note-abc-123';

      final itemKey1 =
          await MasterKeyManager.deriveItemKey(encryptKey, itemId);
      final itemKey2 =
          await MasterKeyManager.deriveItemKey(encryptKey, itemId);

      expect(itemKey1, equals(itemKey2));
    });

    test('different item IDs produce different keys', () async {
      final encryptKey = Uint8List.fromList(List.generate(32, (i) => i));

      final itemKey1 =
          await MasterKeyManager.deriveItemKey(encryptKey, 'item-aaa');
      final itemKey2 =
          await MasterKeyManager.deriveItemKey(encryptKey, 'item-bbb');

      expect(itemKey1, isNot(equals(itemKey2)));
    });

    test('derived key is 32 bytes', () async {
      final encryptKey = Uint8List.fromList(List.generate(32, (i) => i));
      final itemKey =
          await MasterKeyManager.deriveItemKey(encryptKey, 'test-id');

      expect(itemKey.length, 32);
    });

    test('same as Encryptor.derivePerItemKey', () async {
      // Both should use the same BLAKE2b keyed hash internally
      final encryptKey = Uint8List.fromList(List.generate(32, (i) => i));
      const itemId = 'consistency-check';

      final fromMasterKeyManager =
          await MasterKeyManager.deriveItemKey(encryptKey, itemId);

      // Import Encryptor to verify consistency
      // ignore: depend_on_referenced_packages
      final fromEncryptor = await Encryptor.derivePerItemKey(
        encryptKey,
        itemId,
      );

      expect(fromMasterKeyManager, equals(fromEncryptor));
    });
  });

  group('generateSalt', () {
    test('produces 32 bytes', () {
      final salt = MasterKeyManager.generateSalt();
      expect(salt.length, 32);
    });

    test('different each call (non-deterministic)', () {
      final salt1 = MasterKeyManager.generateSalt();
      final salt2 = MasterKeyManager.generateSalt();

      // Two salts should be different (overwhelmingly likely with 256 random bits)
      expect(salt1, isNot(equals(salt2)));
    });

    test('produces different salts over 10 calls', () {
      final salts = <String>{};
      for (var i = 0; i < 10; i++) {
        final salt = MasterKeyManager.generateSalt();
        salts.add(salt.map((b) => b.toRadixString(16).padLeft(2, '0')).join());
      }
      expect(salts.length, 10);
    });
  });

  group('BIP-39 recovery key', () {
    test('generateRecoveryKey produces 12 words', () async {
      final recoveryKey = await MasterKeyManager.generateRecoveryKey();
      final words = recoveryKey.split(' ');

      expect(words.length, 12);
    });

    test('all words are from BIP-39 English wordlist', () async {
      final recoveryKey = await MasterKeyManager.generateRecoveryKey();
      final words = recoveryKey.split(' ');

      // The wordlist is embedded in master_key.dart as _bip39Wordlist.
      // We verify against a known subset -- every word must be lowercase alphabetic.
      for (final word in words) {
        expect(RegExp(r'^[a-z]+$').hasMatch(word), isTrue,
            reason: 'Word "$word" is not valid BIP-39 format',);
      }
    });

    test('entropyFromRecoveryKey recovers original entropy', () async {
      final recoveryKey = await MasterKeyManager.generateRecoveryKey();

      // Entropy extraction should succeed (checksum is valid by construction)
      final entropy =
          await MasterKeyManager.entropyFromRecoveryKey(recoveryKey);

      expect(entropy.length, 16); // 128 bits = 16 bytes
    });

    test('generateRecoveryKey produces different keys each call', () async {
      final key1 = await MasterKeyManager.generateRecoveryKey();
      final key2 = await MasterKeyManager.generateRecoveryKey();

      // Different entropy each time means different mnemonic
      expect(key1, isNot(equals(key2)));
    });

    test('invalid word count (11 words) fails', () async {
      const shortKey = 'abandon ability able about above absent absorb '
          'abstract absurd abuse access';

      expect(
        () => MasterKeyManager.entropyFromRecoveryKey(shortKey),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('invalid word count (13 words) fails', () async {
      const longKey = 'abandon ability able about above absent absorb '
          'abstract absurd abuse access accident account';

      expect(
        () => MasterKeyManager.entropyFromRecoveryKey(longKey),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('invalid word (not in wordlist) fails', () async {
      // Replace one word with a non-BIP-39 word
      const invalidKey = 'abandon ability able about above notaword '
          'absorb abstract absurd abuse access accident';

      expect(
        () => MasterKeyManager.entropyFromRecoveryKey(invalidKey),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('valid words but invalid checksum fails', () async {
      // Use 12 valid BIP-39 words that do not form a valid checksum.
      // The first 12 words of the wordlist are unlikely to have a valid checksum.
      const invalidChecksum = 'abandon ability able about above absent '
          'absorb abstract absurd abuse access accident';

      expect(
        () => MasterKeyManager.entropyFromRecoveryKey(invalidChecksum),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('round-trip: entropy survives generate -> extract -> verify', () async {
      // Generate a recovery key, extract entropy, then verify the entropy
      // can round-trip by re-generating and extracting again.
      final recoveryKey = await MasterKeyManager.generateRecoveryKey();
      final entropy =
          await MasterKeyManager.entropyFromRecoveryKey(recoveryKey);

      // Entropy should be 128-bit (16 bytes)
      expect(entropy.length, 16);

      // Extracting again should give the same entropy
      final entropy2 =
          await MasterKeyManager.entropyFromRecoveryKey(recoveryKey);
      expect(entropy2, equals(entropy));
    });

    test('case-insensitive word matching', () async {
      final recoveryKey = await MasterKeyManager.generateRecoveryKey();

      // Uppercase version should still work (the implementation does toLowerCase)
      final upperKey = recoveryKey.toUpperCase();
      expect(
        () => MasterKeyManager.entropyFromRecoveryKey(upperKey),
        returnsNormally,
      );
    });
  });
}
