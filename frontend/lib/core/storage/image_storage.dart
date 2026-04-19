import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Manages local storage of note images.
class ImageStorage {
  static const _imagesDir = 'note_images';

  /// Save image bytes and return the local file path.
  static Future<String> saveImage(Uint8List bytes, String noteId) async {
    final dir = await _getImagesDirectory();
    final hash = md5.convert(bytes).toString().substring(0, 12);
    final filename = '${noteId}_$hash.png';
    final file = File(p.join(dir.path, filename));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Load image from local path.
  static Future<Uint8List?> loadImage(String path) async {
    final file = File(path);
    if (await file.exists()) {
      return file.readAsBytes();
    }
    return null;
  }

  /// Delete all images for a note.
  static Future<void> deleteImagesForNote(String noteId) async {
    final dir = await _getImagesDirectory();
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File && p.basename(entity.path).startsWith(noteId)) {
        await entity.delete();
      }
    }
  }

  /// Get/create the images directory.
  static Future<Directory> _getImagesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, _imagesDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
