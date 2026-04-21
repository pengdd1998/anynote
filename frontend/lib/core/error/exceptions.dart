/// Centralized exception hierarchy for AnyNote.
///
/// All app-level errors are represented as subclasses of [AppException].
/// Raw exceptions (DioException, StateError, etc.) should be converted via
/// [ErrorMapper] before being surfaced to the UI.
library;

/// Base exception for all app-level errors.
///
/// Subclasses provide structured error information that the UI can use to
/// display appropriate messages and recovery actions.
abstract class AppException implements Exception {
  /// Human-readable message suitable for display.
  final String message;

  /// Machine-readable error code (e.g. 'auth/token_expired').
  final String? code;

  /// The original exception that triggered this error, if any.
  final dynamic originalError;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => '$runtimeType: $message';
}

// ── Network Errors ──────────────────────────────────────

/// The device has no network connectivity or the server is unreachable.
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Server returned a 5xx error.
class ServerException extends AppException {
  final int? statusCode;

  const ServerException({
    required super.message,
    this.statusCode,
    super.code,
    super.originalError,
  });
}

/// Authentication failed (401) or token expired.
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code = 'auth/unauthorized',
    super.originalError,
  });
}

/// Access forbidden (403).
class ForbiddenException extends AppException {
  const ForbiddenException({
    required super.message,
    super.code = 'auth/forbidden',
    super.originalError,
  });
}

/// Resource not found (404).
class NotFoundException extends AppException {
  const NotFoundException({
    required super.message,
    super.code = 'not_found',
    super.originalError,
  });
}

/// Rate limit exceeded (429).
class RateLimitException extends AppException {
  /// Seconds until the rate limit resets, if known.
  final int? retryAfterSeconds;

  const RateLimitException({
    required super.message,
    this.retryAfterSeconds,
    super.code = 'rate_limit',
    super.originalError,
  });
}

/// Validation error (400) -- the request payload was rejected.
class ValidationException extends AppException {
  /// Field-level validation errors, if the server provided them.
  final Map<String, String>? fieldErrors;

  const ValidationException({
    required super.message,
    this.fieldErrors,
    super.code = 'validation',
    super.originalError,
  });
}

/// A conflicting resource state (409).
class ConflictException extends AppException {
  const ConflictException({
    required super.message,
    super.code = 'conflict',
    super.originalError,
  });
}

// ── Crypto Errors ────────────────────────────────────────

/// Base for all cryptography-related errors.
class CryptoException extends AppException {
  const CryptoException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Encryption keys are not available (user has not unlocked).
class CryptoLockedException extends CryptoException {
  const CryptoLockedException({
    super.message = 'Encryption keys are locked. Please unlock to continue.',
    super.code = 'crypto/locked',
    super.originalError,
  });
}

/// Key derivation failed (wrong password, corrupted data, etc.).
class CryptoKeyDerivationException extends CryptoException {
  const CryptoKeyDerivationException({
    super.message = 'Key derivation failed. Please check your password.',
    super.code = 'crypto/key_derivation',
    super.originalError,
  });
}

/// Encryption or decryption of a specific item failed.
class CryptoOperationException extends CryptoException {
  const CryptoOperationException({
    required super.message,
    super.code = 'crypto/operation',
    super.originalError,
  });
}

/// Decryption of a shared note failed (corrupted data, expired link, etc.).
class DecryptFailedException extends CryptoException {
  const DecryptFailedException({
    super.message = 'Failed to decrypt the shared note.',
    super.code = 'crypto/decrypt_failed',
    super.originalError,
  });
}

/// The password provided for a password-protected share is incorrect.
class IncorrectPasswordException extends CryptoException {
  const IncorrectPasswordException({
    super.message = 'Incorrect password.',
    super.code = 'crypto/incorrect_password',
    super.originalError,
  });
}

// ── Sync Errors ─────────────────────────────────────────

/// Base for all sync-related errors.
class SyncException extends AppException {
  const SyncException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// A conflict was detected during sync (LWW resolution failed or manual
/// intervention is required).
class SyncConflictException extends SyncException {
  /// Item IDs that have conflicts.
  final List<String> conflictItemIds;

  const SyncConflictException({
    required super.message,
    this.conflictItemIds = const [],
    super.code = 'sync/conflict',
    super.originalError,
  });
}

// ── Storage Errors ──────────────────────────────────────

/// Local database or secure storage operation failed.
class StorageException extends AppException {
  const StorageException({
    required super.message,
    super.code = 'storage',
    super.originalError,
  });
}

// ── Catch-all ────────────────────────────────────────────

/// An error that could not be classified into a more specific type.
class UnknownException extends AppException {
  const UnknownException({
    required super.message,
    super.code = 'unknown',
    super.originalError,
  });
}
