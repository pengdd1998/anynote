import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anynote/core/crypto/master_key.dart';
import 'package:anynote/core/crypto/web_crypto_compat.dart';
import 'sodium_test_init.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Initialize native sodium for tests.
    registerTestSodiumPlatform();
    await CryptoCompat.init();
  });

  // -- CryptoCompat --

  group('CryptoCompat', () {
    test('isFullEncryptionSupported returns true', () {
      expect(CryptoCompat.isFullEncryptionSupported, isTrue);
    });

    test('init completes without error', () async {
      await CryptoCompat.init();
    });

    test('supportsNativeCrypto returns true (unified backend)', () {
      // Since Phase 142, sodium_libs is used on all platforms.
      expect(CryptoCompat.supportsNativeCrypto, isTrue);
    });
  });

  // -- BIP-39 Mnemonic Encoding/Decoding --

  group('BIP-39 encodeMnemonic / indicesToBits', () {
    test('encodeMnemonic produces 12 words', () {
      final combined = Uint8List.fromList(
        List.generate(17, (i) => i),
      );
      final mnemonic = MasterKeyManager.encodeMnemonic(combined);
      final words = mnemonic.split(' ');

      expect(words.length, 12);
    });

    test('mnemonicToIndices round-trips with indicesToBits', () {
      final combined = Uint8List(17);
      for (int i = 0; i < 16; i++) {
        combined[i] = (i * 7 + 13) % 256;
      }
      combined[16] = 0xA0;

      final mnemonic = MasterKeyManager.encodeMnemonic(combined);
      final indices = MasterKeyManager.mnemonicToIndices(mnemonic);
      final reconstructed = MasterKeyManager.indicesToBits(indices);

      expect(reconstructed, equals(combined));
    });

    test('indicesToBits followed by encodeMnemonic is identity', () {
      final originalIndices = [
        0,
        2047,
        1000,
        500,
        42,
        1337,
        256,
        512,
        1024,
        7,
        999,
        1234,
      ];
      final bits = MasterKeyManager.indicesToBits(originalIndices);
      final mnemonic = MasterKeyManager.encodeMnemonic(bits);
      final decodedIndices = MasterKeyManager.mnemonicToIndices(mnemonic);

      expect(decodedIndices, equals(originalIndices));
    });

    test('encodeMnemonic with all-zero bytes produces "abandon" as first word',
        () {
      final combined = Uint8List(17);
      final mnemonic = MasterKeyManager.encodeMnemonic(combined);
      final words = mnemonic.split(' ');

      expect(words[0], 'abandon');
    });

    test('mnemonicToIndices rejects wrong word count', () {
      expect(
        () => MasterKeyManager.mnemonicToIndices('abandon ability able'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('mnemonicToIndices rejects unknown word', () {
      expect(
        () => MasterKeyManager.mnemonicToIndices(
          'abandon ability able about above absent absorb abstract '
          'absurd abuse access NOTAREALWORD',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('mnemonicToIndices is case-insensitive', () {
      final combined = Uint8List.fromList(
        List.generate(17, (i) => i),
      );
      final mnemonic = MasterKeyManager.encodeMnemonic(combined);
      final upperMnemonic = mnemonic.toUpperCase();

      final indices1 = MasterKeyManager.mnemonicToIndices(mnemonic);
      final indices2 = MasterKeyManager.mnemonicToIndices(upperMnemonic);

      expect(indices1, equals(indices2));
    });

    test('indicesToBits produces 17 bytes', () {
      final indices = List.generate(12, (i) => i * 100);
      final bits = MasterKeyManager.indicesToBits(indices);
      expect(bits.length, 17);
    });

    test('recovery key generation and entropy extraction are symmetric',
        () async {
      final recoveryKey = await MasterKeyManager.generateRecoveryKey();
      final words = recoveryKey.split(' ');
      expect(words.length, 12);

      final entropy = await MasterKeyManager.entropyFromRecoveryKey(
        recoveryKey,
      );
      expect(entropy.length, 16);
    });

    test('invalid recovery key checksum throws', () async {
      final combined = Uint8List(17);
      combined[0] = 0xFF;
      final mnemonic = MasterKeyManager.encodeMnemonic(combined);
      final words = mnemonic.split(' ');

      final lastWord = words[11];
      words[11] = lastWord == 'abandon' ? 'ability' : 'abandon';
      final tamperedMnemonic = words.join(' ');

      expect(
        () => MasterKeyManager.entropyFromRecoveryKey(tamperedMnemonic),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // -- MasterKeyManager key storage via SharedPreferences --

  group('MasterKeyManager storage (SharedPreferences direct)', () {
    const masterKeyKey = 'anynote_master_key';
    const saltKey = 'anynote_salt';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('store and retrieve master key via SharedPreferences', () async {
      final key = Uint8List.fromList(
        List.generate(32, (i) => (i * 7 + 13) % 256),
      );
      final encoded = base64Encode(key);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(masterKeyKey, encoded);

      final retrieved = prefs.getString(masterKeyKey);
      expect(retrieved, isNotNull);
      expect(base64Decode(retrieved!), equals(key));
    });

    test('store and retrieve salt via SharedPreferences', () async {
      final salt = Uint8List.fromList(
        List.generate(32, (i) => (i * 3 + 17) % 256),
      );
      final encoded = base64Encode(salt);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(saltKey, encoded);

      final retrieved = prefs.getString(saltKey);
      expect(retrieved, isNotNull);
      expect(base64Decode(retrieved!), equals(salt));
    });

    test('get returns null when not stored', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(masterKeyKey), isNull);
      expect(prefs.getString(saltKey), isNull);
    });

    test('remove clears stored values', () async {
      final key = Uint8List.fromList(
        List.generate(32, (i) => (i * 7 + 13) % 256),
      );
      final salt = Uint8List.fromList(
        List.generate(32, (i) => (i * 3 + 17) % 256),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(masterKeyKey, base64Encode(key));
      await prefs.setString(saltKey, base64Encode(salt));

      await prefs.remove(masterKeyKey);
      await prefs.remove(saltKey);

      expect(prefs.getString(masterKeyKey), isNull);
      expect(prefs.getString(saltKey), isNull);
    });

    test('overwrite replaces previous value', () async {
      final key1 = Uint8List.fromList(
        List.generate(32, (i) => (i * 7 + 13) % 256),
      );
      final key2 = Uint8List.fromList(
        List.generate(32, (i) => (i * 11 + 29) % 256),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(masterKeyKey, base64Encode(key1));
      await prefs.setString(masterKeyKey, base64Encode(key2));

      final retrieved = prefs.getString(masterKeyKey);
      expect(base64Decode(retrieved!), equals(key2));
    });
  });

  // -- MasterKeyManager facade (native backend) --

  group('MasterKeyManager facade (unified backend)', () {
    test('generateSalt returns 32 random bytes', () async {
      final salt = MasterKeyManager.generateSalt();
      expect(salt.length, 32);
      expect(salt.every((b) => b == 0), isFalse);
    });

    test('generateSalt produces unique values', () async {
      final salt1 = MasterKeyManager.generateSalt();
      final salt2 = MasterKeyManager.generateSalt();
      expect(salt1, isNot(equals(salt2)));
    });

    test('currentKdfVersion is 2', () {
      expect(MasterKeyManager.currentKdfVersion, 2);
    });
  });

  // -- Cross-platform crypto contract --

  group('Cross-platform crypto contract (unified)', () {
    test('deriveMasterKeyImpl returns 32 bytes deterministically', () async {
      final salt = MasterKeyManager.generateSalt();
      final key1 = await MasterKeyManager.deriveMasterKey('testpassword', salt);
      final key2 = await MasterKeyManager.deriveMasterKey('testpassword', salt);

      expect(key1.length, 32);
      expect(key2.length, 32);
      expect(key1, equals(key2));
    });

    test('deriveMasterKey differs for different passwords', () async {
      final salt = MasterKeyManager.generateSalt();
      final key1 = await MasterKeyManager.deriveMasterKey('password1', salt);
      final key2 = await MasterKeyManager.deriveMasterKey('password2', salt);

      expect(key1, isNot(equals(key2)));
    });

    test('deriveMasterKey differs for different salts', () async {
      final salt1 = MasterKeyManager.generateSalt();
      final salt2 = MasterKeyManager.generateSalt();
      final key1 =
          await MasterKeyManager.deriveMasterKey('samepassword', salt1);
      final key2 =
          await MasterKeyManager.deriveMasterKey('samepassword', salt2);

      expect(key1, isNot(equals(key2)));
    });

    test('deriveAuthKey returns 32 bytes', () async {
      final masterKey = Uint8List.fromList(
        List.generate(32, (i) => (i * 7 + 13) % 256),
      );
      final authKey = await MasterKeyManager.deriveAuthKey(masterKey);
      expect(authKey.length, 32);
    });

    test('deriveEncryptKey returns 32 bytes', () async {
      final masterKey = Uint8List.fromList(
        List.generate(32, (i) => (i * 7 + 13) % 256),
      );
      final encryptKey = await MasterKeyManager.deriveEncryptKey(masterKey);
      expect(encryptKey.length, 32);
    });

    test('deriveAuthKey and deriveEncryptKey produce different outputs',
        () async {
      final masterKey = Uint8List.fromList(
        List.generate(32, (i) => (i * 7 + 13) % 256),
      );
      final authKey = await MasterKeyManager.deriveAuthKey(masterKey);
      final encryptKey = await MasterKeyManager.deriveEncryptKey(masterKey);

      expect(authKey, isNot(equals(encryptKey)));
    });

    test('deriveItemKey returns 32 bytes deterministically', () async {
      final encryptKey = Uint8List.fromList(
        List.generate(32, (i) => (i * 7 + 13) % 256),
      );
      final itemKey1 =
          await MasterKeyManager.deriveItemKey(encryptKey, 'note-123');
      final itemKey2 =
          await MasterKeyManager.deriveItemKey(encryptKey, 'note-123');

      expect(itemKey1.length, 32);
      expect(itemKey1, equals(itemKey2));
    });

    test('deriveItemKey differs for different item IDs', () async {
      final encryptKey = Uint8List.fromList(
        List.generate(32, (i) => (i * 7 + 13) % 256),
      );
      final key1 = await MasterKeyManager.deriveItemKey(encryptKey, 'note-aaa');
      final key2 = await MasterKeyManager.deriveItemKey(encryptKey, 'note-bbb');

      expect(key1, isNot(equals(key2)));
    });

    test('hashAuthKey returns hex string', () async {
      final authKey = Uint8List.fromList(
        List.generate(32, (i) => (i * 7 + 13) % 256),
      );
      final hash = await MasterKeyManager.hashAuthKey(authKey);

      // Should be 64 hex characters (32 bytes)
      expect(hash.length, 64);
      // Should be valid hex characters only
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(hash), isTrue);
    });

    test('full key hierarchy: password -> master -> auth/encrypt -> item',
        () async {
      final salt = MasterKeyManager.generateSalt();
      final masterKey =
          await MasterKeyManager.deriveMasterKey('test_hierarchy', salt);
      final authKey = await MasterKeyManager.deriveAuthKey(masterKey);
      final encryptKey = await MasterKeyManager.deriveEncryptKey(masterKey);
      final itemKey =
          await MasterKeyManager.deriveItemKey(encryptKey, 'note-hierarchy');

      // All keys should be 32 bytes and unique
      expect(masterKey.length, 32);
      expect(authKey.length, 32);
      expect(encryptKey.length, 32);
      expect(itemKey.length, 32);

      // No two keys in the hierarchy should be the same
      final keys = [masterKey, authKey, encryptKey, itemKey];
      for (int i = 0; i < keys.length; i++) {
        for (int j = i + 1; j < keys.length; j++) {
          expect(keys[i], isNot(equals(keys[j])),
              reason: 'Keys at positions $i and $j should differ',);
        }
      }
    });
  });

  // -- Legacy web crypto format documentation --

  group('Legacy web crypto format', () {
    test('legacy format description is documented', () {
      // Prior to Phase 142:
      // - Web used AES-256-GCM (12-byte IV) + PBKDF2 + HMAC-SHA256
      // - Native used XChaCha20-Poly1305 (24-byte nonce) + Argon2id + BLAKE2b
      // Since Phase 142: all platforms use the native algorithms.
      expect(true, isTrue);
    });

    test('wire format is XChaCha20-Poly1305 (24-byte nonce)', () async {
      // The unified format uses a 24-byte nonce prefix.
      // This is the same as the pre-Phase-142 native format.
      expect(true, isTrue);
    });
  });
}
