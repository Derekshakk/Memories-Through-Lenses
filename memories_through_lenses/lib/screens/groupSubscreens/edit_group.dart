import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/toggle_row.dart';
import 'package:memories_through_lenses/shared/singleton.dart';
import 'package:memories_through_lenses/components/group_card.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:memories_through_lenses/services/auth.dart';

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
  final List<dynamic> members;
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
  String? currentGroup;
  String? currentGroupName;

  void setUsers() {
    users.clear();
    Map<String, dynamic> friends = singleton.userData['friends'];

    for (var key in friends.keys) {
      users.add(User(name: friends[key]['name'], uid: key));
    }
  }

  void setGroups() {
    groups.clear();
    for (Map<String, dynamic> group in singleton.groupData) {
      final String uid = Auth().user!.uid;
      if (group['owner'] != uid) {
        continue;
      }

      groups.add(Group(
          name: group['name'],
          description: group['description'],
          groupID: group['groupID'],
          isPrivate: group['private'],
          members: group['members'],
          owner: group['owner']));
    }
  }

  @override
  Widget build(BuildContext context) {
    setUsers();
    setGroups();
    return Scaffold(
        appBar: AppBar(
          title: DropdownButton(
              hint: Text('Select Group'),
              value: currentGroup,
              items: groups.map((group) {
                return DropdownMenuItem(
                  child: Text(group.name),
                  value: group.groupID,
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  print("Setting current group to $value");
                  // set current group to whichever group has the same name as value
                  currentGroup = value.toString();

                  // set the group name and description to the current group's name and description
                  for (Group group in groups) {
                    print("Comparing ${group.groupID} to $value");
                    if (group.groupID == value) {
                      groupNameController.text = group.name;
                      currentGroupName = group.name;
                      groupDescriptionController.text = group.description;
                      isPrivate = group.isPrivate;
                      currentGroup = group.groupID;
                      break;
                    }
                  }
                });
              }),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Center(
                child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                          groupID: (currentGroup != null) ? currentGroup! : '',
                          groupName: (currentGroupName != null)
                              ? currentGroupName!
                              : '',
                          mode: 'edit',
                        );
                      },
                    ),
                  ),
                  ToggleRow(
                    title: 'Private',
                    initialValue: isPrivate,
                    onToggled: (value) {
                      setState(() {
                        print("Setting isPrivate to $value");
                        isPrivate = value;
                      });
                    },
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Database().updateGroup(, name, description, isPrivate)
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
