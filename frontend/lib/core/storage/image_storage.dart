import 'dart:io' show Directory, File
    if (dart.library.js) 'package:anynote/core/stubs/io_stub.dart';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'image_compressor.dart';
import 'web_image_storage.dart';

/// Manages local storage of note images.
///
/// On native platforms, images are stored as files in the application documents
/// directory under a `note_images` subdirectory. On web, images are stored as
/// base64 strings in SharedPreferences via [WebImageStorage].
class ImageStorage {
  static const _imagesDir = 'note_images';

  /// Save image bytes and return the local file path (native) or
  /// SharedPreferences key (web).
  ///
  /// When [compress] is true (the default), images larger than 100 KB are
  /// compressed to JPEG at 85% quality with a max dimension of 1920px before
  /// being written to disk. Pass [compress: false] to store the original
  /// bytes unmodified.
  static Future<String> saveImage(
    Uint8List bytes,
    String noteId, {
    bool compress = true,
  }) async {
    if (kIsWeb) {
      return WebImageStorage.saveWebImage(bytes, noteId);
    }

    final bytesToSave =
        compress ? await ImageCompressor.compress(bytes) : bytes;

    final dir = await _getImagesDirectory();
    final hash = md5.convert(bytesToSave).toString().substring(0, 12);
    final ext = compress && bytesToSave.length != bytes.length ? 'jpg' : 'png';
    final filename = '${noteId}_$hash.$ext';
    final file = File(p.join(dir.path, filename));
    await file.writeAsBytes(bytesToSave);
    return file.path;
  }

  /// Load image from local path (native) or SharedPreferences key (web).
  static Future<Uint8List?> loadImage(String path) async {
    if (kIsWeb) {
      return WebImageStorage.loadWebImage(path);
    }
    final file = File(path);
    if (await file.exists()) {
      return file.readAsBytes();
    }
    return null;
  }

  /// Delete all images for a note.
  static Future<void> deleteImagesForNote(String noteId) async {
    if (kIsWeb) {
      await WebImageStorage.deleteWebImagesForNote(noteId);
      return;
    }
    final dir = await _getImagesDirectory();
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File && p.basename(entity.path).startsWith(noteId)) {
        await entity.delete();
      }
    }
  }

  /// Get/create the images directory (native only).
  static Future<Directory> _getImagesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, _imagesDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
