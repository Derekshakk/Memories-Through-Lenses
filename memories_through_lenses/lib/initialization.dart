import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:memories_through_lenses/screens/login.dart';
import 'package:memories_through_lenses/screens/home.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/services/auth.dart';

class Initializer extends StatelessWidget {
  const Initializer({super.key});

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);

    User? user = Auth().user;

    if (user != null) {
      return HomePage();
    }
    return LoginPage();
  }
}
