import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:memories_through_lenses/providers/user_provider.dart';
import 'package:memories_through_lenses/screens/home.dart';
import 'package:memories_through_lenses/screens/login.dart';
import 'package:provider/provider.dart';

/// The single place that decides between the signed-in and signed-out UI.
///
/// It is used for MaterialApp.home *and* for the '/home' and '/login' named
/// routes. Previously those routes built HomePage/LoginPage directly, so any
/// `pushNamedAndRemoveUntil('/home' | '/login')` (after posting, joining a
/// group, declining the EULA…) replaced the only auth listener in the app.
/// After that, logging in or out had nothing to react to and the login or
/// home spinner never cleared until the app was restarted.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.uidChanges,
    this.signedInBuilder,
    this.signedOutBuilder,
  });

  /// Emits the signed-in uid, or null when signed out. Defaults to
  /// FirebaseAuth.authStateChanges(); injectable for tests.
  final Stream<String?>? uidChanges;
  final Widget Function(BuildContext context, String uid)? signedInBuilder;
  final WidgetBuilder? signedOutBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Created once. Building a fresh authStateChanges() stream on every build
  // re-subscribes the StreamBuilder and briefly drops back to "waiting".
  late final Stream<String?> _uidChanges = widget.uidChanges ??
      FirebaseAuth.instance.authStateChanges().map((user) => user?.uid);
  String? _lastUid;
  bool _hasEmitted = false;

  void _onAuthChanged(String? uid) {
    final previous = _lastUid;
    final first = !_hasEmitted;
    _hasEmitted = true;
    _lastUid = uid;
    if (first || previous == uid) return;
    // On sign-out (or switching accounts) drop every screen stacked above the
    // gate so a stale page/spinner for the old session can't stay on top.
    // Sign-in is not popped here: the signup flow intentionally keeps its
    // confirmation dialog visible while Firebase briefly signs the new user in.
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final route = ModalRoute.of(context);
        if (route != null && route.isFirst) {
          Navigator.of(context).popUntil((r) => r.isFirst);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: _uidChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !_hasEmitted) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final uid = snapshot.data;
        if (_lastUid != uid || !_hasEmitted) _onAuthChanged(uid);
        if (uid != null) {
          return widget.signedInBuilder?.call(context, uid) ??
              AuthenticatedHome(key: ValueKey('home_$uid'));
        }
        return widget.signedOutBuilder?.call(context) ?? const _SignedOut();
      },
    );
  }
}

class AuthenticatedHome extends StatefulWidget {
  const AuthenticatedHome({super.key});

  @override
  State<AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<AuthenticatedHome> {
  @override
  void initState() {
    super.initState();
    // Keyed by uid in AuthGate, so this reloads for every new session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
            Provider.of<UserProvider>(context, listen: false).refreshAll());
      }
    });
  }

  @override
  Widget build(BuildContext context) => HomePage();
}

class _SignedOut extends StatefulWidget {
  const _SignedOut();

  @override
  State<_SignedOut> createState() => _SignedOutState();
}

class _SignedOutState extends State<_SignedOut> {
  @override
  void initState() {
    super.initState();
    // Never leak the previous account's cached profile/groups into the next.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Provider.of<UserProvider>(context, listen: false).clear();
    });
  }

  @override
  Widget build(BuildContext context) => const LoginPage();
}
