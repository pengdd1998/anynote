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
}
