import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sodium_libs/sodium_libs_sumo.dart';

import 'package:anynote/core/crypto/encryptor.dart';
import 'package:anynote/core/share/share_service.dart';
import '../crypto/sodium_test_init.dart';

void main() {
  setUpAll(() async {
    registerTestSodiumPlatform();
    await SodiumSumoInit.init();
  });

  group('parseShareLink', () {
    test('parses server share URL with key fragment', () {
      const url =
          'https://api.anynote.app/api/v1/share/abc123def456#SGVsbG9LZXk';

      final result = ShareService.parseShareLink(url);

      expect(result, isNotNull);
      expect(result!.isServerShare, isTrue);
      expect(result.payload, 'abc123def456');
      expect(result.keyFragment, 'SGVsbG9LZXk');
      expect(result.isPasswordProtected, isFalse);
    });

    test('parses server share URL with password fragment', () {
      const url = 'https://api.anynote.app/api/v1/share/abc123#pwd';

      final result = ShareService.parseShareLink(url);

      expect(result, isNotNull);
      expect(result!.isServerShare, isTrue);
      expect(result.payload, 'abc123');
      expect(result.keyFragment, isNull);
      expect(result.isPasswordProtected, isTrue);
    });

    test('parses local share URL with key fragment', () {
      const url = 'anynote://share/AQIDBAUGBwgJCAoLDA0ODxAFEDETMw==#U2hhcmVLZXk=';

      final result = ShareService.parseShareLink(url);

      expect(result, isNotNull);
      expect(result!.isServerShare, isFalse);
      expect(result.payload, 'AQIDBAUGBwgJCAoLDA0ODxAFEDETMw==');
      expect(result.keyFragment, 'U2hhcmVLZXk=');
      expect(result.isPasswordProtected, isFalse);
    });

    test('parses local share URL with password fragment', () {
      const url = 'anynote://share/AQIDBAUGBwgJCAoLDA0ODxAFEDETMw==#pwd';

      final result = ShareService.parseShareLink(url);

      expect(result, isNotNull);
      expect(result!.isServerShare, isFalse);
      expect(result.keyFragment, isNull);
      expect(result.isPasswordProtected, isTrue);
    });

    test('returns null for invalid URL', () {
      const url = 'not-a-url';
      final result = ShareService.parseShareLink(url);
      expect(result, isNull);
    });

    test('returns null for empty string', () {
      final result = ShareService.parseShareLink('');
      expect(result, isNull);
    });

    test('returns null for unrelated http URL', () {
      const url = 'https://example.com/some/page';
      final result = ShareService.parseShareLink(url);
      expect(result, isNull);
    });

    test('returns null for anynote URL without share host', () {
      const url = 'anynote://other/path#key';
      final result = ShareService.parseShareLink(url);
      expect(result, isNull);
    });

    test('returns null for server share URL without ID segment', () {
      const url = 'https://api.anynote.app/api/v1/share/#key';
      final result = ShareService.parseShareLink(url);
      expect(result, isNull);
    });

    test('returns null for local share URL without payload', () {
      const url = 'anynote://share/#key';
      final result = ShareService.parseShareLink(url);
      expect(result, isNull);
    });

    test('returns null for local share URL without fragment', () {
      const url = 'anynote://share/somepayload';
      final result = ShareService.parseShareLink(url);
      expect(result, isNull);
    });

    test('handles server share URL with http scheme', () {
      const url = 'http://localhost:8080/api/v1/share/test-id#mykey';

      final result = ShareService.parseShareLink(url);

      expect(result, isNotNull);
      expect(result!.isServerShare, isTrue);
      expect(result.payload, 'test-id');
      expect(result.keyFragment, 'mykey');
    });
  });

  group('self-contained share round-trip', () {
    test('create local share and decrypt produces same content', () async {
      // Simulate the local-only share path by doing the crypto manually,
      // since createShare tries the server first and we have no mock server.
      final sodium = await SodiumSumoInit.init();

      // Generate share key
      final shareKeyBytes = sodium
          .secureRandom(sodium.crypto.aeadXChaCha20Poly1305IETF.keyBytes)
          .extractBytes();

      // Encrypt payload
      const title = 'Test Note';
      const content = 'This is a shared note with secret content.';
      final plaintext = jsonEncode({'title': title, 'content': content});
      final encryptedBase64 =
          await Encryptor.encrypt(plaintext, shareKeyBytes);

      // Encode key
      final shareKeyB64 =
          base64Url.encode(shareKeyBytes).replaceAll('=', '');

      // Simulate local payload construction (shareId + encrypted data)
      final shareIdBytes = sodium.secureRandom(16).extractBytes();
      final _ =
          base64Url.encode(shareIdBytes).replaceAll('=', '');
      final payloadBytes = <int>[
        ...shareIdBytes,
        ...base64Decode(encryptedBase64),
      ];
      final payload = base64Url.encode(Uint8List.fromList(payloadBytes));

      // Now decrypt using the same logic as decryptSharedNote
      final payloadBytesDecoded =
          base64Url.decode(base64Url.normalize(payload));
      final shareIdBytesDecoded = payloadBytesDecoded.sublist(0, 16);
      expect(shareIdBytesDecoded, equals(shareIdBytes));

      final encryptedBase64Decoded =
          base64Encode(payloadBytesDecoded.sublist(16));
      expect(encryptedBase64Decoded, encryptedBase64);

      // Decode key and decrypt
      final decodedKey =
          base64Url.decode(base64Url.normalize(shareKeyB64));
      final decrypted =
          await Encryptor.decrypt(encryptedBase64Decoded, decodedKey);
      final json = jsonDecode(decrypted) as Map<String, dynamic>;

      expect(json['title'], title);
      expect(json['content'], content);
    });

    test('different share keys produce different ciphertext', () async {
      final sodium = await SodiumSumoInit.init();

      const plaintext = '{"title":"T","content":"C"}';

      final key1 = sodium
          .secureRandom(sodium.crypto.aeadXChaCha20Poly1305IETF.keyBytes)
          .extractBytes();
      final key2 = sodium
          .secureRandom(sodium.crypto.aeadXChaCha20Poly1305IETF.keyBytes)
          .extractBytes();

      final enc1 = await Encryptor.encrypt(plaintext, key1);
      final enc2 = await Encryptor.encrypt(plaintext, key2);

      // Even with same plaintext, different keys + random nonces mean different output
      expect(enc1, isNot(equals(enc2)));

      // Each should decrypt with its own key
      expect(await Encryptor.decrypt(enc1, key1), plaintext);
      expect(await Encryptor.decrypt(enc2, key2), plaintext);
    });

    test('decrypt with wrong key fails', () async {
      final sodium = await SodiumSumoInit.init();

      const plaintext = '{"title":"Secret","content":"Hidden"}';
      final correctKey = sodium
          .secureRandom(sodium.crypto.aeadXChaCha20Poly1305IETF.keyBytes)
          .extractBytes();
      final wrongKey = sodium
          .secureRandom(sodium.crypto.aeadXChaCha20Poly1305IETF.keyBytes)
          .extractBytes();

      final encrypted = await Encryptor.encrypt(plaintext, correctKey);

      expect(
        () => Encryptor.decrypt(encrypted, wrongKey),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('password-protected share key derivation', () {
    test('Argon2id derivation from password is deterministic', () async {
      final sodium = await SodiumSumoInit.init();

      const password = 'my-share-password';
      const shareId = 'test-share-id';

      // Derive key twice with same inputs
      final pwhashSalt1 = sodium.crypto.genericHash.call(
        message: Uint8List.fromList(utf8.encode(shareId)),
        outLen: sodium.crypto.pwhash.saltBytes,
      );
      final pwhashSalt2 = sodium.crypto.genericHash.call(
        message: Uint8List.fromList(utf8.encode(shareId)),
        outLen: sodium.crypto.pwhash.saltBytes,
      );
      expect(pwhashSalt1, equals(pwhashSalt2));

      final passwordBytes = Int8List.fromList(utf8.encode(password));

      final key1 = sodium.crypto.pwhash.call(
        password: passwordBytes,
        salt: pwhashSalt1,
        outLen: 32,
        opsLimit: sodium.crypto.pwhash.opsLimitSensitive,
        memLimit: sodium.crypto.pwhash.memLimitModerate,
        alg: CryptoPwhashAlgorithm.argon2id13,
      );
      final key2 = sodium.crypto.pwhash.call(
        password: passwordBytes,
        salt: pwhashSalt1,
        outLen: 32,
        opsLimit: sodium.crypto.pwhash.opsLimitSensitive,
        memLimit: sodium.crypto.pwhash.memLimitModerate,
        alg: CryptoPwhashAlgorithm.argon2id13,
      );

      expect(key1.extractBytes(), equals(key2.extractBytes()));
      key1.dispose();
      key2.dispose();
    });

    test('different passwords produce different share keys', () async {
      final sodium = await SodiumSumoInit.init();

      const shareId = 'same-share-id';

      final pwhashSalt = sodium.crypto.genericHash.call(
        message: Uint8List.fromList(utf8.encode(shareId)),
        outLen: sodium.crypto.pwhash.saltBytes,
      );

      final key1 = sodium.crypto.pwhash.call(
        password: Int8List.fromList(utf8.encode('password-alpha')),
        salt: pwhashSalt,
        outLen: 32,
        opsLimit: sodium.crypto.pwhash.opsLimitSensitive,
        memLimit: sodium.crypto.pwhash.memLimitModerate,
        alg: CryptoPwhashAlgorithm.argon2id13,
      );
      final key2 = sodium.crypto.pwhash.call(
        password: Int8List.fromList(utf8.encode('password-beta')),
        salt: pwhashSalt,
        outLen: 32,
        opsLimit: sodium.crypto.pwhash.opsLimitSensitive,
        memLimit: sodium.crypto.pwhash.memLimitModerate,
        alg: CryptoPwhashAlgorithm.argon2id13,
      );

      expect(key1.extractBytes(), isNot(equals(key2.extractBytes())));
      key1.dispose();
      key2.dispose();
    });

    test('different share IDs produce different salts', () async {
      final sodium = await SodiumSumoInit.init();

      final salt1 = sodium.crypto.genericHash.call(
        message: Uint8List.fromList(utf8.encode('share-id-aaa')),
        outLen: sodium.crypto.pwhash.saltBytes,
      );
      final salt2 = sodium.crypto.genericHash.call(
        message: Uint8List.fromList(utf8.encode('share-id-bbb')),
        outLen: sodium.crypto.pwhash.saltBytes,
      );

      expect(salt1, isNot(equals(salt2)));
    });
  });

  group('ShareResult', () {
    test('ShareResult holds correct values for local share', () {
      final result = ShareResult(
        id: 'test-id',
        shareLink: 'anynote://share/payload#key',
        payload: 'payload',
        shareKey: 'key',
        hasPassword: false,
        isServerStored: false,
      );

      expect(result.id, 'test-id');
      expect(result.isServerStored, isFalse);
      expect(result.hasPassword, isFalse);
      expect(result.shareKey, 'key');
      expect(result.payload, 'payload');
    });

    test('ShareResult holds correct values for server share with password',
        () {
      final result = ShareResult(
        id: 'server-id',
        shareLink: 'https://api.anynote.app/api/v1/share/server-id#pwd',
        payload: '',
        shareKey: null,
        hasPassword: true,
        isServerStored: true,
        expiresAt: DateTime(2026, 5, 1),
      );

      expect(result.isServerStored, isTrue);
      expect(result.hasPassword, isTrue);
      expect(result.shareKey, isNull);
      expect(result.expiresAt, isNotNull);
    });
  });

  group('ParsedShareLink', () {
    test('ParsedShareLink defaults isServerShare to false', () {
      final parsed = ParsedShareLink(
        payload: 'test',
        keyFragment: 'key',
        isPasswordProtected: false,
      );

      expect(parsed.isServerShare, isFalse);
    });
  });

  group('hexEncode', () {
    test('encodes bytes as lowercase hex', () {
      final bytes = [0x00, 0x01, 0x0F, 0x10, 0xFF];
      expect(hexEncode(bytes), '00010f10ff');
    });

    test('encodes empty list', () {
      expect(hexEncode([]), '');
    });
  });
}
