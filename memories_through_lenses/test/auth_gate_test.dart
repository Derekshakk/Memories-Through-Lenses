import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memories_through_lenses/components/auth_gate.dart';

/// Mimics FirebaseAuth.authStateChanges(): each new listener immediately
/// receives the current state, then later changes.
class FakeAuth {
  final _changes = StreamController<String?>.broadcast();
  String? current;
  bool emitted = false;

  Stream<String?> get stream => Stream<String?>.multi((listener) {
        if (emitted) listener.add(current);
        final sub = _changes.stream.listen(listener.add);
        listener.onCancel = sub.cancel;
      });

  void set(String? uid) {
    current = uid;
    emitted = true;
    _changes.add(uid);
  }
}

Widget gate(FakeAuth auth) => AuthGate(
      uidChanges: auth.stream,
      signedInBuilder: (context, uid) => Scaffold(
        body: Column(children: [
          Text('home $uid'),
          ElevatedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('deep page')))),
            child: const Text('open deep'),
          ),
          ElevatedButton(
            // What posting / joining a group does.
            onPressed: () => Navigator.of(context)
                .pushNamedAndRemoveUntil('/home', (route) => false),
            child: const Text('reset home'),
          ),
        ]),
      ),
      signedOutBuilder: (_) => const Scaffold(body: Text('login page')),
    );

void main() {
  testWidgets('shows a spinner only until the first auth event',
      (tester) async {
    final auth = FakeAuth();
    await tester.pumpWidget(MaterialApp(home: gate(auth)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    auth.set(null);
    await tester.pumpAndSettle();
    expect(find.text('login page'), findsOneWidget);

    auth.set('u1');
    await tester.pumpAndSettle();
    expect(find.text('home u1'), findsOneWidget);
  });

  testWidgets('signing out from a stacked screen returns to the login page',
      (tester) async {
    final auth = FakeAuth()..set('u1');
    await tester.pumpWidget(MaterialApp(home: gate(auth)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open deep'));
    await tester.pumpAndSettle();
    expect(find.text('deep page'), findsOneWidget);

    auth.set(null);
    await tester.pumpAndSettle();
    expect(find.text('deep page'), findsNothing);
    expect(find.text('login page'), findsOneWidget);
  });

  testWidgets(
      'after the navigator is reset to /home, logout and login still work',
      (tester) async {
    final auth = FakeAuth()..set('u1');
    await tester.pumpWidget(MaterialApp(
      home: gate(auth),
      routes: {'/home': (_) => gate(auth)},
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('reset home'));
    await tester.pumpAndSettle();
    expect(find.text('home u1'), findsOneWidget);

    auth.set(null);
    await tester.pumpAndSettle();
    expect(find.text('login page'), findsOneWidget);

    auth.set('u2');
    await tester.pumpAndSettle();
    expect(find.text('home u2'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('switching accounts rebuilds the signed-in page for the new uid',
      (tester) async {
    final auth = FakeAuth()..set('u1');
    await tester.pumpWidget(MaterialApp(home: gate(auth)));
    await tester.pumpAndSettle();
    auth.set('u2');
    await tester.pumpAndSettle();
    expect(find.text('home u2'), findsOneWidget);
  });
}
