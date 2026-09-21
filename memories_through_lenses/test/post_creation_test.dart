import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:memories_through_lenses/services/image_utils.dart';
import 'package:memories_through_lenses/services/post_creation.dart';

import 'support/post_backend.dart';

void main() {
  late FakePostBackend backend;
  PostCreation operation(
          {Future<PreparedImage> Function(Uint8List)? prepare}) =>
      PostCreation(
        backend,
        Uint8List.fromList([1]),
        prepare: prepare ?? (bytes) async => PreparedImage(bytes, 'image/jpeg'),
        stageTimeout: const Duration(milliseconds: 20),
        uploadTimeout: const Duration(milliseconds: 20),
        cleanupTimeout: const Duration(milliseconds: 5),
        moderationTimeout: const Duration(milliseconds: 20),
      );
  setUp(() {
    backend = FakePostBackend();
  });

  test(
      'success requires upload, URL and acknowledged post; secondary work is not blocking',
      () async {
    backend.actions['side'] = () => Completer<void>().future;
    final post = operation();
    await post.submit();
    expect(post.committed, isTrue);
    expect(backend.calls, [
      'auth',
      'group',
      'auth',
      'upload',
      'url',
      'moderation',
      'auth',
      'write',
      'side'
    ]);
  });

  for (final name in ['auth', 'group', 'upload', 'url', 'moderation']) {
    test('unresolved $name exits with a stage failure and cannot write later',
        () async {
      final blocked = Completer<void>();
      backend.actions[name] = () => blocked.future;
      final post = operation();
      await expectLater(
          post.submit(),
          throwsA(isA<PostCreationFailure>()
              .having((e) => e.pending, 'pending', false)));
      expect(backend.calls, isNot(contains('write')));
      blocked.complete();
      await Future<void>.delayed(Duration.zero);
      expect(backend.calls, isNot(contains('write')));
    });
  }

  test('unresolved preprocessing exits without starting Storage', () async {
    final post = operation(prepare: (_) => Completer<PreparedImage>().future);
    await expectLater(
        post.submit(),
        throwsA(isA<PostCreationFailure>()
            .having((e) => e.stage, 'stage', 'image_preprocessing')));
    expect(backend.calls, isNot(contains('upload')));
  });

  test(
      'write timeout retains image and retries the same write; late success is recognized',
      () async {
    final write = Completer<void>();
    backend.actions['write'] = () => write.future;
    final post = operation();
    for (var i = 0; i < 2; i++) {
      await expectLater(
          post.submit(),
          throwsA(isA<PostCreationFailure>()
              .having((e) => e.pending, 'pending', true)));
    }
    expect(backend.calls.where((e) => e == 'write'), hasLength(1));
    expect(backend.calls.where((e) => e == 'upload'), hasLength(1));
    expect(backend.calls, isNot(contains('delete')));
    write.complete();
    await post.submit();
    expect(post.committed, isTrue);
  });

  test('late write rejection cleans up the orphaned image', () async {
    final write = Completer<void>();
    backend.actions['write'] = () => write.future;
    final post = operation();
    await expectLater(post.submit(), throwsA(isA<PostCreationFailure>()));
    write.completeError(StateError('permission denied'));
    await expectLater(
        post.submit(),
        throwsA(isA<PostCreationFailure>()
            .having((e) => e.pending, 'pending', false)));
    expect(backend.calls.where((e) => e == 'delete'), hasLength(1));
  });

  test('write rejection and stuck cancellation/deletion still return failure',
      () async {
    backend.actions['write'] = () async => throw StateError('denied');
    backend.actions['cancel'] = () => Completer<void>().future;
    backend.actions['delete'] = () => Completer<void>().future;
    await expectLater(
        operation().submit(), throwsA(isA<PostCreationFailure>()));
    expect(backend.calls, containsAll(['cancel', 'delete']));
  });

  test('changed session immediately before write cleans image without posting',
      () async {
    var checks = 0;
    backend.actions['auth'] = () async {
      if (++checks == 3) throw StateError('session changed');
    };
    await expectLater(
        operation().submit(),
        throwsA(isA<PostCreationFailure>()
            .having((e) => e.stage, 'stage', 'auth_before_write')));
    expect(backend.calls, contains('delete'));
    expect(backend.calls, isNot(contains('write')));
  });

  test('moderation failure cannot publish a deleted or unapproved image',
      () async {
    backend.actions['moderation'] =
        () async => throw StateError('moderation failed');
    await expectLater(
        operation().submit(),
        throwsA(isA<PostCreationFailure>()
            .having((e) => e.stage, 'stage', 'moderation')));
    expect(backend.calls, contains('delete'));
    expect(backend.calls, isNot(contains('write')));
  });

  test('overlapping submissions share one operation', () async {
    final post = operation();
    final first = post.submit();
    final second = post.submit();
    expect(identical(first, second), isTrue);
    await Future.wait([first, second]);
    expect(backend.calls.where((e) => e == 'write'), hasLength(1));
  });

  test('cancellation exits a stuck upload and prevents later writes', () async {
    final upload = Completer<void>();
    backend.actions['upload'] = () => upload.future;
    final post = operation();
    final result = post.submit();
    final assertion = expectLater(result, throwsA(isA<PostCreationFailure>()));
    await Future<void>.delayed(Duration.zero);
    post.cancel();
    await assertion;
    upload.complete();
    await Future<void>.delayed(Duration.zero);
    expect(backend.calls, contains('delete'));
    expect(backend.calls, isNot(contains('write')));
  });
}
