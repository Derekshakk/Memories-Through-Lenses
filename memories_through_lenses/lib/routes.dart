import 'package:memories_through_lenses/screens/login.dart';
import 'package:memories_through_lenses/screens/scan_face.dart';
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
import 'package:memories_through_lenses/screens/groupSubscreens/review_reports.dart';
import 'package:memories_through_lenses/screens/profile_edit.dart';
import 'package:memories_through_lenses/screens/camera.dart';
import 'package:memories_through_lenses/screens/yearbook.dart';

var routes = {
  "/login": (context) => LoginPage(),
  "/signup": (context) => SignupPage(),
  "/home": (context) => HomePage(),
  "/received": (context) => ReceivedScreen(),
  "/send": (context) => SentScreen(),
  "/settings": (context) => SettingsScreen(),
  "/notifications": (context) => NotificationScreen(),
  "/create": (context) => CreatePostScreen(),
  "/camera": (context) => CameraScreen(),
  "/group": (context) => GroupScreen(),
  "/create_group": (context) => CreateGroupScreen(),
  "/join_group": (context) => JoinGroupScreen(),
  "/edit_group": (context) => EditGroupScreen(),
  "/review_reports": (context) => ReviewReportsScreen(),
  "/profile_edit": (context) => ProfileEditScreen(),
  "/yearbook": (context) => YearbookScreen(),
  "/scan_face": (context) => ScanFace(),
};
