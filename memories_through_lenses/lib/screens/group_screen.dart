import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/group_card.dart';
import 'package:memories_through_lenses/providers/user_provider.dart';
import 'package:provider/provider.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  List<GroupCard> groups = [
    GroupCard(name: 'Group 1', groupID: '1', type: GroupCardType.notification),
    GroupCard(name: 'Group 2', groupID: '2', type: GroupCardType.notification),
    GroupCard(
        name: 'Group Derek', groupID: '3', type: GroupCardType.notification),
    GroupCard(name: 'Group 4', groupID: '4', type: GroupCardType.notification),
    GroupCard(name: 'Group 5', groupID: '5', type: GroupCardType.notification),
  ];

  void getGroupRequests(UserProvider provider) {
    groups.clear(); // Clear the existing groups
    // Fetch group requests from the user data in provider
    print("TESTING: ${provider.userData?['group_invites']}");
    if (provider.userData?['group_invites'] == null ||
        provider.userData!['group_invites'].isEmpty) {
      return;
    }
    provider.userData!['group_invites'].forEach((key, value) {
      groups.add(GroupCard(
          name: value, groupID: key, type: GroupCardType.notification));
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<UserProvider>(context, listen: false);
    getGroupRequests(provider); // Fetch group requests when building the widget
    return Scaffold(
        appBar: AppBar(
          title: Text('Manage Groups',
              style:
                  GoogleFonts.merriweather(fontSize: 30, color: Colors.black)),
        ),
        body: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/join_group');
                },
                child: Text('Join Group')),
            ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/edit_group');
                },
                child: Text('Edit Existing Group')),
            Column(
              children: [
                Text("Group Invites"),
                SizedBox(
                  width: SizeConfig.blockSizeHorizontal! * 90,
                  height: SizeConfig.blockSizeVertical! * 40,
                  child: Card(
                      color: Colors.grey,
                      child: ListView.builder(
                          itemCount: groups.length,
                          itemBuilder: (context, index) {
                            print(index);
                            return groups[index];
                          })),
                ),
              ],
            ),
            ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/create_group');
                },
                child: Text('Create Group')),
          ],
        )));
  }
}
