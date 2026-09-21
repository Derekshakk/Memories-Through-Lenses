import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memories_through_lenses/services/firebase_post_backend.dart';
import 'package:memories_through_lenses/services/post_creation.dart';

class _Snapshot extends Fake implements TaskSnapshot {
  _Snapshot(this.state);
  @override
  final TaskState state;
  @override
  int get totalBytes => 10;
  @override
  int get bytesTransferred => state == TaskState.success ? 10 : 0;
}

class _Task extends Fake implements UploadTask {
  _Task({FutureOr<void> Function()? onCancel})
      : events = StreamController<TaskSnapshot>(onCancel: onCancel);
  final StreamController<TaskSnapshot> events;
  final completion = Completer<TaskSnapshot>();
  @override
  TaskSnapshot snapshot = _Snapshot(TaskState.running);
  @override
  Stream<TaskSnapshot> get snapshotEvents => events.stream;
  @override
  Future<S> then<S>(FutureOr<S> Function(TaskSnapshot) onValue,
          {Function? onError}) =>
      completion.future.then(onValue, onError: onError);
}

void main() {
  late _Task task;
  setUp(() {
    task = _Task();
  });
  Future<void> wait() => waitForStorageUpload(task, PostTrace('storage-test'),
      timeout: const Duration(milliseconds: 20),
      cleanupTimeout: const Duration(milliseconds: 5));

  test('success snapshot resolves even if task completer never resolves',
      () async {
    final result = wait();
    task.events.add(_Snapshot(TaskState.success));
    await result;
    expect(task.events.hasListener, isFalse);
  });
  test('already completed snapshot covers a missed completion event', () async {
    task.snapshot = _Snapshot(TaskState.success);
    await wait();
  });
  test('native stream error does not wait for broken task completer', () async {
    final result = expectLater(wait(), throwsStateError);
    task.events.addError(StateError('native channel failed'));
    await result;
  });
  test('stream closure without terminal result fails', () async {
    final result = expectLater(wait(), throwsStateError);
    await task.events.close();
    await result;
  });
  test('canceled snapshot fails without waiting for completer', () async {
    final result = expectLater(wait(), throwsA(isA<FirebaseException>()));
    task.events.add(_Snapshot(TaskState.canceled));
    await result;
  });
  test('error snapshot fails promptly even if the task Future is unresolved',
      () async {
    final result = expectLater(wait(), throwsA(isA<FirebaseException>()));
    task.events.add(_Snapshot(TaskState.error));
    await result;
  });
  test('listener cancellation cannot hold a successful upload forever',
      () async {
    task = _Task(onCancel: () => Completer<void>().future);
    final result = wait();
    task.events.add(_Snapshot(TaskState.success));
    await result;
  });
  test('no native events times out and removes listener', () async {
    await expectLater(wait(), throwsA(isA<TimeoutException>()));
    expect(task.events.hasListener, isFalse);
  });
  test('task failure is propagated even if stream stays silent', () async {
    final result = expectLater(wait(), throwsStateError);
    task.completion.completeError(StateError('failed'));
    await result;
  });
}
