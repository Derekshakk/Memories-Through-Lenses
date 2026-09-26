import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Temporary release diagnostics. Never log captions, paths, URLs or tokens.
class PostTrace {
  PostTrace(this.id);
  final String id;
  final Stopwatch _clock = Stopwatch()..start();
  static const enabled =
      bool.fromEnvironment('POST_UPLOAD_LOGS', defaultValue: true);

  void event(String stage, String event,
      [Map<String, Object?> fields = const {}]) {
    if (!enabled) return;
    debugPrint(jsonEncode({
      'flow': 'post_upload',
      'operation': id,
      'stage': stage,
      'marker':
          '${_markers[stage] ?? stage.toUpperCase()}_${event.toUpperCase()}',
      'event': event,
      'elapsed_ms': _clock.elapsedMilliseconds,
      ...fields,
    }));
  }

  static const _markers = {
    'photo': 'PHOTO',
    'selected_file_length': 'PHOTO_LENGTH',
    'selected_file_read': 'PHOTO_BYTES_READ',
    'image_validation': 'PHOTO_VALIDATION',
    'image_decode': 'PHOTO_DECODE',
    'image_compression': 'PHOTO_COMPRESSION',
    'image_preprocessing': 'PHOTO_PREPROCESSING',
    'storage_upload': 'STORAGE_UPLOAD',
    'download_url': 'DOWNLOAD_URL',
    'firestore_write': 'POST_WRITE',
  };

  static String code(Object error) => error is FirebaseException
      ? '${error.plugin}/${error.code}'
      : error is TimeoutException
          ? 'timeout'
          : error.runtimeType.toString();
}
