import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Client-side image resizing/compression helpers.
///
/// iOS camera photos and full-resolution library images are frequently
/// 5-15 MB. Uploading them untouched is the main reason posts felt slow or
/// looked "stuck" on poor connections. These helpers shrink the longest edge
/// and re-encode as JPEG at a reasonable quality before upload while keeping
/// the photo looking good.
class ImageUtils {
  /// Longest edge (in pixels) allowed before we downscale.
  static const int maxDimension = 1920;

  /// JPEG quality used when re-encoding (0-100). 85 keeps photos looking good
  /// while dramatically reducing file size.
  static const int jpegQuality = 85;

  /// Returns a compressed/resized copy of [file], or the original [file] if
  /// compression fails or does not make the file smaller.
  ///
  /// Runs the CPU-heavy decode/resize/encode work on a background isolate via
  /// [compute] so the UI thread never janks. Never throws — on any failure it
  /// safely falls back to the original file so a post can still be uploaded.
  static Future<File> compressImage(File file) async {
    try {
      final Uint8List originalBytes = await file.readAsBytes();
      final Uint8List? compressed =
          await compute(_compressBytes, originalBytes);

      if (compressed == null || compressed.isEmpty) {
        return file;
      }

      // Only bother writing/using the compressed version if it is actually
      // smaller than the original.
      if (compressed.length >= originalBytes.length) {
        return file;
      }

      final String targetPath =
          '${file.parent.path}/mtl_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File out = File(targetPath);
      await out.writeAsBytes(compressed, flush: true);
      return out;
    } catch (e) {
      if (kDebugMode) print('Image compression failed, using original: $e');
      return file;
    }
  }

  /// Pure function (safe to run in an isolate): decode, downscale if needed,
  /// and re-encode as JPEG. Returns null if the bytes cannot be decoded.
  static Uint8List? _compressBytes(Uint8List bytes) {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    img.Image working = decoded;
    final int longestEdge =
        decoded.width > decoded.height ? decoded.width : decoded.height;

    if (longestEdge > maxDimension) {
      if (decoded.width >= decoded.height) {
        working = img.copyResize(decoded, width: maxDimension);
      } else {
        working = img.copyResize(decoded, height: maxDimension);
      }
    }

    return Uint8List.fromList(img.encodeJpg(working, quality: jpegQuality));
  }
}
