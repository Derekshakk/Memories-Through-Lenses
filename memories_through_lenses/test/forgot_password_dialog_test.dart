// Regression tests for the forgot-password dialog.
//
// These lock in the behavior that fixes two production bugs:
//   1. The black-screen bug: an extra `Navigator.pop()` (from double-tapping
//      Send, or cancelling/backing out mid-request) used to pop the page
//      underneath the dialog, leaving an empty navigator = black screen. The
//      dialog must now pop itself exactly once and never over-pop.
//   2. The reset request must only report success when the sender actually
//      succeeds, and must never leave the Send button stuck in a loading state.
//
// The dialog takes an injectable `onSubmit`, so these run without Firebase.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memories_through_lenses/components/forgot_password_dialog.dart';

/// Home screen with a stable marker we can assert is still visible — proving
/// the page underneath the dialog was never popped (no black screen).
Widget _harness({required PasswordResetSender onSubmit}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('HOME MARKER', key: Key('home_marker')),
              ElevatedButton(
                onPressed: () =>
                    showForgotPasswordDialog(context, onSubmit: onSubmit),
                child: const Text('open'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Finder get _sendButton => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(ElevatedButton),
    );

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ElevatedButton, 'open'));
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
}

void main() {
  testWidgets('successful request closes the dialog and confirms neutrally',
      (tester) async {
    await tester.pumpWidget(_harness(onSubmit: (_) async => null));
    await _openDialog(tester);

    await tester.enterText(find.byType(TextField), 'user@icloud.com');
    await tester.tap(_sendButton);
    await tester.pumpAndSettle();

    // Dialog closed (navigation after success)...
    expect(find.byType(AlertDialog), findsNothing);
    // ...page underneath is intact (NO black screen)...
    expect(find.byKey(const Key('home_marker')), findsOneWidget);
    // ...and the message does not guarantee delivery or reveal account state.
    expect(find.textContaining('inbox and spam'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'FirebaseAuthException message keeps dialog open and restores button',
      (tester) async {
    await tester.pumpWidget(_harness(
      onSubmit: (_) async =>
          'Too many attempts. Please wait a moment and try again.',
    ));
    await _openDialog(tester);

    await tester.enterText(find.byType(TextField), 'user@example.com');
    await tester.tap(_sendButton);
    await tester.pumpAndSettle();

    // Dialog stays open so the user can retry (navigation after failure).
    expect(find.byType(AlertDialog), findsOneWidget);
    // Button restored: label back, spinner gone (loading-state cleanup).
    expect(
        find.widgetWithText(ElevatedButton, 'Send Reset Link'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Too many attempts'), findsOneWidget);
  });

  testWidgets('network failure surfaces the error without getting stuck',
      (tester) async {
    await tester.pumpWidget(_harness(
      onSubmit: (_) async =>
          'Network error. Please check your connection and try again.',
    ));
    await _openDialog(tester);

    await tester.enterText(find.byType(TextField), 'user@outlook.com');
    await tester.tap(_sendButton);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Network error'), findsOneWidget);
    expect(
        find.widgetWithText(ElevatedButton, 'Send Reset Link'), findsOneWidget);
  });

  testWidgets('empty email is rejected without calling the sender',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(_harness(onSubmit: (_) async {
      calls++;
      return null;
    }));
    await _openDialog(tester);

    // No text entered.
    await tester.tap(_sendButton);
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(find.text('Please enter your email address'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('repeated Send taps trigger only ONE request and one pop',
      (tester) async {
    var calls = 0;
    final completer = Completer<String?>();
    await tester.pumpWidget(_harness(onSubmit: (_) async {
      calls++;
      return completer.future;
    }));
    await _openDialog(tester);
    await tester.enterText(find.byType(TextField), 'user@yahoo.com');

    // Mash the button while the request is in flight.
    await tester.tap(_sendButton);
    await tester.pump();
    await tester.tap(_sendButton, warnIfMissed: false);
    await tester.tap(_sendButton, warnIfMissed: false);
    await tester.pump();

    expect(calls, 1);
    // Loading indicator shown, duplicate requests prevented.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(null);
    await tester.pumpAndSettle();

    // Exactly one pop: dialog gone, page intact (never went black).
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('home_marker')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('widget disposed mid-request does not throw or over-pop',
      (tester) async {
    final completer = Completer<String?>();
    await tester.pumpWidget(_harness(onSubmit: (_) async => completer.future));
    await _openDialog(tester);
    await tester.enterText(find.byType(TextField), 'user@school.edu');
    await tester.tap(_sendButton);
    await tester.pump();

    // Tear the whole tree down (simulates the dialog being disposed, e.g. an
    // auth-state change rebuilding the app) while the request is pending.
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Text('REPLACED', key: Key('replaced'))),
    ));
    completer.complete(null);
    await tester.pumpAndSettle();

    // No crash, no attempt to pop/snackbar on a dead context.
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('replaced')), findsOneWidget);
  });

  testWidgets('barrier/back dismissal is blocked while a request is in flight',
      (tester) async {
    final completer = Completer<String?>();
    await tester.pumpWidget(_harness(onSubmit: (_) async => completer.future));
    await _openDialog(tester);
    await tester.enterText(find.byType(TextField), 'user@gmail.com');

    // Before sending, the route can be popped normally.
    PopScope popScope = tester.widget(find.byType(PopScope));
    expect(popScope.canPop, isTrue);

    await tester.tap(_sendButton);
    await tester.pump();

    // While sending, PopScope blocks the barrier tap / system back gesture so
    // the page underneath cannot be popped (no black screen).
    popScope = tester.widget(find.byType(PopScope));
    expect(popScope.canPop, isFalse);

    completer.complete(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home_marker')), findsOneWidget);
  });
}
