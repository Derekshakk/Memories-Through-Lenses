import 'package:memories_through_lenses/initialization.dart';
import 'package:memories_through_lenses/screens/login.dart';
import 'package:memories_through_lenses/screens/signup.dart';
import 'package:memories_through_lenses/screens/home.dart';
import 'package:memories_through_lenses/screens/received_requests.dart';
import 'package:memories_through_lenses/screens/send_requests.dart';

var routes = {
  "/": (context) => Initializer(),
  "/login": (context) => LoginPage(),
  "/signup": (context) => SignupPage(),
  "/home": (context) => HomePage(),
  "/received": (context) => ReceivedScreen(),
};
