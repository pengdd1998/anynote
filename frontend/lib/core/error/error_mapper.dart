import 'dart:io' if (dart.library.js) 'package:anynote/core/stubs/io_stub.dart';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

import 'exceptions.dart';

/// Converts raw exceptions into typed [AppException] instances.
///
/// Usage:
/// ```dart
/// try {
///   await apiClient.login(req);
/// } catch (e) {
///   final appError = ErrorMapper.map(e);
///   // appError is always an AppException
/// }
/// ```
class ErrorMapper {
  ErrorMapper._();

  /// Convert any exception to an [AppException].
  ///
  /// If [error] is already an [AppException], it is returned as-is.
  /// Known types (DioException, SocketException, StateError) are mapped
  /// to specific subclasses. Everything else becomes [UnknownException].
  static AppException map(Object error) {
    // Already classified.
    if (error is AppException) return error;

    // Dio HTTP errors.
    if (error is DioException) return _mapDioError(error);

    // Raw socket errors (can appear outside of Dio in rare cases).
    // SocketException is not available on web platform.
    if (!kIsWeb && error is SocketException) {
      return NetworkException(
        message: 'No network connection. Please check your internet settings.',
        code: 'network/socket',
        originalError: error,
      );
    }

    // Crypto service StateError -- encryption keys not unlocked.
    if (error is StateError) {
      final msg = error.message;
      if (msg.contains('CryptoService is not unlocked')) {
        return CryptoLockedException(originalError: error);
      }
      return UnknownException(
        message: msg,
        code: 'state',
        originalError: error,
      );
    }

    // Format / parse errors.
    if (error is FormatException) {
      return ValidationException(
        message: 'Invalid data format: ${error.message}',
        code: 'format',
        originalError: error,
      );
    }

    // Fallthrough.
    return UnknownException(
      message: error.toString(),
      originalError: error,
    );
  }

  /// Map a [DioException] to the most specific [AppException] available.
  static AppException _mapDioError(DioException e) {
    // Connection-level errors (no response at all).
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return NetworkException(
        message: 'Connection timed out. Please try again.',
        code: 'network/timeout',
        originalError: e,
      );
    }

    if (e.type == DioExceptionType.connectionError) {
      return NetworkException(
        message: 'Unable to reach the server. Please check your connection.',
        code: 'network/connection',
        originalError: e,
      );
    }

    if (e.type == DioExceptionType.cancel) {
      return const NetworkException(
        message: 'Request was cancelled.',
        code: 'network/cancelled',
      );
    }

    // Errors with an HTTP response.
    final statusCode = e.response?.statusCode;
    if (statusCode != null) {
      return _mapStatusCode(e, statusCode);
    }

    // Fallback for other Dio types (unknown, badResponse with no status, etc.)
    return NetworkException(
      message: e.message ?? 'An unexpected network error occurred.',
      code: 'network/unknown',
      originalError: e,
    );
  }

  /// Map an HTTP status code to a specific [AppException].
  static AppException _mapStatusCode(DioException e, int statusCode) {
    final serverMessage = _extractServerMessage(e);

    return switch (statusCode) {
      400 => ValidationException(
          message: serverMessage ?? 'Invalid request. Please check your input.',
          code: 'validation',
          originalError: e,
        ),
      401 => AuthException(
          message: serverMessage ?? 'Session expired. Please log in again.',
          originalError: e,
        ),
      403 => ForbiddenException(
          message:
              serverMessage ?? 'You do not have permission for this action.',
          originalError: e,
        ),
      404 => NotFoundException(
          message: serverMessage ?? 'The requested resource was not found.',
          originalError: e,
        ),
      409 => ConflictException(
          message: serverMessage ??
              'A conflict occurred. Please refresh and try again.',
          originalError: e,
        ),
      429 => RateLimitException(
          message: serverMessage ?? 'Too many requests. Please wait a moment.',
          retryAfterSeconds: _parseRetryAfter(e),
          originalError: e,
        ),
      _ when statusCode >= 500 && statusCode < 600 => ServerException(
          message: serverMessage ??
              'Server error ($statusCode). Please try again later.',
          statusCode: statusCode,
          code: 'server/$statusCode',
          originalError: e,
        ),
      _ => NetworkException(
          message: serverMessage ?? 'HTTP error $statusCode.',
          code: 'http/$statusCode',
          originalError: e,
        ),
    };
  }

  /// Attempt to extract a user-facing message from the Dio error response body.
  ///
  /// The backend returns errors as `{"error": {"code": "...", "message": "..."}}`
  /// or occasionally as `{"error": "message"}` or `{"message": "message"}`.
  static String? _extractServerMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final error = data['error'];
        if (error is Map<String, dynamic>) {
          return error['message'] as String?;
        }
        if (error is String) {
          return error;
        }
        return data['message'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('[ErrorMapper] failed to extract server message: $e');
      return null;
    }
  }

  /// Parse Retry-After header value into seconds.
  static int? _parseRetryAfter(DioException e) {
    try {
      final value = e.response?.headers.value('retry-after');
      if (value != null) return int.tryParse(value);
      return null;
    } catch (e) {
      debugPrint('[ErrorMapper] failed to parse retry-after header: $e');
      return null;
    }
  }
}
