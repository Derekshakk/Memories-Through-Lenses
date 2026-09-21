import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'image_utils.dart';

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
      'event': event,
      'elapsed_ms': _clock.elapsedMilliseconds,
      ...fields,
    }));
  }

  static String code(Object error) => error is FirebaseException
      ? '${error.plugin}/${error.code}'
      : error is TimeoutException
          ? 'timeout'
          : error.runtimeType.toString();
}

class PostCreationFailure implements Exception {
  PostCreationFailure(this.stage, this.cause, {this.pending = false});
  final String stage;
  final Object cause;
  final bool pending;

  String get message {
    if (pending) {
      return 'The photo uploaded, but the post is not yet confirmed. '
          'Check your connection and tap Share Post to check the same post again. '
          'It may still appear; do not create another copy.';
    }
    if (cause is FormatException && stage == 'image_preprocessing') {
      return 'This photo could not be processed. Select it again or try a JPEG/PNG copy.';
    }
    if (cause is FirebaseException) {
      final code = (cause as FirebaseException).code;
      if ((cause as FirebaseException).plugin == 'post_moderation' &&
          code == 'rejected') {
        return 'This photo was not approved for posting. Please choose another photo.';
      }
      if (['unauthenticated', 'user-token-expired', 'invalid-user-token']
          .contains(code)) {
        return 'Your session changed or expired. Sign in again and retry.';
      }
      if (['permission-denied', 'unauthorized'].contains(code)) {
        return 'You do not have permission to upload to this group. Refresh your groups and retry.';
      }
    }
    final label = {
          'image_preprocessing': 'preparing your photo',
          'storage_upload': 'uploading your photo',
          'download_url': 'retrieving the uploaded photo',
          'firestore_write': 'saving your post',
          'moderation': 'checking your photo',
          'group_validation': 'checking your group',
          'auth_before_upload': 'checking your session',
          'auth_upload': 'checking your session',
          'auth_before_write': 'checking your session',
        }[stage] ??
        stage;
    return 'Could not finish $label${cause is TimeoutException ? ' (timed out)' : ''}. '
        'Check your connection and try again. If the photo is unavailable, select it again.';
  }
}

abstract class PostBackend {
  String get id;
  Future<void> authenticate();
  Future<void> validateGroup();
  Future<void> upload(PreparedImage image, PostTrace trace);
  Future<String> downloadUrl();
  Future<void> moderate(String url, PostTrace trace);
  Future<void> writePost(String url);
  Future<void> cancelUpload();
  Future<void> deleteUpload();
  Future<void> afterCommit(String url, PostTrace trace);
}

/// One immutable submission. Retain it after a write timeout: Future.timeout
/// does NOT cancel Firestore's locally queued write. Retrying observes the same
/// write, never creates a second document or deletes its still-needed image.
class PostCreation {
  PostCreation(
    this.backend,
    this.bytes, {
    Future<PreparedImage> Function(Uint8List)? prepare,
    this.stageTimeout = const Duration(seconds: 25),
    this.uploadTimeout = const Duration(minutes: 2),
    this.cleanupTimeout = const Duration(seconds: 5),
    this.moderationTimeout = const Duration(seconds: 35),
  })  : prepare = prepare ?? ImageUtils.prepareBytes,
        trace = PostTrace(backend.id);

  final PostBackend backend;
  final Uint8List bytes;
  final Future<PreparedImage> Function(Uint8List) prepare;
  final Duration stageTimeout;
  final Duration uploadTimeout;
  final Duration cleanupTimeout;
  final Duration moderationTimeout;
  final PostTrace trace;
  final Completer<void> _cancellation = Completer<void>();
  Future<void>? _active;
  Future<void>? _write;
  Future<void>? _cleanup;
  PostCreationFailure? _failure;
  bool _committed = false;
  bool _rejected = false;
  bool _uploadStarted = false;
  String _stage = 'starting';

  bool get pending => _write != null && !_committed && !_rejected;
  bool get committed => _committed;

  void cancel() {
    // A dispatched Firestore write cannot be canceled. Its observer owns any
    // eventual cleanup/indexing even if the screen has been disposed.
    if (_write == null && !_cancellation.isCompleted) {
      _cancellation.complete();
      trace.event('operation', 'cancel_requested');
    }
  }

  Future<void> submit() {
    if (_active != null) return _active!;
    if (_failure != null) return Future<void>.error(_failure!);
    final result = _run();
    _active = result;
    // Attach both handlers without introducing an unhandled error future.
    unawaited(result.then((_) {
      _active = null;
    }, onError: (Object _) {
      _active = null;
    }));
    return result;
  }

  Future<T> _step<T>(String name, Future<T> Function() action,
      {Duration? limit}) async {
    _stage = name;
    trace.event(name, 'start');
    try {
      if (_write == null && _cancellation.isCompleted) {
        throw StateError('canceled');
      }
      final work = Future<T>.sync(action);
      final result = await (_write == null
              ? Future.any<T>([
                  work,
                  _cancellation.future
                      .then<T>((_) => throw StateError('canceled'))
                ])
              : work)
          .timeout(limit ?? stageTimeout);
      trace.event(name, 'success');
      return result;
    } catch (error) {
      trace.event(name, 'error', {'code': PostTrace.code(error)});
      rethrow;
    }
  }

  Future<void> _run() async {
    try {
      if (_committed) return;
      if (_write == null) {
        await _step('auth_before_upload', backend.authenticate);
        await _step('group_validation', backend.validateGroup);
        final image = await _step('image_preprocessing', () => prepare(bytes));
        trace.event('image_preprocessing', 'prepared', {
          'input_bytes': bytes.length,
          'output_bytes': image.bytes.length,
          'content_type': image.contentType,
        });
        // The session may have changed during preprocessing.
        await _step('auth_upload', backend.authenticate);
        _uploadStarted = true;
        await _step('storage_upload', () => backend.upload(image, trace),
            limit: uploadTimeout);
        final url = await _step('download_url', backend.downloadUrl);
        // The configured moderation server can delete the image. Its outcome
        // must be known before publishing a document that references it.
        await _step('moderation', () => backend.moderate(url, trace),
            limit: moderationTimeout);
        await _step('auth_before_write', backend.authenticate);
        if (_cancellation.isCompleted) throw StateError('canceled');
        _stage = 'firestore_write';
        _write = Future<void>.sync(() => backend.writePost(url));
        unawaited(_write!.then((_) {
          _committed = true;
          trace.event('firestore_write', 'acknowledged');
          // Yearbook indexing is best-effort and does not determine whether
          // the post exists; it no longer blocks the posting UI.
          unawaited(_sideEffects(url));
        }, onError: (Object error) {
          _rejected = true;
          trace.event(
              'firestore_write', 'rejected', {'code': PostTrace.code(error)});
          unawaited(_cleanUpload());
        }));
      }
      await _step('firestore_write', () => _write!);
    } catch (error) {
      final failedStage = _stage;
      if (!pending && !_committed) await _cleanUpload();
      final failure = PostCreationFailure(failedStage, error, pending: pending);
      if (!pending) _failure = failure;
      throw failure;
    } finally {
      trace.event('operation', 'settled',
          {'committed': _committed, 'pending': pending});
    }
  }

  Future<void> _sideEffects(String url) async {
    try {
      await backend
          .afterCommit(url, trace)
          .timeout(const Duration(seconds: 35));
    } catch (error) {
      trace.event(
          'secondary_writes', 'skipped', {'code': PostTrace.code(error)});
    }
  }

  Future<void> _cleanUpload() => _cleanup ??= _performCleanup();

  Future<void> _performCleanup() async {
    if (!_uploadStarted || _committed || pending) return;
    // Cleanup must never replace the original error or stall the loading UI.
    for (final entry in {
      'storage_cancel': backend.cancelUpload,
      'storage_delete': backend.deleteUpload,
    }.entries) {
      trace.event(entry.key, 'start');
      try {
        await Future<void>.sync(entry.value).timeout(cleanupTimeout);
        trace.event(entry.key, 'success');
      } catch (error) {
        trace.event(
            entry.key, 'cleanup_failed', {'code': PostTrace.code(error)});
      }
    }
  }
}
