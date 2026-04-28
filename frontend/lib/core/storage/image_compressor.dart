import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Compresses images before storage to reduce disk and sync payload size.
///
/// On native platforms, uses [FlutterImageCompress] for hardware-accelerated
/// JPEG encoding. On web, returns the original bytes (web has its own image
/// handling via Blob/IndexedDB).
class ImageCompressor {
  /// Maximum image width. Images wider than this are downscaled.
  static const int maxWidth = 1920;

  /// Maximum image height. Images taller than this are downscaled.
  static const int maxHeight = 1920;

  /// JPEG quality (0-100). Higher means larger files with less artefacts.
  static const int quality = 85;

  /// Size threshold below which compression is skipped (100 KB).
  static const int skipCompressionThreshold = 100 * 1024;

  /// Compress [bytes] and return the result as [Uint8List].
  ///
  /// Parameters:
  /// - [maxWidth]: override the default maximum width.
  /// - [quality]: override the default JPEG quality.
  ///
  /// Returns the original [bytes] unchanged on web, or when the input is
  /// below [skipCompressionThreshold] bytes.
  static Future<Uint8List> compress(
    Uint8List bytes, {
    int? maxWidth,
    int? quality,
  }) async {
    // Web platform: no native compression available.
    if (kIsWeb) return bytes;

    // Skip compression for small images where the overhead of decoding and
    // re-encoding is not worth it. Also skip at the exact threshold boundary.
    if (bytes.length <= skipCompressionThreshold) return bytes;

    // On platforms where flutter_image_compress is unavailable (e.g. desktop
    // without media codec), the call may return null. In that case, return
    // the original bytes.
    final result = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: maxWidth ?? ImageCompressor.maxWidth,
      minHeight: maxHeight,
      quality: quality ?? ImageCompressor.quality,
      format: CompressFormat.jpeg,
    );

    // If compression produced a larger output (rare for very small images),
    // return the original.
    if (result.length >= bytes.length) return bytes;

    return Uint8List.fromList(result);
  }
}
