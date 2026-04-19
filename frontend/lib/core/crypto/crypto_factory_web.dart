// Web crypto stub implementation.
//
// This file is imported on web platforms (when dart.library.html is available).
// It provides stub implementations that throw UnsupportedError because
// sodium_libs is not available on web.
//
// To fully support web, these stubs must be replaced with implementations
// that use the WebCrypto API (window.crypto.subtle). However, note that
// the wire format and algorithms would differ from native:
//   - Native uses XChaCha20-Poly1305; WebCrypto supports AES-256-GCM
//   - Native uses Argon2id; WebCrypto supports PBKDF2
//   - Native uses BLAKE2b; WebCrypto supports SHA-256/SHA-384
//
// This means data encrypted on native cannot be decrypted on web and vice
// versa unless a common algorithm (e.g., AES-256-GCM + PBKDF2) is adopted
// for both platforms.

Future<String> encryptImpl(String plaintext, List<int> itemKey) async {
  throw UnsupportedError(
    'Encryption is not supported on web. '
    'Implement WebCrypto-based encryption to enable web support.',
  );
}

Future<String> decryptImpl(String encryptedBase64, List<int> itemKey) async {
  throw UnsupportedError(
    'Decryption is not supported on web. '
    'Implement WebCrypto-based decryption to enable web support.',
  );
}

Future<List<int>> deriveItemKeyImpl(
  List<int> encryptKey,
  String itemId,
) async {
  throw UnsupportedError(
    'Key derivation is not supported on web. '
    'Implement WebCrypto-based key derivation to enable web support.',
  );
}
