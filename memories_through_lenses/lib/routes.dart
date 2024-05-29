import 'package:memories_through_lenses/initialization.dart';
import 'package:memories_through_lenses/screens/login.dart';
import 'package:memories_through_lenses/screens/signup.dart';
import 'package:memories_through_lenses/screens/home.dart';

var routes = {
  "/": (context) => Initializer(),
  "/login": (context) => LoginPage(),
  "/signup": (context) => SignupPage(),
  "/home": (context) => HomePage(),
};
