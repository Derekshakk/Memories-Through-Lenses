import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/group_card.dart';
import 'package:memories_through_lenses/shared/singleton.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final Singleton singleton = Singleton();
  List<GroupCard> groups = [
    GroupCard(name: 'Group 1', groupID: '1', type: GroupCardType.notification),
    GroupCard(name: 'Group 2', groupID: '2', type: GroupCardType.notification),
    GroupCard(
        name: 'Group Derek', groupID: '3', type: GroupCardType.notification),
    GroupCard(name: 'Group 4', groupID: '4', type: GroupCardType.notification),
    GroupCard(name: 'Group 5', groupID: '5', type: GroupCardType.notification),
  ];

  void getGroupRequests() {
    groups.clear(); // Clear the existing groups
    // Fetch group requests from the user data in singleton
    print("TESTING: ${singleton.userData['group_invites']}");
    if (singleton.userData['group_invites'] == null ||
        singleton.userData['group_invites'].isEmpty) {
      return;
    }
    singleton.userData['group_invites'].forEach((key, value) {
      groups.add(GroupCard(
          name: value, groupID: key, type: GroupCardType.notification));
    });
  }

  @override
  Widget build(BuildContext context) {
    getGroupRequests(); // Fetch group requests when building the widget
    return Scaffold(
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
