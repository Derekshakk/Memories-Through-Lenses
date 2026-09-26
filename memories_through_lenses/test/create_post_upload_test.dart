import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:memories_through_lenses/providers/user_provider.dart';
import 'package:memories_through_lenses/screens/create_post.dart';
import 'package:memories_through_lenses/services/image_utils.dart';
import 'package:memories_through_lenses/services/post_creation.dart';
import 'package:provider/provider.dart';

import 'support/post_backend.dart';

class _Groups extends UserProvider {
  List<Map<String, dynamic>> data = [
    {'groupID': 'group', 'name': 'Photo group'}
  ];
  @override
  List<Map<String, dynamic>> get groups => data;
  void replace(List<Map<String, dynamic>> value) {
    data = value;
    notifyListeners();
  }
}

class _UnresolvedSubmission extends PostCreation {
  _UnresolvedSubmission() : super(FakePostBackend(), Uint8List(0));
  bool canceled = false;
  @override
  Future<void> submit() => Completer<void>().future;
  @override
  void cancel() {
    canceled = true;
    super.cancel();
  }
}

class _DelayedPhoto extends XFile {
  _DelayedPhoto(this.bytes) : super('unused-path');
  final Uint8List bytes;
  final read = Completer<Uint8List>();
  @override
  Future<int> length() async => bytes.length;
  @override
  Future<Uint8List> readAsBytes() => read.future;
}

void main() {
  const platforms =
      TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android});
  late FakePostBackend backend;
  late File photo;
  late Directory directory;
  late _Groups groups;
  setUp(() {
    backend = FakePostBackend();
    groups = _Groups();
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
      bool handoff = false,
      PostCreation? overrideOperation,
      bool factoryThrows = false,
      Future<XFile?> Function(ImageSource)? pickPhoto,
      Future<PreparedImage> Function(Uint8List)? prepare}) async {
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
        create: (_) => groups..imageFile = handoff ? photo : null,
        child: MaterialApp(
          onGenerateRoute: (settings) {
            if (navigationFails) throw StateError('navigation failed');
            return MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Home reached')));
          },
          home: CreatePostScreen(
              pickPhoto: pickPhoto,
              createPost: (group, caption, bytes) => factoryThrows
                  ? throw StateError('factory failure')
                  : overrideOperation ??
                      PostCreation(
                        backend,
                        bytes,
                        prepare: prepare ??
                            (bytes) async => PreparedImage(bytes, 'image/jpeg'),
                        stageTimeout: const Duration(seconds: 1),
                        uploadTimeout: const Duration(seconds: 1),
                        cleanupTimeout: const Duration(milliseconds: 10),
                      )),
        ),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    if (pickPhoto != null) {
      await tester.tap(find.text(source));
    } else {
      await tester.runAsync(() async {
        if (!handoff) await tester.tap(find.text(source));
        // Finish real file IO before returning to the fake widget clock.
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
    }
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

  testWidgets('UI safety deadline clears even an unresolved submission',
      (tester) async {
    final operation = _UnresolvedSubmission();
    await open(tester, overrideOperation: operation);
    await tester.tap(find.text('Share Post'));
    await tester.pump();
    await tester.pump(const Duration(minutes: 6, seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Uploading...'), findsNothing);
    expect(find.textContaining('timed out'), findsOneWidget);
    expect(operation.canceled, isTrue);
  }, variant: platforms);

  testWidgets('synchronous construction exception clears loading',
      (tester) async {
    await open(tester, factoryThrows: true);
    await tester.tap(find.text('Share Post'));
    await tester.pumpAndSettle();
    expect(find.text('Uploading...'), findsNothing);
    expect(find.textContaining('Could not finish'), findsOneWidget);
  }, variant: platforms);

  testWidgets(
      'removed group and malformed rows cannot submit a stale selection',
      (tester) async {
    await open(tester);
    groups.replace([
      {'groupID': null, 'name': 'broken'},
      {'name': 'missing id'}
    ]);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Share Post'))
            .onPressed,
        isNull);
    expect(backend.calls, isEmpty);
  }, variant: platforms);

  for (final stage in ['upload', 'url']) {
    testWidgets('$stage failure stops loading and allows successful retry',
        (tester) async {
      backend.actions[stage] = () async => throw FirebaseException(
          plugin: 'firebase_storage', code: 'retry-limit-exceeded');
      await open(tester);
      await tester.tap(find.text('Share Post'));
      await tester.pumpAndSettle();
      expect(find.text('Uploading...'), findsNothing);
      expect(find.textContaining('Could not finish'), findsOneWidget);
      expect(find.text('Home reached'), findsNothing);
      backend.actions.remove(stage);
      await tester.tap(find.text('Share Post'));
      await tester.pumpAndSettle();
      expect(find.text('Home reached'), findsOneWidget);
    }, variant: platforms);
  }

  for (final stage in ['auth', 'group', 'moderation', 'write']) {
    testWidgets('$stage failure always clears loading and cannot navigate',
        (tester) async {
      backend.actions[stage] = () async => throw StateError('failed');
      await open(tester);
      await tester.tap(find.text('Share Post'));
      await tester.pumpAndSettle();
      expect(find.text('Uploading...'), findsNothing);
      expect(find.text('Home reached'), findsNothing);
      expect(
          tester
              .widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, 'Share Post'))
              .onPressed,
          isNotNull);
    }, variant: platforms);
  }

  testWidgets('slow materialization before picker completion is awaited',
      (tester) async {
    final selection = Completer<XFile?>();
    await open(tester, pickPhoto: (_) => selection.future);
    await tester.pump(const Duration(seconds: 40));
    expect(backend.calls, isEmpty);
    final bytes = Uint8List.fromList(photo.readAsBytesSync());
    selection.complete(XFile.fromData(bytes));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Photo group'));
    await tester.tap(find.text('Photo group'));
    await tester.pump();
    await tester.ensureVisible(find.text('Share Post'));
    await tester.tap(find.text('Share Post'));
    await tester.pumpAndSettle();
    expect(find.text('Home reached'), findsOneWidget);
  }, variant: platforms);

  for (final timesOut in [false, true]) {
    testWidgets(
        'delayed XFile read ${timesOut ? 'times out without late selection' : 'retains bytes without a usable path'}',
        (tester) async {
      final source = _DelayedPhoto(Uint8List.fromList(photo.readAsBytesSync()));
      await open(tester, pickPhoto: (_) async => source);
      await tester.pump(Duration(seconds: timesOut ? 16 : 5));
      expect(backend.calls, isEmpty);
      source.read.complete(source.bytes);
      await tester.pumpAndSettle();
      if (timesOut) {
        expect(
            find.textContaining('Could not open this photo'), findsOneWidget);
        expect(
            tester
                .widget<ElevatedButton>(
                    find.widgetWithText(ElevatedButton, 'Share Post'))
                .onPressed,
            isNull);
      } else {
        await tester.ensureVisible(find.text('Photo group'));
        await tester.tap(find.text('Photo group'));
        await tester.pump();
        await tester.ensureVisible(find.text('Share Post'));
        await tester.tap(find.text('Share Post'));
        await tester.pumpAndSettle();
        expect(find.text('Home reached'), findsOneWidget);
      }
    }, variant: platforms);
  }

  for (final timesOut in [false, true]) {
    testWidgets(
        'slow preprocessing ${timesOut ? 'clears loading and ignores late success' : 'is not mistaken for cancellation'}',
        (tester) async {
      final prepared = Completer<PreparedImage>();
      await open(tester, prepare: (_) => prepared.future);
      await tester.tap(find.text('Share Post'));
      await tester.pump();
      await tester.pump(Duration(milliseconds: timesOut ? 1100 : 500));
      expect(backend.calls, isNot(contains('upload')));
      prepared.complete(PreparedImage(
          Uint8List.fromList(photo.readAsBytesSync()), 'image/jpeg'));
      await tester.pumpAndSettle();
      expect(find.text('Uploading...'), findsNothing);
      if (timesOut) {
        expect(find.textContaining('preparing your photo (timed out)'),
            findsOneWidget);
        expect(backend.calls, isNot(contains('upload')));
      } else {
        expect(find.text('Home reached'), findsOneWidget);
      }
    }, variant: platforms);
  }

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
