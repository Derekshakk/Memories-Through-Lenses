import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/toggle_row.dart';
import 'package:memories_through_lenses/components/group_card.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  List<Group> groups = [];
  TextEditingController groupNameController = TextEditingController();
  TextEditingController groupDescriptionController = TextEditingController();
  bool isPrivate = false;
  String? currentGroup;
  String? currentGroupName;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    await Future.wait([loadFriends(), loadGroups()]);
  }

  Future<void> loadFriends() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(Auth().user!.uid)
          .get();

      if (userDoc.exists && mounted) {
        Map<String, dynamic> friends = userDoc.data()?['friends'] ?? {};
        setState(() {
          users.clear();
          for (var key in friends.keys) {
            users.add(User(name: friends[key]['name'], uid: key));
          }
        });
      }
    } catch (e) {
      print('Error loading friends: $e');
    }
  }

  Future<void> loadGroups() async {
    try {
      final uid = Auth().user!.uid;
      final groupsSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .where('owner', isEqualTo: uid)
          .get();

      if (mounted) {
        setState(() {
          groups.clear();
          for (var doc in groupsSnapshot.docs) {
            final data = doc.data();
            groups.add(Group(
                name: data['name'],
                description: data['description'],
                groupID: doc.id,
                isPrivate: data['private'],
                members: data['members'],
                owner: data['owner']));
          }
        });
      }
    } catch (e) {
      print('Error loading groups: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
