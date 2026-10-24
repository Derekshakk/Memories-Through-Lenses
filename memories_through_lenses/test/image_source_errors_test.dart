import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:memories_through_lenses/services/image_source_errors.dart';

void main() {
  String msg(ImageSource s, String stage, Object e) =>
      imagePickErrorMessage(s, stage, e);

  test('camera errors never mention iCloud', () {
    for (final error in <Object>[
      PlatformException(code: 'camera_access_denied'),
      PlatformException(code: 'no_available_camera'),
      PlatformException(code: 'multiple_request'),
      PlatformException(code: 'invalid_image'),
      TimeoutException('slow'),
      StateError('x'),
    ]) {
      for (final stage in ['picker_camera', 'selected_file_read']) {
        expect(msg(ImageSource.camera, stage, error), isNot(contains('iCloud')),
            reason: '$error at $stage');
      }
    }
  });

  test('camera permission, missing camera and busy picker are explained', () {
    expect(
        msg(ImageSource.camera, 'picker_camera',
            PlatformException(code: 'camera_access_denied')),
        contains('Camera access is turned off'));
    expect(
        msg(ImageSource.camera, 'picker_camera',
            PlatformException(code: 'no_available_camera')),
        contains('No camera'));
    expect(
        msg(ImageSource.camera, 'picker_camera',
            PlatformException(code: 'already_active')),
        contains('Tap Camera again'));
  });

  test('gallery errors are specific; unreadable files keep the iCloud hint', () {
    expect(
        msg(ImageSource.gallery, 'picker_gallery',
            PlatformException(code: 'photo_access_denied')),
        contains('Photo library access'));
    expect(
        msg(ImageSource.gallery, 'selected_file_length',
            const FormatException('Empty or oversized photo')),
        contains('too large'));
    expect(msg(ImageSource.gallery, 'selected_file_read', TimeoutException('')),
        contains('iCloud'));
  });

  test('isPickerBusy recognises both platform codes', () {
    expect(isPickerBusy(PlatformException(code: 'already_active')), isTrue);
    expect(isPickerBusy(PlatformException(code: 'multiple_request')), isTrue);
    expect(isPickerBusy(PlatformException(code: 'camera_access_denied')),
        isFalse);
    expect(isPickerBusy(StateError('x')), isFalse);
  });
}
