import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:memories_through_lenses/services/image_utils.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mtl_image_utils_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  File writeJpeg(img.Image image, {int quality = 100}) {
    final file = File(
        '${tempDir.path}/src_${DateTime.now().microsecondsSinceEpoch}.jpg');
    file.writeAsBytesSync(img.encodeJpg(image, quality: quality));
    return file;
  }

  test('downscales an oversized image below the max dimension', () async {
    // A 4000x3000 image simulates a large phone photo.
    final large = img.Image(width: 4000, height: 3000);
    // Fill with a gradient so the JPEG is non-trivial in size.
    for (int y = 0; y < large.height; y++) {
      for (int x = 0; x < large.width; x++) {
        large.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
      }
    }
    final source = writeJpeg(large);

    final result = await ImageUtils.compressImage(source);

    // The returned file should decode to something within the max dimension.
    final decoded = img.decodeImage(await result.readAsBytes())!;
    final longestEdge =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    expect(longestEdge, lessThanOrEqualTo(ImageUtils.maxDimension));

    // And it should be smaller on disk than the original.
    expect(await result.length(), lessThan(await source.length()));
  });

  test('returns a valid image for a small image (never throws)', () async {
    final small = img.Image(width: 100, height: 100);
    final source = writeJpeg(small);

    final result = await ImageUtils.compressImage(source);

    // Whatever it returns must still be a decodable image file.
    final decoded = img.decodeImage(await result.readAsBytes());
    expect(decoded, isNotNull);
  });

  test('falls back to the original file when bytes are not an image', () async {
    final bogus = File('${tempDir.path}/not_an_image.jpg');
    await bogus.writeAsBytes(List<int>.filled(1024, 7));

    final result = await ImageUtils.compressImage(bogus);

    // Must not throw and must fall back to the original file untouched.
    expect(result.path, bogus.path);
  });
}
