import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:memories_through_lenses/providers/user_provider.dart';
import 'package:memories_through_lenses/screens/create_post.dart';
import 'package:memories_through_lenses/services/image_utils.dart';
import 'package:memories_through_lenses/services/post_creation.dart';
import 'package:provider/provider.dart';

import 'support/post_backend.dart';

class _Groups extends UserProvider {
  @override
  List<Map<String, dynamic>> get groups => [
        {'groupID': 'group', 'name': 'Photo group'}
      ];
}

void main() {
  const platforms =
      TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android});
  late FakePostBackend backend;
  late File photo;
  late Directory directory;
  setUp(() {
    backend = FakePostBackend();
    directory = Directory.systemTemp.createTempSync('post-ui-');
    photo = File('${directory.path}/photo.jpg')
      ..writeAsBytesSync(img.encodeJpg(img.Image(width: 16, height: 16)));
  });
  tearDown(() {
    directory.deleteSync(recursive: true);
  });

  Future<void> open(WidgetTester tester,
      {bool navigationFails = false,
      String source = 'Gallery',
      bool missingFile = false,
      bool handoff = false}) async {
    final oldError = FlutterError.onError;
    FlutterError.onError = (details) {
      // Existing decorated group ListTile diagnostic, unrelated to upload.
      if (!details.exceptionAsString().startsWith(
          'ListTile background color or ink splashes may be invisible.')) {
        oldError?.call(details);
      }
    };
    addTearDown(() => FlutterError.onError = oldError);
    const channel = MethodChannel('plugins.flutter.io/image_picker');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      expect(call.arguments['source'], source == 'Camera' ? 0 : 1);
      return missingFile ? '${directory.path}/gone.jpg' : photo.path;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await tester.runAsync(() async {
      await tester.pumpWidget(ChangeNotifierProvider<UserProvider>(
        create: (_) => _Groups()..imageFile = handoff ? photo : null,
        child: MaterialApp(
          onGenerateRoute: (settings) {
            if (navigationFails) throw StateError('navigation failed');
            return MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Home reached')));
          },
          home: CreatePostScreen(
              createPost: (group, caption, bytes) => PostCreation(
                    backend,
                    bytes,
                    prepare: (bytes) async =>
                        PreparedImage(bytes, 'image/jpeg'),
                    stageTimeout: const Duration(seconds: 1),
                    uploadTimeout: const Duration(seconds: 1),
                    cleanupTimeout: const Duration(milliseconds: 10),
                  )),
        ),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      if (!handoff) await tester.tap(find.text(source));
      // Finish real file IO before returning to the fake widget clock.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Photo group'));
    await tester.tap(find.text('Photo group'));
    await tester.pump();
    await tester.ensureVisible(find.text('Share Post'));
    await tester.pump();
  }

  for (final source in ['Camera', 'Gallery']) {
    testWidgets(
        '$source selection uploads after picker temporary file is deleted',
        (tester) async {
      await open(tester, source: source);
      photo.deleteSync();
      await tester.tap(find.text('Share Post'));
      await tester.pumpAndSettle();
      expect(find.text('Home reached'), findsOneWidget);
      expect(backend.calls.where((e) => e == 'write'), hasLength(1));
    }, variant: platforms);
  }

  testWidgets('camera screen provider handoff owns bytes before uploading',
      (tester) async {
    await open(tester, handoff: true);
    photo.deleteSync();
    await tester.tap(find.text('Share Post'));
    await tester.pumpAndSettle();
    expect(find.text('Home reached'), findsOneWidget);
  }, variant: platforms);

  testWidgets('stuck upload clears spinner and rejects duplicate taps',
      (tester) async {
    backend.actions['upload'] = () => Completer<void>().future;
    await open(tester);
    final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Share Post'));
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(find.text('Uploading...'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Uploading...'), findsNothing);
    expect(find.textContaining('timed out'), findsOneWidget);
    expect(backend.calls.where((e) => e == 'upload'), hasLength(1));
  }, variant: platforms);

  testWidgets('pending write stops spinner; retry waits for same post',
      (tester) async {
    final write = Completer<void>();
    backend.actions['write'] = () => write.future;
    await open(tester);
    await tester.tap(find.text('Share Post'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Uploading...'), findsNothing);
    expect(find.textContaining('not yet confirmed'), findsOneWidget);
    await tester.tap(find.text('Share Post'));
    await tester.pump();
    write.complete();
    await tester.pumpAndSettle();
    expect(find.text('Home reached'), findsOneWidget);
    expect(backend.calls.where((e) => e == 'write'), hasLength(1));
    expect(backend.calls, isNot(contains('delete')));
  }, variant: platforms);

  testWidgets('database denial after upload stops loading and never navigates',
      (tester) async {
    backend.actions['write'] = () async => throw FirebaseException(
        plugin: 'cloud_firestore', code: 'permission-denied');
    await open(tester);
    await tester.tap(find.text('Share Post'));
    await tester.pumpAndSettle();
    expect(find.text('Uploading...'), findsNothing);
    expect(find.textContaining('do not have permission'), findsOneWidget);
    expect(find.text('Home reached'), findsNothing);
    expect(backend.calls, contains('delete'));
  }, variant: platforms);

  testWidgets('navigation failure leaves spinner off and prevents reposting',
      (tester) async {
    await open(tester, navigationFails: true);
    await tester.tap(find.text('Share Post'));
    await tester.pumpAndSettle();
    expect(find.text('Uploading...'), findsNothing);
    expect(find.textContaining('Your post was saved'), findsOneWidget);
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Share Post'))
            .onPressed,
        isNull);
  }, variant: platforms);

  testWidgets('disposed route cancels upload without setState after dispose',
      (tester) async {
    backend.actions['upload'] = () => Completer<void>().future;
    await open(tester);
    await tester.tap(find.text('Share Post'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('cancel'));
    expect(backend.calls, isNot(contains('write')));
    expect(tester.takeException(), isNull);
  }, variant: platforms);

  testWidgets(
      'unavailable picker file gives retry message without enabling upload',
      (tester) async {
    await open(tester, missingFile: true);
    expect(find.textContaining('Could not open this photo'), findsOneWidget);
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Share Post'))
            .onPressed,
        isNull);
  }, variant: platforms);
}
