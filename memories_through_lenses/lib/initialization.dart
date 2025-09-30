import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:memories_through_lenses/screens/login.dart';
import 'package:memories_through_lenses/screens/home.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:memories_through_lenses/providers/user_provider.dart';
import 'package:provider/provider.dart';

class Initializer extends StatefulWidget {
  const Initializer({super.key});

  @override
  State<Initializer> createState() => _InitializerState();
}

class _InitializerState extends State<Initializer> {
  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);

    // Listen to auth state changes
    return StreamBuilder<User?>(
      stream: Auth().authStateChanges,
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // User is logged in
        if (snapshot.hasData && snapshot.data != null) {
          return const _AuthenticatedView();
        }

        // User is logged out
        return const _UnauthenticatedView();
      },
    );
  }
}

class _AuthenticatedView extends StatefulWidget {
  const _AuthenticatedView();

  @override
  State<_AuthenticatedView> createState() => _AuthenticatedViewState();
}

class _AuthenticatedViewState extends State<_AuthenticatedView> {
  @override
  void initState() {
    super.initState();
    // Load user data once when entering authenticated state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = Provider.of<UserProvider>(context, listen: false);
        provider.loadUserData();
        provider.loadGroups();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return HomePage();
  }
}

class _UnauthenticatedView extends StatefulWidget {
  const _UnauthenticatedView();

  @override
  State<_UnauthenticatedView> createState() => _UnauthenticatedViewState();
}

class _UnauthenticatedViewState extends State<_UnauthenticatedView> {
  @override
  void initState() {
    super.initState();
    // Clear provider data once when entering unauthenticated state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = Provider.of<UserProvider>(context, listen: false);
        provider.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const LoginPage();
  }
}
