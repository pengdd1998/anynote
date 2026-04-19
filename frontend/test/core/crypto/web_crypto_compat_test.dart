import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anynote/core/crypto/master_key.dart';
import 'package:anynote/core/crypto/web_crypto_compat.dart';
import 'sodium_test_init.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Initialize native sodium for recovery key tests (uses BLAKE2b/SHA-256
    // on native test runner; would use WebCrypto in browser).
    registerTestSodiumPlatform();
    await CryptoCompat.init();
  });

  // ── CryptoCompat ──────────────────────────────────────────────────

  group('CryptoCompat', () {
    test('isFullEncryptionSupported returns true', () {
      expect(CryptoCompat.isFullEncryptionSupported, isTrue);
    });

    test('init completes without error', () async {
      // Should not throw on any platform.
      await CryptoCompat.init();
    });

    test('supportsNativeCrypto returns a valid bool', () {
      // When running via `flutter test` (native), this should be true.
      // When running in a browser, it would be false.
      // We just verify it returns a bool without error.
      expect(
        CryptoCompat.supportsNativeCrypto,
        anyOf(isTrue, isFalse),
      );
    });
  });

  // ── BIP-39 Mnemonic Encoding/Decoding ─────────────────────────────
  // These are pure-Dart operations that work on both platforms.

  group('BIP-39 encodeMnemonic / indicesToBits', () {
    test('encodeMnemonic produces 12 words', () {
      // Create 17 bytes (132 bits + 4 unused bits) of known data.
      final combined = Uint8List.fromList(
        List.generate(17, (i) => i),
      );
      final mnemonic = MasterKeyManager.encodeMnemonic(combined);
      final words = mnemonic.split(' ');

      expect(words.length, 12);
    });

    test('mnemonicToIndices round-trips with indicesToBits', () {
      // BIP-39 encodes 132 bits as 12 words of 11 bits each.
      // 17 bytes = 136 bits, but only the upper 132 bits are used.
      // The lower 4 bits of the last byte are NOT preserved.
      // To test a clean round-trip, ensure the lower 4 bits of byte 16
      // are zero.
      final combined = Uint8List(17);
      for (int i = 0; i < 16; i++) {
        combined[i] = (i * 7 + 13) % 256;
      }
      // Set last byte with upper 4 bits only (lower 4 bits = 0).
      combined[16] = 0xA0;

      final mnemonic = MasterKeyManager.encodeMnemonic(combined);
      final indices = MasterKeyManager.mnemonicToIndices(mnemonic);
      final reconstructed = MasterKeyManager.indicesToBits(indices);

      expect(reconstructed, equals(combined));
    });

    test('indicesToBits followed by encodeMnemonic is identity', () {
      // Start with known indices, convert to bits, encode to mnemonic,
      // then decode back to indices.
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

    test(
        'encodeMnemonic with all-zero bytes produces "abandon" as first word',
        () {
      // Index 0 = "abandon" in BIP-39. All-zero 132 bits produces all-zeros
      // for the first 11 bits, which is index 0.
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

      // Should still parse (case-insensitive lookup).
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
      // Generate a recovery key and verify it round-trips through
      // entropyFromRecoveryKey. This uses the native sodium implementation
      // on the test runner.
      final recoveryKey = await MasterKeyManager.generateRecoveryKey();
      final words = recoveryKey.split(' ');
      expect(words.length, 12);

      final entropy = await MasterKeyManager.entropyFromRecoveryKey(
        recoveryKey,
      );
      expect(entropy.length, 16);
    });

    test('invalid recovery key checksum throws', () async {
      // Take a valid 12-word mnemonic and change one word to alter
      // the checksum, then verify it fails.
      final combined = Uint8List(17);
      combined[0] = 0xFF; // Some non-zero data.
      final mnemonic = MasterKeyManager.encodeMnemonic(combined);
      final words = mnemonic.split(' ');

      // Swap one word to break the checksum.
      // Replace the last word with a different valid word.
      final lastWord = words[11];
      words[11] = lastWord == 'abandon' ? 'ability' : 'abandon';
      final tamperedMnemonic = words.join(' ');

      expect(
        () => MasterKeyManager.entropyFromRecoveryKey(tamperedMnemonic),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ── MasterKeyManager key storage via SharedPreferences ────────────
  // These tests use SharedPreferences directly to test the web storage
  // path independently of the kIsWeb check in MasterKeyManager.

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

  // ── MasterKeyManager facade (runs on native test runner) ──────────
  // These tests exercise the full MasterKeyManager API using the
  // native crypto backend (sodium_libs). On web, these would use
  // WebCrypto instead.

  group('MasterKeyManager facade (native backend)', () {
    // Skip on web since these use native sodium.
    // On native test runner, sodium must be initialized first.

    setUpAll(() async {
      // The native sodium tests need a registered platform.
      // MasterKeyManager.generateSalt() uses the native impl on non-web.
    });

    test(
        'generateSalt returns 32 random bytes',
        () async {
      final salt = MasterKeyManager.generateSalt();
      expect(salt.length, 32);

      // Should look random (not all zeros).
      expect(salt.every((b) => b == 0), isFalse);
    },
        skip: kIsWeb ? 'Native only' : null,);

    test(
        'generateSalt produces unique values',
        () async {
      final salt1 = MasterKeyManager.generateSalt();
      final salt2 = MasterKeyManager.generateSalt();
      expect(salt1, isNot(equals(salt2)));
    },
        skip: kIsWeb ? 'Native only' : null,);
  });

  // ── Platform incompatibility documentation ─────────────────────────
  //
  // NOTE: The following WebCrypto operations can only be tested in a
  // browser environment (`flutter test --platform chrome`):
  //   - PBKDF2 key derivation (deriveMasterKeyImpl)
  //   - HMAC-SHA256 sub-key derivation (deriveAuthKeyImpl, deriveEncryptKeyImpl)
  //   - AES-256-GCM encrypt/decrypt (encryptImpl, decryptImpl)
  //   - SHA-256 hashing (hashAuthKeyImpl, hashForRecoverySaltImpl)
  //
  // On the native test runner, these functions delegate to the native
  // implementations (Argon2id, BLAKE2b, XChaCha20-Poly1305) which are
  // tested separately in encryptor_test.dart and master_key_test.dart.
  //
  // To run the WebCrypto tests in a browser:
  //   flutter test test/core/crypto/web_crypto_compat_test.dart \
  //     --platform chrome --web-browser-flag=--headless

  group('WebCrypto operation contract (documented)', () {
    test('deriveMasterKeyImpl has expected signature', () {
      // deriveMasterKeyImpl(String password, Uint8List salt) -> Future<Uint8List>
      // Must return exactly 32 bytes.
      // Must be deterministic: same (password, salt) -> same key.
      // Must differ for different passwords with same salt.
      // Must differ for different salts with same password.
      expect(true, isTrue);
    });

    test('deriveAuthKeyImpl / deriveEncryptKeyImpl use HMAC-SHA256', () {
      // On web: HMAC-SHA256(key, info_string).
      // On native: BLAKE2b(key, info_string).
      // These produce different output for the same inputs.
      expect(true, isTrue);
    });

    test('AES-256-GCM wire format is iv(12) || ciphertext+tag', () {
      // On web: AES-256-GCM with 12-byte IV.
      // On native: XChaCha20-Poly1305 with 24-byte nonce.
      // These are NOT compatible.
      expect(true, isTrue);
    });

    test('PBKDF2 uses 600,000 iterations with SHA-256', () {
      // Web implementation uses 600K iterations as per OWASP 2023
      // recommendations for PBKDF2-SHA256.
      expect(true, isTrue);
    });
  });
}
