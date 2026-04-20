import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/error/exceptions.dart';

void main() {
  // ---------------------------------------------------------------------------
  // AppException base class
  // ---------------------------------------------------------------------------

  group('AppException', () {
    test('toString includes runtime type and message', () {
      const ex = NetworkException(message: 'connection lost');
      expect(ex.toString(), 'NetworkException: connection lost');
    });

    test('toString works for all subclasses', () {
      const ex = StorageException(message: 'disk full');
      expect(ex.toString(), 'StorageException: disk full');
    });

    test('stores originalError', () {
      final inner = Exception('inner');
      final ex = NetworkException(
        message: 'outer',
        originalError: inner,
      );
      expect(ex.originalError, inner);
    });

    test('code defaults to null when not provided', () {
      const ex = NetworkException(message: 'test');
      expect(ex.code, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // NetworkException
  // ---------------------------------------------------------------------------

  group('NetworkException', () {
    test('is an AppException', () {
      const ex = NetworkException(message: 'no connection');
      expect(ex, isA<AppException>());
    });

    test('stores message and code', () {
      const ex = NetworkException(
        message: 'timeout',
        code: 'network/timeout',
      );
      expect(ex.message, 'timeout');
      expect(ex.code, 'network/timeout');
    });
  });

  // ---------------------------------------------------------------------------
  // ServerException
  // ---------------------------------------------------------------------------

  group('ServerException', () {
    test('stores statusCode', () {
      const ex = ServerException(
        message: 'internal error',
        statusCode: 500,
        code: 'server/500',
      );
      expect(ex.statusCode, 500);
      expect(ex.message, 'internal error');
      expect(ex.code, 'server/500');
    });

    test('statusCode defaults to null', () {
      const ex = ServerException(message: 'error');
      expect(ex.statusCode, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // AuthException
  // ---------------------------------------------------------------------------

  group('AuthException', () {
    test('has default code auth/unauthorized', () {
      const ex = AuthException(message: 'token expired');
      expect(ex.code, 'auth/unauthorized');
    });

    test('allows custom code override', () {
      const ex = AuthException(
        message: 'invalid credentials',
        code: 'auth/invalid_credentials',
      );
      expect(ex.code, 'auth/invalid_credentials');
    });
  });

  // ---------------------------------------------------------------------------
  // ForbiddenException
  // ---------------------------------------------------------------------------

  group('ForbiddenException', () {
    test('has default code auth/forbidden', () {
      const ex = ForbiddenException(message: 'access denied');
      expect(ex.code, 'auth/forbidden');
    });
  });

  // ---------------------------------------------------------------------------
  // NotFoundException
  // ---------------------------------------------------------------------------

  group('NotFoundException', () {
    test('has default code not_found', () {
      const ex = NotFoundException(message: 'note not found');
      expect(ex.code, 'not_found');
    });
  });

  // ---------------------------------------------------------------------------
  // RateLimitException
  // ---------------------------------------------------------------------------

  group('RateLimitException', () {
    test('stores retryAfterSeconds', () {
      const ex = RateLimitException(
        message: 'too many requests',
        retryAfterSeconds: 60,
      );
      expect(ex.retryAfterSeconds, 60);
      expect(ex.code, 'rate_limit');
    });

    test('retryAfterSeconds defaults to null', () {
      const ex = RateLimitException(message: 'rate limited');
      expect(ex.retryAfterSeconds, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // ValidationException
  // ---------------------------------------------------------------------------

  group('ValidationException', () {
    test('stores fieldErrors map', () {
      const ex = ValidationException(
        message: 'invalid input',
        fieldErrors: {
          'email': 'must be a valid email',
          'password': 'must be at least 8 characters',
        },
      );
      expect(ex.fieldErrors, isNotNull);
      expect(ex.fieldErrors!['email'], 'must be a valid email');
      expect(ex.fieldErrors!['password'], 'must be at least 8 characters');
      expect(ex.code, 'validation');
    });

    test('fieldErrors defaults to null', () {
      const ex = ValidationException(message: 'bad request');
      expect(ex.fieldErrors, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // ConflictException
  // ---------------------------------------------------------------------------

  group('ConflictException', () {
    test('has default code conflict', () {
      const ex = ConflictException(message: 'version conflict');
      expect(ex.code, 'conflict');
    });
  });

  // ---------------------------------------------------------------------------
  // CryptoException hierarchy
  // ---------------------------------------------------------------------------

  group('CryptoException', () {
    test('is an AppException', () {
      const ex = CryptoException(message: 'crypto error');
      expect(ex, isA<AppException>());
    });

    test('stores custom code', () {
      const ex = CryptoException(
        message: 'failed',
        code: 'crypto/custom',
      );
      expect(ex.code, 'crypto/custom');
    });
  });

  group('CryptoLockedException', () {
    test('is a CryptoException', () {
      const ex = CryptoLockedException();
      expect(ex, isA<CryptoException>());
      expect(ex, isA<AppException>());
    });

    test('has default message and code', () {
      const ex = CryptoLockedException();
      expect(
        ex.message,
        'Encryption keys are locked. Please unlock to continue.',
      );
      expect(ex.code, 'crypto/locked');
    });

    test('allows custom message', () {
      const ex = CryptoLockedException(
        message: 'Vault is sealed',
      );
      expect(ex.message, 'Vault is sealed');
    });
  });

  group('CryptoKeyDerivationException', () {
    test('is a CryptoException', () {
      const ex = CryptoKeyDerivationException();
      expect(ex, isA<CryptoException>());
    });

    test('has default message and code', () {
      const ex = CryptoKeyDerivationException();
      expect(
        ex.message,
        'Key derivation failed. Please check your password.',
      );
      expect(ex.code, 'crypto/key_derivation');
    });
  });

  group('CryptoOperationException', () {
    test('is a CryptoException', () {
      const ex = CryptoOperationException(message: 'decryption failed');
      expect(ex, isA<CryptoException>());
    });

    test('has default code crypto/operation', () {
      const ex = CryptoOperationException(message: 'error');
      expect(ex.code, 'crypto/operation');
    });
  });

  // ---------------------------------------------------------------------------
  // SyncException hierarchy
  // ---------------------------------------------------------------------------

  group('SyncException', () {
    test('is an AppException', () {
      const ex = SyncException(message: 'sync failed');
      expect(ex, isA<AppException>());
    });
  });

  group('SyncConflictException', () {
    test('is a SyncException', () {
      const ex = SyncConflictException(message: 'conflict');
      expect(ex, isA<SyncException>());
      expect(ex, isA<AppException>());
    });

    test('stores conflictItemIds', () {
      const ex = SyncConflictException(
        message: 'manual resolution required',
        conflictItemIds: ['id-1', 'id-2', 'id-3'],
      );
      expect(ex.conflictItemIds, ['id-1', 'id-2', 'id-3']);
      expect(ex.code, 'sync/conflict');
    });

    test('conflictItemIds defaults to empty list', () {
      const ex = SyncConflictException(message: 'conflict');
      expect(ex.conflictItemIds, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // StorageException
  // ---------------------------------------------------------------------------

  group('StorageException', () {
    test('has default code storage', () {
      const ex = StorageException(message: 'db error');
      expect(ex.code, 'storage');
    });
  });

  // ---------------------------------------------------------------------------
  // UnknownException
  // ---------------------------------------------------------------------------

  group('UnknownException', () {
    test('has default code unknown', () {
      const ex = UnknownException(message: 'something unexpected');
      expect(ex.code, 'unknown');
    });
  });

  // ---------------------------------------------------------------------------
  // Inheritance hierarchy validation
  // ---------------------------------------------------------------------------

  group('Inheritance hierarchy', () {
    test('all network/http exceptions extend AppException directly', () {
      // Network layer exceptions.
      const network = NetworkException(message: 'n');
      const server = ServerException(message: 's');
      const auth = AuthException(message: 'a');
      const forbidden = ForbiddenException(message: 'f');
      const notFound = NotFoundException(message: 'nf');
      const rateLimit = RateLimitException(message: 'r');
      const validation = ValidationException(message: 'v');
      const conflict = ConflictException(message: 'c');

      for (final ex in [network, server, auth, forbidden, notFound, rateLimit, validation, conflict]) {
        expect(ex, isA<AppException>());
      }
    });

    test('crypto exceptions form correct hierarchy', () {
      const base = CryptoException(message: 'base');
      const locked = CryptoLockedException();
      const keyDerivation = CryptoKeyDerivationException();
      const operation = CryptoOperationException(message: 'op');

      expect(base, isA<AppException>());
      expect(locked, isA<CryptoException>());
      expect(keyDerivation, isA<CryptoException>());
      expect(operation, isA<CryptoException>());
    });

    test('sync exceptions form correct hierarchy', () {
      const base = SyncException(message: 'base');
      const conflict = SyncConflictException(message: 'conflict');

      expect(base, isA<AppException>());
      expect(conflict, isA<SyncException>());
    });

    test('storage and unknown extend AppException', () {
      const storage = StorageException(message: 's');
      const unknown = UnknownException(message: 'u');

      expect(storage, isA<AppException>());
      expect(unknown, isA<AppException>());
    });
  });
}
