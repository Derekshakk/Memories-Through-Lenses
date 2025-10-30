import 'package:flutter/material.dart';
import 'package:memories_through_lenses/routes.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:memories_through_lenses/firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:memories_through_lenses/providers/user_provider.dart';
import 'package:memories_through_lenses/providers/theme_provider.dart';
import 'package:memories_through_lenses/screens/login.dart';
import 'package:memories_through_lenses/screens/home.dart';

late final FirebaseApp app;
late final FirebaseAuth auth;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  app = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  auth = FirebaseAuth.instanceFor(app: app);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Memories through Lenses',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
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
            return const AuthenticatedHome();
          }

          // User is not logged in
          return const LoginPage();
        },
      ),
      routes: routes,
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
    // Load user data once
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
