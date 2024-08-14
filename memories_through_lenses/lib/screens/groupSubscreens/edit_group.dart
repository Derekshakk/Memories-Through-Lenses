import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/toggle_row.dart';
import 'package:memories_through_lenses/shared/singleton.dart';
import 'package:memories_through_lenses/components/group_card.dart';
import 'package:memories_through_lenses/services/database.dart';

class User {
  final String name;
  final String uid;

  User({required this.name, required this.uid});
}

class Group {
  final String name;
  final String description;
  final String groupID;
  final bool isPrivate;
  final List<String> members;
  final String owner;

  Group(
      {required this.name,
      required this.description,
      required this.groupID,
      required this.isPrivate,
      required this.members,
      required this.owner});
}

class EditGroupScreen extends StatefulWidget {
  const EditGroupScreen({super.key});

  @override
  State<EditGroupScreen> createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends State<EditGroupScreen> {
  List<User> users = [];
  List<Group> groups = [
    Group(
        name: 'Group 1',
        description: 'Description 1',
        groupID: '1',
        isPrivate: false,
        members: ['1'],
        owner: '1'),
  ];
  Singleton singleton = Singleton();
  TextEditingController groupNameController = TextEditingController();
  TextEditingController groupDescriptionController = TextEditingController();
  bool isPrivate = false;

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
      child: SingleChildScrollView(
        child: Center(
            child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DropdownButton(
                  hint: Text('Select Group'),
                  items: groups.map((group) {
                    return DropdownMenuItem(
                      child: Text(group.name),
                      value: group.groupID,
                    );
                  }).toList(),
                  onChanged: (value) {}),
              TextField(
                controller: groupNameController,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                ),
              ),
              TextField(
                controller: groupDescriptionController,
                decoration: const InputDecoration(
                  labelText: 'Group Description',
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
                      mode: 'edit',
                    );
                  },
                ),
              ),
              ToggleRow(
                title: 'Private',
                onToggled: (value) {
                  setState(() {
                    isPrivate = value;
                  });
                },
              ),
              ElevatedButton(
                onPressed: () {
                  Database().createGroup(groupNameController.text,
                      groupDescriptionController.text, isPrivate);
                  Navigator.pop(context);
                },
                child: Text('Edit Group'),
              ),
            ],
          ),
        )),
      ),
    ));
  }
}
