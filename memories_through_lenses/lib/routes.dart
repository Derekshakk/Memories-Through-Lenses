import 'package:memories_through_lenses/initialization.dart';
import 'package:memories_through_lenses/screens/login.dart';
import 'package:memories_through_lenses/screens/signup.dart';
import 'package:memories_through_lenses/screens/home.dart';
import 'package:memories_through_lenses/screens/received_requests.dart';
import 'package:memories_through_lenses/screens/send_requests.dart';
import 'package:memories_through_lenses/screens/settings.dart';
import 'package:memories_through_lenses/screens/notifications.dart';
import 'package:memories_through_lenses/screens/create_post.dart';
import 'package:memories_through_lenses/screens/group_screen.dart';
import 'package:memories_through_lenses/screens/groupSubscreens/create_group.dart';
import 'package:memories_through_lenses/screens/groupSubscreens/join_group.dart';
import 'package:memories_through_lenses/screens/groupSubscreens/edit_group.dart';

var routes = {
  "/": (context) => Initializer(),
  "/login": (context) => LoginPage(),
  "/signup": (context) => SignupPage(),
  "/home": (context) => HomePage(),
  "/received": (context) => ReceivedScreen(),
  "/send": (context) => SentScreen(),
  "/settings": (context) => SettingsScreen(),
  "/notifications": (context) => NotificationScreen(),
  "/create": (context) => CreatePostScreen(),
  "/group": (context) => GroupScreen(),
  "/create_group": (context) => CreateGroupScreen(),
  "/join_group": (context) => JoinGroupScreen(),
  "/edit_group": (context) => EditGroupScreen(),
};
