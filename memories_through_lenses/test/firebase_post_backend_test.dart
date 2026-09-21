import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:memories_through_lenses/services/firebase_post_backend.dart';
import 'package:memories_through_lenses/services/image_utils.dart';
import 'package:memories_through_lenses/services/post_creation.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'user';
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'token';
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User? currentUser = _User();
}

// Mutable SDK test double; production references still come from Firebase.
// ignore: subtype_of_sealed_class, must_be_immutable
class _Doc extends Fake implements DocumentReference<Map<String, dynamic>> {
  Map<String, dynamic>? written;
  Map<String, dynamic>? group = {
    'members': ['user']
  };
  GetOptions? options;
  Future<void> Function()? onWrite;
  @override
  String get id => 'post-id';
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    written = data;
    await onWrite?.call();
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get(
      [GetOptions? options]) async {
    this.options = options;
    return _DocSnapshot(group);
  }
}

// SDK annotation excludes external implementations except these test doubles.
// ignore: subtype_of_sealed_class
class _DocSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _DocSnapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value;
}

// ignore: subtype_of_sealed_class
class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.document);
  final _Doc document;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => document;
}

class _Firestore extends Fake implements FirebaseFirestore {
  final post = _Doc();
  final group = _Doc();
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(path == 'posts' ? post : group);
}

class _Snapshot extends Fake implements TaskSnapshot {
  _Snapshot(this.state);
  @override
  final TaskState state;
  @override
  int get bytesTransferred => state == TaskState.success ? 10 : 0;
  @override
  int get totalBytes => 10;
}

class _Task extends Fake implements UploadTask {
  final events = StreamController<TaskSnapshot>.broadcast();
  final completion = Completer<TaskSnapshot>();
  Future<bool> Function()? onCancel;
  @override
  TaskSnapshot snapshot = _Snapshot(TaskState.running);
  @override
  Stream<TaskSnapshot> get snapshotEvents => events.stream;
  @override
  Future<T> then<T>(FutureOr<T> Function(TaskSnapshot) onValue,
          {Function? onError}) =>
      completion.future.then(onValue, onError: onError);
  @override
  Future<bool> cancel() async => await onCancel?.call() ?? true;
  void finish() {
    snapshot = _Snapshot(TaskState.success);
    events.add(snapshot);
    completion.complete(snapshot);
  }
}

class _Reference extends Fake implements Reference {
  final task = _Task();
  Uint8List? data;
  SettableMetadata? metadata;
  int deletes = 0;
  Future<String> Function()? onUrl;
  Future<void> Function()? onDelete;
  @override
  UploadTask putData(Uint8List data, [SettableMetadata? metadata]) {
    this.data = data;
    this.metadata = metadata;
    return task;
  }

  @override
  Future<String> getDownloadURL() async =>
      await onUrl?.call() ?? 'https://photo.example/image';
  @override
  Future<void> delete() async {
    deletes++;
    await onDelete?.call();
  }
}

class _Storage extends Fake implements FirebaseStorage {
  final image = _Reference();
  String? path;
  @override
  Reference ref([String? path]) {
    this.path = path;
    return image;
  }
}

class _Data extends Fake implements DataSnapshot {
  _Data(this.value);
  @override
  final Object? value;
}

class _Event extends Fake implements DatabaseEvent {
  _Event(Object? value) : snapshot = _Data(value);
  @override
  final DataSnapshot snapshot;
}

class _ConfigRef extends Fake implements DatabaseReference {
  _ConfigRef(this.value);
  final Object? value;
  @override
  Future<DatabaseEvent> once(
          [DatabaseEventType eventType = DatabaseEventType.value]) async =>
      _Event(value);
}

class _Realtime extends Fake implements FirebaseDatabase {
  final config = <String, Object?>{};
  @override
  DatabaseReference ref([String? path]) => _ConfigRef(config[path]);
}

class _Client extends MockClient {
  _Client(super.fn);
  bool closed = false;
  @override
  void close() {
    closed = true;
    super.close();
  }
}

void main() {
  late _Auth auth;
  late _Firestore db;
  late _Storage storage;
  late _Realtime realtime;
  late _Client client;
  late FirebasePostBackend backend;
  late PostTrace trace;
  setUp(() {
    auth = _Auth();
    db = _Firestore();
    storage = _Storage();
    realtime = _Realtime();
    client = _Client((_) async => http.Response('{"offensive":false}', 200));
    backend = FirebasePostBackend('group', 'caption',
        auth: auth,
        firestore: db,
        storage: storage,
        realtime: realtime,
        clientFactory: () => client);
    trace = PostTrace(backend.id);
  });
  tearDown(() async {
    // Settle native fakes even when the foreground operation has timed out.
    await storage.image.task.events.close();
  });
  final bytes = Uint8List.fromList([1, 2, 3]);
  Future<void> upload() async {
    final result = backend.upload(PreparedImage(bytes, 'image/png'), trace);
    storage.image.task.finish();
    await result;
  }

  PostCreation operation() => PostCreation(backend, bytes,
      prepare: (data) async => PreparedImage(data, 'image/png'),
      stageTimeout: const Duration(milliseconds: 30),
      uploadTimeout: const Duration(milliseconds: 30),
      cleanupTimeout: const Duration(milliseconds: 5));

  test('actual adapter uploads owned bytes with matching path and MIME type',
      () async {
    await upload();
    expect(storage.path, 'posts/user/post-id');
    expect(storage.image.data, bytes);
    expect(storage.image.metadata!.contentType, 'image/png');
    expect(await backend.downloadUrl(), 'https://photo.example/image');
  });
  test('post schema remains compatible with feeds, comments and yearbook',
      () async {
    await backend.writePost('https://photo.example/image');
    expect(
        db.post.written!.keys,
        unorderedEquals([
          'group_id',
          'user_id',
          'caption',
          'image_url',
          'likes',
          'dislikes',
          'comments',
          'created_at'
        ]));
    expect(db.post.written!['group_id'], 'group');
    expect(db.post.written!['user_id'], 'user');
    expect(db.post.written!['image_url'], 'https://photo.example/image');
    expect(db.post.written!['likes'], isEmpty);
    expect(db.post.written!['comments'], isEmpty);
    expect(db.post.written!['created_at'], isA<DateTime>());
  });
  test('sign-out between validation and database dispatch is rejected',
      () async {
    await backend.authenticate();
    auth.currentUser = null;
    await expectLater(
        backend.authenticate(), throwsA(isA<FirebaseAuthException>()));
    expect(
        () => backend.writePost('url'), throwsA(isA<FirebaseAuthException>()));
    expect(db.post.written, isNull);
  });
  for (final group in [
    null,
    <String, dynamic>{},
    <String, dynamic>{
      'members': ['other']
    }
  ]) {
    test('missing or stale group $group is rejected from a server read',
        () async {
      db.group.group = group;
      await expectLater(
          backend.validateGroup(), throwsA(isA<FirebaseException>()));
      expect(db.group.options!.source, Source.server);
    });
  }
  for (final body in ['{"offensive":true}', '{}', 'not json']) {
    test('moderation rejects $body and always closes HTTP client', () async {
      realtime.config['moderation_server_url'] =
          'https://moderation.example/predict';
      client = _Client((_) async => http.Response(body, 200));
      await expectLater(
          backend.moderate('url', trace), throwsA(isA<Exception>()));
      expect(client.closed, isTrue);
    });
  }
  test('moderation server failures cannot be reported as success', () async {
    realtime.config['moderation_server_url'] =
        'https://moderation.example/predict';
    client = _Client((_) async => http.Response('error', 503));
    await expectLater(
        backend.moderate('url', trace), throwsA(isA<FirebaseException>()));
    expect(client.closed, isTrue);
  });
  test('moderation and yearbook retain endpoint payload contracts', () async {
    realtime.config.addAll({
      'moderation_server_url': 'https://server.example/mod',
      'yearbook_server_url': 'https://server.example/year'
    });
    final requests = <Map<String, dynamic>>[];
    client = _Client((request) async {
      requests.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response('{"offensive":false}', 200);
    });
    await backend.moderate('url', trace);
    await backend.afterCommit('url', trace);
    expect(requests, [
      {'url': 'url', 'user_uid': 'user', 'image_name': 'post-id'},
      {'photo_path': 'url', 'post_id': 'post-id'},
    ]);
  });
  test('URL failure after upload deletes image and never writes a post',
      () async {
    storage.image.onUrl = () async => throw FirebaseException(
        plugin: 'firebase_storage', code: 'unauthorized');
    final result = expectLater(
        operation().submit(),
        throwsA(isA<PostCreationFailure>()
            .having((e) => e.stage, 'stage', 'download_url')));
    await Future<void>.delayed(Duration.zero);
    storage.image.task.finish();
    await result;
    expect(storage.image.deletes, greaterThanOrEqualTo(1));
    expect(db.post.written, isNull);
  });
  test('rejected cancellation and late native success retry orphan deletion',
      () async {
    storage.image.task.onCancel = () async => false;
    final result = operation().submit();
    await expectLater(result, throwsA(isA<PostCreationFailure>()));
    final initialDeletes = storage.image.deletes;
    expect(initialDeletes, 1);
    storage.image.task.finish();
    await Future<void>.delayed(Duration.zero);
    expect(storage.image.deletes, greaterThan(initialDeletes));
    expect(db.post.written, isNull);
  });
  test('failed late cleanup is observed without an unhandled exception',
      () async {
    storage.image.task.onCancel = () async => false;
    await expectLater(
        operation().submit(), throwsA(isA<PostCreationFailure>()));
    storage.image.onDelete = () async => throw StateError('offline');
    storage.image.task.finish();
    await Future<void>.delayed(Duration.zero);
    expect(db.post.written, isNull);
  });
}
