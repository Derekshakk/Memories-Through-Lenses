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
  FirebasePostBackend(this.groupId, this.caption)
      : uid = FirebaseAuth.instance.currentUser?.uid,
        post = FirebaseFirestore.instance.collection('posts').doc();

  final String groupId;
  final String caption;
  final String? uid;
  final DocumentReference<Map<String, dynamic>> post;
  UploadTask? _task;
  Reference? _image;
  @override
  String get id => post.id;

  @override
  Future<void> authenticate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (uid == null || user == null || user.uid != uid) {
      throw FirebaseAuthException(code: 'unauthenticated');
    }
    final token = await user.getIdToken();
    if (token == null || FirebaseAuth.instance.currentUser?.uid != uid) {
      throw FirebaseAuthException(code: 'unauthenticated');
    }
  }

  @override
  Future<void> validateGroup() async {
    if (groupId.isEmpty || groupId.contains('/')) {
      throw const FormatException('No valid group selected');
    }
    final group = await FirebaseFirestore.instance
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
    _image = FirebaseStorage.instance.ref('posts/$uid/$id');
    trace.event('storage_put_data', 'start', {'bytes': image.bytes.length});
    final task = _task = _image!
        .putData(image.bytes, SettableMetadata(contentType: image.contentType));
    await waitForStorageUpload(task, trace);
  }

  @override
  Future<String> downloadUrl() => _image!.getDownloadURL();

  @override
  Future<void> writePost(String url) {
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
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
    final task = _task;
    if (task != null && task.snapshot.state != TaskState.success) {
      await task.cancel();
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
    final client = http.Client();
    try {
      trace.event('${name}_config', 'start');
      final value = await FirebaseDatabase.instance
          .ref(config)
          .once()
          .timeout(const Duration(seconds: 15));
      trace.event('${name}_config', 'success');
      final url = value.snapshot.value?.toString();
      if (url == null || url.isEmpty) {
        trace.event(name, 'not_configured');
        return;
      }
      trace.event('${name}_http', 'start');
      final response = await client
          .post(Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      trace.event(
          '${name}_http',
          response.statusCode >= 200 && response.statusCode < 300
              ? 'success'
              : 'failed',
          {'http_status': response.statusCode});
      if (mustSucceed) {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw FirebaseException(
              plugin: 'post_moderation', code: 'http-${response.statusCode}');
        }
        final result = jsonDecode(response.body);
        if (result is! Map || result['offensive'] is! bool) {
          throw FirebaseException(
              plugin: 'post_moderation', code: 'invalid-response');
        }
        if (result['offensive'] == true) {
          throw FirebaseException(plugin: 'post_moderation', code: 'rejected');
        }
      }
    } catch (error) {
      trace.event(name, mustSucceed ? 'failed' : 'skipped',
          {'code': PostTrace.code(error)});
      if (mustSucceed) rethrow;
    } finally {
      client.close();
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
    } else if (value.state == TaskState.canceled && !terminal.isCompleted) {
      terminal.completeError(
          FirebaseException(plugin: 'firebase_storage', code: 'canceled'));
    }
  }

  int lastPercent = -1;
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
