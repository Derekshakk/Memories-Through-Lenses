import 'package:flutter/material.dart';
import 'package:memories_through_lenses/screens/login.dart';
import 'package:memories_through_lenses/size_config.dart';

class Initializer extends StatelessWidget {
  const Initializer({super.key});

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return LoginPage();
  }
}
