import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:memories_through_lenses/services/image_utils.dart';

void main() {
  test('large camera JPEG is resized and has matching metadata', () async {
    final source = img.Image(width: 4000, height: 3000);
    final result = await ImageUtils.prepareBytes(
        Uint8List.fromList(img.encodeJpg(source)));
    final decoded = img.decodeImage(result.bytes)!;
    expect(decoded.width, 1920);
    expect(decoded.height, 1440);
    expect(result.contentType, 'image/jpeg');
  });

  test('highly compressible PNG cannot bypass dimension limit', () async {
    final source = img.Image(width: 2400, height: 3000);
    final result = await ImageUtils.prepareBytes(
        Uint8List.fromList(img.encodePng(source)));
    final decoded = img.decodeImage(result.bytes)!;
    expect(decoded.height, 1920);
    expect(decoded.width, 1536);
    expect(result.contentType, 'image/png');
  });

  test('small JPEG remains a valid image', () async {
    final source = img.Image(width: 100, height: 80);
    final result = await ImageUtils.prepareBytes(
        Uint8List.fromList(img.encodeJpg(source)));
    expect(img.decodeJpg(result.bytes)!.width, 100);
  });

  final topLeftColors = [
    [255, 0, 0],
    [0, 255, 0],
    [255, 255, 0],
    [0, 0, 255],
    [255, 0, 0],
    [0, 0, 255],
    [255, 255, 0],
    [0, 255, 0],
  ];
  for (var orientation = 1; orientation <= 8; orientation++) {
    test('EXIF orientation $orientation preserves rotation and mirroring',
        () async {
      final source = img.Image(width: 100, height: 80);
      for (var y = 0; y < 80; y++) {
        for (var x = 0; x < 100; x++) {
          final color = y < 40
              ? (x < 50 ? [255, 0, 0] : [0, 255, 0])
              : (x < 50 ? [0, 0, 255] : [255, 255, 0]);
          source.setPixelRgb(x, y, color[0], color[1], color[2]);
        }
      }
      source.exif.imageIfd.orientation = orientation;
      final result = await ImageUtils.prepareBytes(
          Uint8List.fromList(img.encodeJpg(source)));
      final decoded = img.decodeImage(result.bytes)!;
      expect(decoded.width, orientation >= 5 ? 80 : 100);
      expect(decoded.height, orientation >= 5 ? 100 : 80);
      final pixel = decoded.getPixel(10, 10);
      final expected = topLeftColors[orientation - 1];
      expect(pixel.r, closeTo(expected[0], 15));
      expect(pixel.g, closeTo(expected[1], 15));
      expect(pixel.b, closeTo(expected[2], 15));
    });
  }

  test(
      'corrupt bytes and unconverted HEIC fail instead of silent original fallback',
      () async {
    for (final bytes in [
      Uint8List.fromList([7, 7, 7]),
      Uint8List.fromList([0, 0, 0, 24, ...'ftypheic'.codeUnits, 0, 0, 0, 0]),
      Uint8List(0),
    ]) {
      await expectLater(ImageUtils.prepareBytes(bytes), throwsFormatException);
    }
  });
}
