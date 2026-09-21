import 'dart:async';
import 'package:memories_through_lenses/services/image_utils.dart';
import 'package:memories_through_lenses/services/post_creation.dart';

class FakePostBackend implements PostBackend {
  final calls = <String>[];
  final actions = <String, Future<void> Function()>{};
  Future<void> call(String name) async {
    calls.add(name);
    await actions[name]?.call();
  }

  @override
  String get id => 'test-post';
  @override
  Future<void> authenticate() => call('auth');
  @override
  Future<void> validateGroup() => call('group');
  @override
  Future<void> upload(PreparedImage image, PostTrace trace) => call('upload');
  @override
  Future<String> downloadUrl() async {
    await call('url');
    return 'test-url';
  }

  @override
  Future<void> moderate(String url, PostTrace trace) => call('moderation');
  @override
  Future<void> writePost(String url) => call('write');
  @override
  Future<void> cancelUpload() => call('cancel');
  @override
  Future<void> deleteUpload() => call('delete');
  @override
  Future<void> afterCommit(String url, PostTrace trace) => call('side');
}
