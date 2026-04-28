/// Stub implementations of dart:io types for web compilation.
///
/// On web targets dart:io is not available. This file provides empty stubs so
/// that code guarded by kIsWeb checks can still compile. None of these stubs
/// are ever executed at runtime on web because all callers guard with
/// `if (kIsWeb) return ...` before touching File/Directory/Platform.
///
/// Usage (in the consuming file):
/// ```dart
/// import 'dart:io' if (dart.library.js) 'package:anynote/core/stubs/io_stub.dart';
/// ```
library;

// Re-export Uint8List so consuming code that references it via dart:io compiles.
export 'dart:typed_data' show Uint8List;

import 'dart:typed_data' show Uint8List;

/// Stub for dart:io [File].
///
/// All methods throw [UnsupportedError] because they should never be called
/// on web (all callers are guarded by kIsWeb).
class File {
  final String path;
  File(this.path);

  Future<bool> exists() async =>
      throw UnsupportedError('File is not available on web');

  Future<String> readAsString({dynamic encoding}) async =>
      throw UnsupportedError('File is not available on web');

  Future<Uint8List> readAsBytes() async =>
      throw UnsupportedError('File is not available on web');

  Future<File> writeAsString(String contents) async =>
      throw UnsupportedError('File is not available on web');

  Future<File> writeAsBytes(List<int> bytes) async =>
      throw UnsupportedError('File is not available on web');

  Future<int> length() async =>
      throw UnsupportedError('File is not available on web');

  Future<DateTime> lastModified() async =>
      throw UnsupportedError('File is not available on web');

  DateTime lastModifiedSync() =>
      throw UnsupportedError('File is not available on web');

  static Future<File> get(String path) async =>
      throw UnsupportedError('File is not available on web');
}

/// Stub for dart:io [Directory].
class Directory {
  final String path;
  Directory(this.path);

  Future<bool> exists() async =>
      throw UnsupportedError('Directory is not available on web');

  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) =>
      throw UnsupportedError('Directory is not available on web');
}

/// Stub for dart:io [FileSystemEntity].
class FileSystemEntity {
  final String path;
  FileSystemEntity(this.path);
}

/// Stub for dart:io [Platform].
///
/// Provides safe default values that reflect "not a native platform".
class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isLinux => false;
  static bool get isWindows => false;
  static bool get isMacOS => false;
  static bool get isFuchsia => false;
  static Map<String, String> get environment => {};
  static String get operatingSystem => 'web';
  static String get pathSeparator => '/';
}

/// Stub for dart:io [FileSystemException].
class FileSystemException implements Exception {
  final String message;
  final String? path;
  final int? osError;

  FileSystemException([this.message = '', this.path, this.osError]);

  @override
  String toString() => 'FileSystemException: $message';
}

/// Stub for dart:io [IOException].
class IOException implements Exception {
  final String? message;

  IOException([this.message]);

  @override
  String toString() => 'IOException: ${message ?? ""}';
}

/// Stub for dart:io [SocketException].
class SocketException implements IOException {
  final String message;
  final OSError? osError;
  final InternetAddress? address;
  final int? port;

  SocketException(this.message, {this.osError, this.address, this.port});

  @override
  String toString() => 'SocketException: $message';
}

/// Stub for dart:io [OSError].
class OSError {
  final String message;
  final int errorCode;

  OSError([this.message = '', this.errorCode = 0]);
}

/// Stub for dart:io [InternetAddress].
class InternetAddress {
  final String address;
  final InternetAddressType type;

  InternetAddress(this.address, [this.type = InternetAddressType.IPv4]);
}

/// Stub for dart:io [InternetAddressType].
enum InternetAddressType {
  IPv4,
  IPv6,
  any,
}

/// Stub for dart:io [HandshakeException].
class HandshakeException implements IOException {
  final String? message;

  HandshakeException([this.message]);

  @override
  String toString() => 'HandshakeException: ${message ?? ""}';
}

/// Stub for dart:io [Process].
class Process {
  final int pid;

  Process(this.pid);

  Future<int> get exitCode =>
      throw UnsupportedError('Process is not available on web');

  Stream<List<int>> get stdout =>
      throw UnsupportedError('Process is not available on web');

  Stream<List<int>> get stderr =>
      throw UnsupportedError('Process is not available on web');
}

/// Stub for dart:io [HttpStatus].
class HttpStatus {
  static int get continue_ => 100;
  static int get ok => 200;
  static int get created => 201;
  static int get badRequest => 400;
  static int get unauthorized => 401;
  static int get forbidden => 403;
  static int get notFound => 404;
  static int get conflict => 409;
  static int get internalServerError => 500;
  static int get serviceUnavailable => 503;
}

/// Stub for dart:io [HttpHeaders].
class HttpHeaders {
  static String get contentTypeHeader => 'content-type';
  static String get authorizationHeader => 'authorization';
  static String get acceptHeader => 'accept';
  static String get cacheControlHeader => 'cache-control';
}

/// Stub for dart:io [PathAccessException].
class PathAccessException extends FileSystemException {
  PathAccessException([String? message, String? path, int? osError])
      : super(message ?? '', path, osError);
}

/// Stub for dart:io [SystemTemp].
/// getTemporaryDirectory is from path_provider, not dart:io.
/// This stub exists for completeness.
// ignore: unused_element
class _SystemTemp {
  Directory get temp => Directory('');
}
