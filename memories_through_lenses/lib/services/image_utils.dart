import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'post_trace.dart';

class PreparedImage {
  const PreparedImage(this.bytes, this.contentType);
  final Uint8List bytes;
  final String contentType;
}

/// Upload bytes are owned by the submission, not a picker temporary file.
/// Decode/resize/encode runs off the UI isolate on iOS/Android. The caller
/// bounds this Future; invalid/unsupported input is never silently uploaded.
class ImageUtils {
  static const int maxDimension = 1920;
  static const int jpegQuality = 85;
  static const int maxInputBytes = 60 * 1024 * 1024;
  static const int maxPixels = 64 * 1000 * 1000;

  static Future<PreparedImage> prepareBytes(Uint8List bytes,
          {String? traceId}) =>
      compute(_prepare, (bytes, traceId));

  static PreparedImage _prepare((Uint8List, String?) request) {
    final (bytes, traceId) = request;
    final trace = traceId == null ? null : PostTrace(traceId);
    var stage = 'image_validation';
    try {
      trace?.event(stage, 'start');
      return _decode(bytes, (name, event, fields) {
        stage = name;
        trace?.event(name, event, fields);
      });
    } catch (error) {
      trace?.event(stage, 'failure', {'code': PostTrace.code(error)});
      throw const FormatException('Unsupported, corrupt or oversized image');
    }
  }

  static PreparedImage _decode(Uint8List bytes,
      void Function(String, String, Map<String, Object?>) event) {
    if (bytes.isEmpty || bytes.length > maxInputBytes) {
      throw const FormatException('Empty or oversized image');
    }
    // Inspect dimensions before allocating a full-resolution decoded image.
    final decoder = img.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (info == null || info.width * info.height > maxPixels) {
      throw const FormatException('Unsupported or oversized image');
    }
    event('image_validation', 'success', {
      'width': info.width,
      'height': info.height,
      'bytes': bytes.length,
      'decoder': decoder.runtimeType.toString(),
    });
    event('image_decode', 'start', {});
    final decoded = decoder!.decodeFrame(0);
    if (decoded == null) throw const FormatException('Image decode failed');
    event('image_decode', 'success', {});
    event('image_compression', 'start', {});
    var working = img.bakeOrientation(decoded);
    if (working.width > maxDimension || working.height > maxDimension) {
      working = working.width >= working.height
          ? img.copyResize(working,
              width: maxDimension, interpolation: img.Interpolation.average)
          : img.copyResize(working,
              height: maxDimension, interpolation: img.Interpolation.average);
    }
    final jpeg =
        Uint8List.fromList(img.encodeJpg(working, quality: jpegQuality));
    // Keep compact screenshots lossless when PNG is smaller, but still use the
    // resized/oriented image (never bypass dimension limits based on file size).
    if (decoder is img.PngDecoder) {
      final png = Uint8List.fromList(img.encodePng(working));
      if (png.length < jpeg.length) {
        event('image_compression', 'success',
            {'bytes': png.length, 'content_type': 'image/png'});
        return PreparedImage(png, 'image/png');
      }
    }
    event('image_compression', 'success',
        {'bytes': jpeg.length, 'content_type': 'image/jpeg'});
    return PreparedImage(jpeg, 'image/jpeg');
  }
}
