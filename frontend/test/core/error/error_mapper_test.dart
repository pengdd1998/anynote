import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/error/error_mapper.dart';
import 'package:anynote/core/error/exceptions.dart';

void main() {
  group('ErrorMapper.map', () {
    test('returns AppException as-is', () {
      const original = NetworkException(
        message: 'already classified',
        code: 'test',
      );
      final result = ErrorMapper.map(original);
      expect(identical(result, original), isTrue);
    });

    test('maps StateError about CryptoService to CryptoLockedException', () {
      final error = StateError('CryptoService is not unlocked. Call unlock() first.');
      final result = ErrorMapper.map(error);

      expect(result, isA<CryptoLockedException>());
      expect(result.originalError, error);
    });

    test('maps generic StateError to UnknownException', () {
      final error = StateError('Some other state issue');
      final result = ErrorMapper.map(error);

      expect(result, isA<UnknownException>());
      expect(result.code, 'state');
      expect(result.originalError, error);
    });

    test('maps FormatException to ValidationException', () {
      const error = FormatException('Unexpected character');
      final result = ErrorMapper.map(error);

      expect(result, isA<ValidationException>());
      expect(result.message, contains('Unexpected character'));
      expect(result.code, 'format');
      expect(result.originalError, error);
    });

    test('maps unknown exception to UnknownException', () {
      final error = Exception('something went wrong');
      final result = ErrorMapper.map(error);

      expect(result, isA<UnknownException>());
      expect(result.originalError, error);
    });

    test('maps ArgumentError to UnknownException', () {
      final error = ArgumentError('bad argument');
      final result = ErrorMapper.map(error);

      expect(result, isA<UnknownException>());
      expect(result.originalError, error);
    });

    test('maps RangeError to UnknownException', () {
      final error = RangeError('out of range');
      final result = ErrorMapper.map(error);

      expect(result, isA<UnknownException>());
    });

    // -- SocketException tests --
    // Note: SocketException mapping is guarded by !kIsWeb. In test context
    // kIsWeb is false, so SocketException should be mapped.
    test('maps SocketException to NetworkException', () {
      const error = SocketException('Connection refused');
      final result = ErrorMapper.map(error);

      expect(result, isA<NetworkException>());
      expect(result.message, contains('No network connection'));
      expect(result.code, 'network/socket');
      expect(result.originalError, error);
    });

    test('maps SocketException with empty message to NetworkException', () {
      const error = SocketException('');
      final result = ErrorMapper.map(error);

      expect(result, isA<NetworkException>());
    });
  });

  group('ErrorMapper - DioException mapping', () {
    test('maps connectionTimeout to NetworkException', () {
      final error = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(path: '/test'),
      );
      final result = ErrorMapper.map(error);

      expect(result, isA<NetworkException>());
      expect(result.message, contains('timed out'));
      expect(result.code, 'network/timeout');
    });

    test('maps sendTimeout to NetworkException', () {
      final error = DioException(
        type: DioExceptionType.sendTimeout,
        requestOptions: RequestOptions(path: '/test'),
      );
      final result = ErrorMapper.map(error);

      expect(result, isA<NetworkException>());
      expect(result.code, 'network/timeout');
    });

    test('maps receiveTimeout to NetworkException', () {
      final error = DioException(
        type: DioExceptionType.receiveTimeout,
        requestOptions: RequestOptions(path: '/test'),
      );
      final result = ErrorMapper.map(error);

      expect(result, isA<NetworkException>());
      expect(result.code, 'network/timeout');
    });

    test('maps connectionError to NetworkException', () {
      final error = DioException(
        type: DioExceptionType.connectionError,
        requestOptions: RequestOptions(path: '/test'),
      );
      final result = ErrorMapper.map(error);

      expect(result, isA<NetworkException>());
      expect(result.message, contains('Unable to reach the server'));
      expect(result.code, 'network/connection');
    });

    test('maps cancel to NetworkException', () {
      final error = DioException(
        type: DioExceptionType.cancel,
        requestOptions: RequestOptions(path: '/test'),
      );
      final result = ErrorMapper.map(error);

      expect(result, isA<NetworkException>());
      expect(result.message, contains('cancelled'));
      expect(result.code, 'network/cancelled');
      expect(result.originalError, isNull);
    });

    test('maps 400 to ValidationException', () {
      final error = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 400,
        ),
      );
      final result = ErrorMapper.map(error);

      expect(result, isA<ValidationException>());
      expect(result.code, 'validation');
    });

    test('maps 400 with server error message', () {
      final error = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 400,
          data: {'error': 'Username is required'},
        ),
      );
      final result = ErrorMapper.map(error);

      expect(result, isA<ValidationException>());
      expect(result.message, 'Username is required');
    });

    test('maps 401 to AuthException', () {
      final error = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 401,
        ),
      );
      final result = ErrorMapper.map(error);

      expect(result, isA<AuthException>());
      expect(result.message, contains('Session expired'));
    });

    test('maps 401 with custom server message', () {
      final error = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 401,
          data: {'message': 'Token has been revoked'},
        ),
      );
      final result = ErrorMapper.map(error);

      expect(result, isA<AuthException>());
      expect(result.message, 'Token has been revoked');
    });

    test('maps 403 to ForbiddenException', () {
      final error = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 403,
        ),
      );
      final result = ErrorMapper.map(error);

      expect(result, isA<ForbiddenException>());
      expect(result.message, contains('permission'));
    });

    test('maps 404 to NotFoundException', () {
      final error = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 404,
        ),
      );
      final result = ErrorMapper.map(error);

      expect(result, isA<NotFoundException>());
    });

    test('maps 409 to ConflictException', () {
      final error = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 409,
        ),
      );
      final result = ErrorMapper.map(error);

      expect(result, isA<ConflictException>());
    });

    test('maps 429 to RateLimitException', () {
      final error = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 429,
          headers: Headers.fromMap({
            'retry-after': ['30'],
          }),
        ),
      );
      final result = ErrorMapper.map(error);

      expect(result, isA<RateLimitException>());
      final rateLimit = result as RateLimitException;
      expect(rateLimit.retryAfterSeconds, 30);
    });

    test('maps 429 without Retry-After header', () {
      final error = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 429,
        ),
      );
      final result = ErrorMapper.map(error);

      expect(result, isA<RateLimitException>());
      final rateLimit = result as RateLimitException;
      expect(rateLimit.retryAfterSeconds, isNull);
    });

    test('maps 500 to ServerException', () {
      final error = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 500,
        ),
      );
      final result = ErrorMapper.map(error);

      expect(result, isA<ServerException>());
      final serverEx = result as ServerException;
      expect(serverEx.statusCode, 500);
      expect(serverEx.code, 'server/500');
    });

    test('maps 502 to ServerException', () {
      final error = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 502,
        ),
      );
      final result = ErrorMapper.map(error);

      expect(result, isA<ServerException>());
      final serverEx = result as ServerException;
      expect(serverEx.statusCode, 502);
    });

    test('maps 503 to ServerException', () {
      final error = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 503,
        ),
      );
      final result = ErrorMapper.map(error);

      expect(result, isA<ServerException>());
    });

    test('maps unknown status code to NetworkException', () {
      final error = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 418,
        ),
      );
      final result = ErrorMapper.map(error);

      expect(result, isA<NetworkException>());
      expect(result.code, 'http/418');
    });

    test('maps DioException with no response to NetworkException', () {
      final error = DioException(
        type: DioExceptionType.unknown,
        requestOptions: RequestOptions(path: '/test'),
        message: 'Something went wrong',
      );
      final result = ErrorMapper.map(error);

      expect(result, isA<NetworkException>());
      expect(result.code, 'network/unknown');
    });

    test('extracts server message from error key', () {
      final error = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 400,
          data: {'error': 'Field is required'},
        ),
      );
      final result = ErrorMapper.map(error);

      expect(result.message, 'Field is required');
    });

    test('extracts server message from message key', () {
      final error = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 400,
          data: {'message': 'Invalid input data'},
        ),
      );
      final result = ErrorMapper.map(error);

      expect(result.message, 'Invalid input data');
    });

    test('prefers error key over message key', () {
      final error = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 400,
          data: {'error': 'Error value', 'message': 'Message value'},
        ),
      );
      final result = ErrorMapper.map(error);

      expect(result.message, 'Error value');
    });

    test('falls back to default message when response data is not a map', () {
      final error = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 400,
          data: 'plain text error',
        ),
      );
      final result = ErrorMapper.map(error);

      expect(result, isA<ValidationException>());
      expect(result.message, contains('Invalid request'));
    });
  });

  group('ErrorMapper - exception hierarchy', () {
    test('all exception types extend AppException', () {
      final exceptions = <AppException>[
        const NetworkException(message: 'net'),
        const ServerException(message: 'srv'),
        const AuthException(message: 'auth'),
        const ForbiddenException(message: 'forbidden'),
        const NotFoundException(message: 'not found'),
        const RateLimitException(message: 'rate'),
        const ValidationException(message: 'val'),
        const ConflictException(message: 'conflict'),
        const CryptoException(message: 'crypto'),
        const CryptoLockedException(),
        const CryptoKeyDerivationException(),
        const CryptoOperationException(message: 'op'),
        const SyncException(message: 'sync'),
        const SyncConflictException(message: 'sync conflict'),
        const StorageException(message: 'storage'),
        const UnknownException(message: 'unknown'),
      ];

      for (final ex in exceptions) {
        expect(ex, isA<AppException>());
        expect(ex.message, isNotEmpty);
      }
    });

    test('AppException toString includes runtime type and message', () {
      const ex = NetworkException(message: 'connection lost');
      expect(ex.toString(), contains('NetworkException'));
      expect(ex.toString(), contains('connection lost'));
    });
  });
}
