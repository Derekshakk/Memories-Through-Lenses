import 'dart:async';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Picker error codes reported by image_picker on iOS/Android.
const _cameraDenied = {'camera_access_denied', 'camera_access_restricted'};
const _photosDenied = {'photo_access_denied', 'photo_access_restricted'};
const _busy = {'already_active', 'multiple_request'};

String? _code(Object error) => error is PlatformException ? error.code : null;

/// True when the platform refused to open the picker because a previous
/// picker session (e.g. the gallery that was just closed) is still being torn
/// down. Retrying shortly afterwards normally succeeds.
bool isPickerBusy(Object error) => _busy.contains(_code(error));

/// User-facing message for a failure while choosing or reading a photo.
///
/// [stage] is the step that failed: `picker_<source>` / `camera_handoff`
/// while the picker or camera is open, `selected_file_*` while reading the
/// returned file. Every failure used to show the iCloud hint, including
/// camera failures that have nothing to do with iCloud.
String imagePickErrorMessage(ImageSource source, String stage, Object error) {
  final code = _code(error);
  final reading = stage.startsWith('selected_file');

  if (source == ImageSource.camera) {
    if (_cameraDenied.contains(code)) {
      return 'Camera access is turned off. Allow camera access for '
          'Memories Through Lenses in Settings, then try again.';
    }
    if (code == 'no_available_camera') {
      return 'No camera is available on this device. Choose a photo from '
          'the gallery instead.';
    }
    if (_busy.contains(code)) {
      return 'The photo picker was still closing. Tap Camera again.';
    }
    if (reading) {
      return 'The photo from the camera could not be saved. Please take it '
          'again.';
    }
    if (error is TimeoutException) {
      return 'The camera took too long to respond. Please try again.';
    }
    return 'Could not open the camera. Please try again.';
  }

  if (_photosDenied.contains(code)) {
    return 'Photo library access is turned off. Allow photo access for '
        'Memories Through Lenses in Settings, then try again.';
  }
  if (_busy.contains(code)) {
    return 'The photo picker was still closing. Tap Gallery again.';
  }
  if (error is FormatException) {
    return 'This photo is empty or too large. Please choose another one.';
  }
  // Gallery-only: reading a library photo can fail when the original is
  // stored in iCloud and has not been downloaded to the device.
  return 'Could not open this photo. Try again; for an iCloud photo, '
      'download it in Photos first.';
}
