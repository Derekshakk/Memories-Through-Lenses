import 'package:flutter/material.dart';
import 'package:memories_through_lenses/components/app_keyboard_behavior.dart';
import 'package:memories_through_lenses/components/auth_gate.dart';
import 'package:memories_through_lenses/providers/preferences_provider.dart';
import 'package:memories_through_lenses/routes.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:memories_through_lenses/firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:memories_through_lenses/providers/user_provider.dart';
import 'package:memories_through_lenses/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

late final FirebaseApp app;
late final FirebaseAuth auth;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  app = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  auth = FirebaseAuth.instanceFor(app: app);

  // Read saved display preferences before the first frame so dark mode, text
  // size and the feed sort apply immediately (no light-theme flash).
  final preferences = await PreferencesProvider.load();
  bool? darkMode;
  try {
    darkMode = ThemeProvider.readSaved(await SharedPreferences.getInstance());
  } catch (e) {
    debugPrint('Error reading theme preference: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(
            create: (context) => ThemeProvider(initialDarkMode: darkMode)),
        ChangeNotifierProvider.value(value: preferences),
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
    final preferences = Provider.of<PreferencesProvider>(context);

    return MaterialApp(
      title: 'Memories through Lenses',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => preferences.applyTextScale(
          context, AppKeyboardBehavior.builder(context, child)),
      // AuthGate owns the signed-in/signed-out decision; '/home' and '/login'
      // also resolve to it (see routes.dart).
      home: const AuthGate(),
      routes: routes,
    );
  }
}
