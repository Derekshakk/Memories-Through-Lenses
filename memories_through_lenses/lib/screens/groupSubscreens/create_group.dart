import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/toggle_row.dart';
import 'package:memories_through_lenses/shared/singleton.dart';
import 'package:memories_through_lenses/components/group_card.dart';

class User {
  final String name;
  final String uid;

  User({required this.name, required this.uid});
}

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  List<User> users = [];
  Singleton singleton = Singleton();

  void setUsers() {
    users.clear();
    Map<String, dynamic> friends = singleton.userData['friends'];

    for (var key in friends.keys) {
      users.add(User(name: friends[key]['name'], uid: key));
    }
  }

  @override
  Widget build(BuildContext context) {
    setUsers();
    return Scaffold(
        body: SafeArea(
      child: Center(
          child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Group Name',
              ),
            ),
            Container(
              color: Colors.grey,
              height: SizeConfig.blockSizeVertical! * 60,
              width: SizeConfig.blockSizeHorizontal! * 90,
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  return GroupFriendCard(
                    name: users[index].name,
                    uid: users[index].uid,
                  );
                },
              ),
            ),
            ToggleRow(
              title: 'Private',
            ),
            ElevatedButton(
              onPressed: () {},
              child: Text('Create Group'),
            ),
          ],
        ),
      )),
    ));
  }
}
