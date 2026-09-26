import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

import 'image_utils.dart';
import 'post_creation.dart';

class FirebasePostBackend implements PostBackend {
  FirebasePostBackend(
    this.groupId,
    this.caption, {
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseDatabase? realtime,
    http.Client Function()? clientFactory,
    this.serviceTimeout = const Duration(seconds: 15),
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _realtime = realtime ?? FirebaseDatabase.instance,
        _clientFactory = clientFactory ?? http.Client.new {
    uid = _auth.currentUser?.uid;
    post = _firestore.collection('posts').doc();
  }

  final String groupId;
  final String caption;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseDatabase _realtime;
  final http.Client Function() _clientFactory;
  final Duration serviceTimeout;
  late final String? uid;
  late final DocumentReference<Map<String, dynamic>> post;
  bool _uploadAbandoned = false;
  UploadTask? _task;
  Reference? _image;
  @override
  String get id => post.id;

  @override
  Future<void> authenticate() async {
    final user = _auth.currentUser;
    if (uid == null || user == null || user.uid != uid) {
      throw FirebaseAuthException(code: 'unauthenticated');
    }
    final token = await user.getIdToken();
    if (token == null || _auth.currentUser?.uid != uid) {
      throw FirebaseAuthException(code: 'unauthenticated');
    }
  }

  @override
  Future<void> validateGroup() async {
    if (groupId.isEmpty || groupId.contains('/')) {
      throw const FormatException('No valid group selected');
    }
    final group = await _firestore
        .collection('groups')
        .doc(groupId)
        .get(const GetOptions(source: Source.server));
    final members = group.data()?['members'];
    if (!group.exists || members is! List || !members.contains(uid)) {
      throw FirebaseException(
          plugin: 'cloud_firestore', code: 'permission-denied');
    }
  }

  @override
  Future<void> upload(PreparedImage image, PostTrace trace) async {
    _image = _storage.ref('posts/$uid/$id');
    trace.event('storage_put_data', 'start', {'bytes': image.bytes.length});
    final task = _task = _image!
        .putData(image.bytes, SettableMetadata(contentType: image.contentType));
    // timeout() cannot cancel native work. If cancellation loses a race with
    // completion, the first delete may see no object yet. Observe the original
    // task independently and delete again if it succeeds after abandonment.
    unawaited(task.then<void>((snapshot) async {
      if (!_uploadAbandoned || snapshot.state != TaskState.success) return;
      try {
        await deleteUpload().timeout(const Duration(seconds: 5));
        trace.event('storage_late_cleanup', 'success');
      } catch (error) {
        trace.event('storage_late_cleanup', 'cleanup_failed',
            {'code': PostTrace.code(error)});
      }
    }, onError: (Object _) {
      // Foreground completion handling reports this error.
    }));
    await waitForStorageUpload(task, trace);
  }

  @override
  Future<String> downloadUrl() => _image!.getDownloadURL();

  @override
  Future<void> writePost(String url) {
    if (_auth.currentUser?.uid != uid) {
      throw FirebaseAuthException(code: 'unauthenticated');
    }
    return post.set({
      'group_id': groupId,
      'user_id': uid,
      'caption': caption,
      'image_url': url,
      'likes': [],
      'dislikes': [],
      'comments': [],
      'created_at': DateTime.now(),
    });
  }

  @override
  Future<void> cancelUpload() async {
    _uploadAbandoned = true;
    final task = _task;
    if (task != null && task.snapshot.state != TaskState.success) {
      final canceled = await task.cancel();
      if (!canceled &&
          task.snapshot.state != TaskState.success &&
          task.snapshot.state != TaskState.canceled) {
        throw StateError('Storage did not confirm cancellation');
      }
    }
  }

  @override
  Future<void> deleteUpload() async {
    try {
      await _image?.delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }

  @override
  Future<void> moderate(String url, PostTrace trace) => _sideCall(
      'moderation',
      'moderation_server_url',
      {'url': url, 'user_uid': uid, 'image_name': id},
      trace,
      mustSucceed: true);

  @override
  Future<void> afterCommit(String url, PostTrace trace) => _sideCall('yearbook',
      'yearbook_server_url', {'photo_path': url, 'post_id': id}, trace);

  Future<void> _sideCall(
      String name, String config, Map<String, Object?> body, PostTrace trace,
      {bool mustSucceed = false}) async {
    http.Client? client;
    var stage = '${name}_config';
    try {
      trace.event(stage, 'start');
      final value = await _realtime.ref(config).once().timeout(serviceTimeout);
      final configured = value.snapshot.value;
      if (configured == null || configured == '') {
        trace.event(stage, 'success');
        trace.event(name, 'not_configured');
        return;
      }
      // Treat malformed configuration separately from a transport failure.
      final endpoint = configured is String ? Uri.tryParse(configured) : null;
      if (endpoint == null ||
          !['http', 'https'].contains(endpoint.scheme) ||
          endpoint.host.isEmpty ||
          endpoint.userInfo.isNotEmpty) {
        throw FirebaseException(plugin: 'post_$name', code: 'invalid-endpoint');
      }
      trace.event(stage, 'success');
      stage = '${name}_http';
      trace.event(stage, 'start');
      client = _clientFactory();
      final response = await client
          .post(endpoint,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(serviceTimeout);
      // Never log endpoint URLs, request/response bodies, or exception text:
      // they can contain image URLs with download tokens or user information.
      trace.event(stage, 'response', {'http_status': response.statusCode});
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FirebaseException(
            plugin: 'post_$name', code: 'http-${response.statusCode}');
      }
      trace.event(stage, 'success');
      if (mustSucceed) {
        stage = '${name}_response';
        trace.event(stage, 'start');
        Object? result;
        try {
          result = jsonDecode(response.body);
        } on FormatException {
          throw FirebaseException(
              plugin: 'post_moderation', code: 'invalid-response');
        }
        if (result is! Map || result['offensive'] is! bool) {
          throw FirebaseException(
              plugin: 'post_moderation', code: 'invalid-response');
        }
        if (result['offensive'] == true) {
          throw FirebaseException(plugin: 'post_moderation', code: 'rejected');
        }
        trace.event(stage, 'success');
      }
    } catch (error) {
      trace.event(stage, error is TimeoutException ? 'timeout' : 'failure',
          {'code': PostTrace.code(error)});
      if (mustSucceed) throw PostCreationFailure(stage, error);
      trace.event(name, 'skipped');
    } finally {
      client?.close();
    }
  }
}

/// The native task Future and snapshot stream can fail independently.
Future<void> waitForStorageUpload(
  UploadTask task,
  PostTrace trace, {
  Duration timeout = const Duration(minutes: 2),
  Duration cleanupTimeout = const Duration(seconds: 2),
}) async {
  final terminal = Completer<void>();
  void snapshot(TaskSnapshot value) {
    if (value.state == TaskState.success && !terminal.isCompleted) {
      terminal.complete();
    } else if ((value.state == TaskState.canceled ||
            value.state == TaskState.error) &&
        !terminal.isCompleted) {
      terminal.completeError(FirebaseException(
          plugin: 'firebase_storage',
          code: value.state == TaskState.canceled ? 'canceled' : 'unknown'));
    }
  }

  int lastPercent = -10;
  final subscription = task.snapshotEvents.listen((value) {
    final percent = value.totalBytes == 0
        ? 0
        : value.bytesTransferred * 100 ~/ value.totalBytes;
    if (percent ~/ 10 != lastPercent ~/ 10 ||
        value.state != TaskState.running) {
      trace.event('storage_progress', value.state.name, {
        'bytes': value.bytesTransferred,
        'total_bytes': value.totalBytes,
      });
      lastPercent = percent;
    }
    snapshot(value);
  }, onError: (Object error, StackTrace stack) {
    if (!terminal.isCompleted) terminal.completeError(error, stack);
  }, onDone: () {
    snapshot(task.snapshot);
    if (!terminal.isCompleted) {
      terminal.completeError(
          StateError('Storage stream closed without completion'));
    }
  });
  try {
    // Await the task, with the stream as a fallback for wrapper completers
    // that are not resolved on native stream failure/cancellation. Reading
    // the current snapshot also covers a terminal event before subscription.
    snapshot(task.snapshot);
    await Future.any<void>([
      task.then<void>((value) {
        if (value.state != TaskState.success) {
          throw FirebaseException(plugin: 'firebase_storage', code: 'canceled');
        }
      }),
      terminal.future,
    ]).timeout(timeout);
    trace.event('storage_put_data', 'success');
  } finally {
    // Listener cleanup must not hold completion hostage either.
    try {
      await subscription.cancel().timeout(cleanupTimeout);
    } catch (error) {
      trace.event(
          'storage_listener_cleanup', 'error', {'code': PostTrace.code(error)});
    }
  }
}
