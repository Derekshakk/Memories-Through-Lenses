import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/toggle_row.dart';

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
        title: Text('Settings'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  width: SizeConfig.blockSizeHorizontal! * 90,
                  // height: SizeConfig.blockSizeVertical! * 40,
                  child: const Card(
                    color: Colors.grey,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text("Notification Settings",
                              style: TextStyle(fontSize: 20)),
                          ToggleRow(title: "Disable All Notifications"),
                          ToggleRow(title: "New Uploads in Groups"),
                          ToggleRow(title: "Comments on Posts"),
                          ToggleRow(title: "Likes on Posts"),
                          ToggleRow(title: "New Group Invitations"),
                          ToggleRow(title: "Friend Requests"),
                          ToggleRow(title: "Admin Announcements"),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: SizeConfig.blockSizeHorizontal! * 90,
                  // height: SizeConfig.blockSizeVertical! * 40,
                  child: const Card(
                    color: Colors.grey,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text("Privacy Settings",
                              style: TextStyle(fontSize: 20)),
                          ToggleRow(title: "Private Account"),
                          ToggleRow(title: "Hide Profile from Search"),
                          ToggleRow(title: "Hide Friends List"),
                          ToggleRow(title: "Hide Groups"),
                          ToggleRow(title: "Hide Posts"),
                          ToggleRow(title: "Hide Comments"),
                          ToggleRow(title: "Hide Likes"),
                          ToggleRow(title: "Hide Groups"),
                          ToggleRow(title: "Hide Posts"),
                          ToggleRow(title: "Hide Comments"),
                          ToggleRow(title: "Hide Likes"),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: SizeConfig.blockSizeHorizontal! * 90,
                  height: SizeConfig.blockSizeVertical! * 20,
                  child: Card(
                    color: Colors.grey,
                    child: ListWheelScrollView(
                      itemExtent: 50,
                      children: [
                        ListTile(
                          tileColor: Colors.white,
                          title: Text("English"),
                          onTap: () {},
                        ),
                        ListTile(
                          tileColor: Colors.white,
                          title: Text("Spanish"),
                          onTap: () {},
                        ),
                        ListTile(
                          tileColor: Colors.white,
                          title: Text("Japanese"),
                          onTap: () {},
                        ),
                        ListTile(
                          tileColor: Colors.white,
                          title: Text("Chinese"),
                          onTap: () {},
                        ),
                        ListTile(
                          tileColor: Colors.white,
                          title: Text("Korean"),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ),
                ElevatedButton(onPressed: () {}, child: Text("Delete Account")),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
