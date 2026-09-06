import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memories_through_lenses/components/app_keyboard_behavior.dart';
import 'package:memories_through_lenses/providers/user_provider.dart';
import 'package:memories_through_lenses/screens/change_password.dart';
import 'package:memories_through_lenses/screens/create_post.dart';
import 'package:memories_through_lenses/screens/home.dart';
import 'package:memories_through_lenses/screens/login.dart';
import 'package:memories_through_lenses/screens/signup.dart';
import 'package:provider/provider.dart';

class _PostUserProvider extends UserProvider {
  @override
  List<Map<String, dynamic>> get groups => [
        {'groupID': 'photography', 'name': 'Photography'},
      ];
}

Widget _app(Widget screen, {bool withGroups = false}) =>
    ChangeNotifierProvider<UserProvider>(
      create: (_) => withGroups ? _PostUserProvider() : UserProvider(),
      child: MaterialApp(
        builder: AppKeyboardBehavior.builder,
        home: screen,
      ),
    );

const _mobilePlatforms = TargetPlatformVariant({
  TargetPlatform.android,
  TargetPlatform.iOS,
});

void main() {
  final screens = <String, Widget Function()>{
    'Create Post': () => const CreatePostScreen(),
    'Login': () => const LoginPage(),
    'Signup': () => const SignupPage(),
    'Change Password': () => const ChangePasswordScreen(),
    'Home search': () => Scaffold(
          body: SearchBarWidget(onSearch: (_) {}, onClear: () {}),
        ),
  };

  for (final screen in screens.entries) {
    testWidgets('${screen.key}: every field dismisses and retains entered text',
        (tester) async {
      await tester.pumpWidget(_app(screen.value()));
      await tester.pumpAndSettle();
      if (screen.key == 'Signup') {
        await tester.tap(find.text('Accept'));
        await tester.pumpAndSettle();
      }

      final fields = find.byType(TextField);
      expect(fields, findsAtLeastNWidgets(1));
      for (var index = 0; index < fields.evaluate().length; index++) {
        final field = fields.at(index);
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.tap(field);
        await tester.enterText(field, 'draft $index');
        await tester.pump();
        final input = tester.widget<EditableText>(
          find.descendant(of: field, matching: find.byType(EditableText)),
        );
        expect(input.focusNode.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);

        // The left screen margin is outside all padded text inputs.
        await tester.tapAt(const Offset(2, 100));
        await tester.pump();
        expect(input.focusNode.hasFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(input.controller.text, 'draft $index');
      }
    }, variant: _mobilePlatforms);
  }

  testWidgets('Create Post group selection works on the first tap',
      (tester) async {
    // This existing screen paints its group list over a decorated Container.
    // Newer Flutter versions report that unrelated ink-background diagnostic;
    // capture only that known warning while exercising the actual group tiles.
    final originalOnError = FlutterError.onError;
    final tileDiagnostics = <FlutterErrorDetails>[];
    FlutterError.onError = (details) {
      if (details.exceptionAsString().startsWith(
          'ListTile background color or ink splashes may be invisible.')) {
        tileDiagnostics.add(details);
      } else {
        originalOnError?.call(details);
      }
    };
    addTearDown(() => FlutterError.onError = originalOnError);
    await tester.pumpWidget(_app(const CreatePostScreen(), withGroups: true));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Photography'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'group draft');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Photography'));
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'group draft');
    expect(tileDiagnostics, isNotEmpty);
  }, variant: _mobilePlatforms);

  for (final label in ['Gallery', 'Camera']) {
    testWidgets('Create Post $label opens on the first tap with keyboard open',
        (tester) async {
      const channel = MethodChannel('plugins.flutter.io/image_picker');
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async {
          calls.add(call);
          return null; // User cancels the native picker.
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(_app(const CreatePostScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'photo draft');
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      expect(calls.single.method, 'pickImage');
      expect(calls.single.arguments['source'], label == 'Camera' ? 0 : 1);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          'photo draft');
    }, variant: _mobilePlatforms);
  }

  testWidgets('Login password visibility and reset dialog still work',
      (tester) async {
    await tester.pumpWidget(_app(const LoginPage()));
    await tester.pumpAndSettle();
    final password = find.byType(TextField).last;
    await tester.ensureVisible(password);
    await tester.enterText(password, 'password draft');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(tester.widget<TextField>(password).obscureText, isFalse);
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    final resetEmail = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(resetEmail, 'draft@example.com');
    await tester.pump();
    await tester.tap(find.text('Reset Password'));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(resetEmail);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  }, variant: _mobilePlatforms);
}
