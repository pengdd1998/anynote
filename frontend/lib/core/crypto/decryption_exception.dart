/// Exception thrown when AEAD decryption fails due to authentication tag
/// verification failure, tampered ciphertext, or a wrong key.
///
/// This is distinct from the "crypto service is locked" case, which returns
/// null from [decryptForItem] instead of throwing.
class DecryptionException implements Exception {
  /// Human-readable description of the failure.
  final String message;

  /// The underlying cause, if available.
  final Object? cause;

  const DecryptionException(this.message, {this.cause});

  @override
  String toString() => 'DecryptionException: $message';
}
