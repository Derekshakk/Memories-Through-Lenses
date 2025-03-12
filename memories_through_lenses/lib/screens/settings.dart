import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/toggle_row.dart';
import 'package:memories_through_lenses/services/auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isSwitched = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings',
            style: GoogleFonts.merriweather(fontSize: 30, color: Colors.black)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // SizedBox(
              //   width: SizeConfig.blockSizeHorizontal! * 90,
              //   // height: SizeConfig.blockSizeVertical! * 40,
              //   child: const Card(
              //     color: Colors.grey,
              //     child: Padding(
              //       padding: EdgeInsets.all(16.0),
              //       child: Column(
              //         children: [
              //           Text("Notification Settings",
              //               style: TextStyle(fontSize: 20)),
              //           ToggleRow(title: "Disable All Notifications"),
              //           ToggleRow(title: "New Uploads in Groups"),
              //           ToggleRow(title: "Comments on Posts"),
              //           ToggleRow(title: "Likes on Posts"),
              //           ToggleRow(title: "New Group Invitations"),
              //           ToggleRow(title: "Friend Requests"),
              //           // ToggleRow(title: "Admin Announcements"),
              //         ],
              //       ),
              //     ),
              //   ),
              // ),
              // SizedBox(
              //   width: SizeConfig.blockSizeHorizontal! * 90,
              //   // height: SizeConfig.blockSizeVertical! * 40,
              //   child: const Card(
              //     color: Colors.grey,
              //     child: Padding(
              //       padding: EdgeInsets.all(16.0),
              //       child: Column(
              //         children: [
              //           Text("Privacy Settings",
              //               style: TextStyle(fontSize: 20)),
              //           ToggleRow(title: "Private Account"),
              //           ToggleRow(title: "Hide Profile from Search"),
              //           ToggleRow(title: "Hide Friends List"),
              //           ToggleRow(title: "Hide Groups"),
              //           ToggleRow(title: "Hide Posts"),
              //           ToggleRow(title: "Hide Comments"),
              //           ToggleRow(title: "Hide Likes"),
              //           ToggleRow(title: "Hide Groups"),
              //           ToggleRow(title: "Hide Posts"),
              //           ToggleRow(title: "Hide Comments"),
              //           ToggleRow(title: "Hide Likes"),
              //         ],
              //       ),
              //     ),
              //   ),
              // ),
              // SizedBox(
              //   width: SizeConfig.blockSizeHorizontal! * 90,
              //   height: SizeConfig.blockSizeVertical! * 20,
              //   child: Card(
              //     color: Colors.grey,
              //     child: ListWheelScrollView(
              //       itemExtent: 50,
              //       children: [
              //         ListTile(
              //           tileColor: Colors.white,
              //           title: Text("English"),
              //           onTap: () {},
              //         ),
              //         ListTile(
              //           tileColor: Colors.white,
              //           title: Text("Spanish"),
              //           onTap: () {},
              //         ),
              //         ListTile(
              //           tileColor: Colors.white,
              //           title: Text("Japanese"),
              //           onTap: () {},
              //         ),
              //         ListTile(
              //           tileColor: Colors.white,
              //           title: Text("Chinese"),
              //           onTap: () {},
              //         ),
              //         ListTile(
              //           tileColor: Colors.white,
              //           title: Text("Korean"),
              //           onTap: () {},
              //         ),
              //       ],
              //     ),
              //   ),
              // ),
              SizedBox(
                height: SizeConfig.blockSizeVertical! * 10,
              ),
              Center(
                  child:
                      Icon(Icons.delete_forever, size: 100, color: Colors.red)),
              SizedBox(
                height: SizeConfig.blockSizeVertical! * 5,
              ),
              Center(
                child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return const DeleteAccountPopup();
                        },
                      );
                    },
                    child:
                        Text("Delete Account", style: TextStyle(fontSize: 20))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeleteAccountPopup extends StatelessWidget {
  const DeleteAccountPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Delete Account"),
      content: Text("Are you sure you want to delete your account?"),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            // Add delete account logic here
            Auth().deleteUser().then(
              (value) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/', (route) => false);
              },
            );
          },
          child: Text("Delete"),
        ),
      ],
    );
  }
}
