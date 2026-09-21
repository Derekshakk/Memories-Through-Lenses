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

  test('EXIF rotation is baked before encoding', () async {
    final source = img.Image(width: 100, height: 80);
    source.exif.imageIfd.orientation = 6;
    final result = await ImageUtils.prepareBytes(
        Uint8List.fromList(img.encodeJpg(source)));
    final decoded = img.decodeImage(result.bytes)!;
    expect(decoded.width, 80);
    expect(decoded.height, 100);
  });

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
