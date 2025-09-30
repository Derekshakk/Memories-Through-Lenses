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

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  List<User> users = [];
  TextEditingController groupNameController = TextEditingController();
  TextEditingController groupDescriptionController = TextEditingController();
  bool isPrivate = false;

  @override
  void initState() {
    super.initState();
    loadFriends();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(),
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
                  Stack(
                    alignment: Alignment.center,
                    children: [
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
                      Center(
                        child: Container(
                          child: Text(
                            (users.length > 0) ? "" : "No Friends Available",
                            style: TextStyle(fontSize: 25),
                          ),
                        ),
                      ),
                    ],
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
                      if (groupNameController.text.isEmpty ||
                          groupDescriptionController.text.isEmpty) {
                        //show dialog
                        showDialog(context: context, builder: (context) {
                          return AlertDialog(
                            title: Text('Error'),
                            content: Text('Please fill out all fields'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: Text('OK'),
                              ),
                            ],
                          );
                        });
                      }
                      Database().createGroup(groupNameController.text,
                          groupDescriptionController.text, isPrivate);
                      Navigator.pop(context);
                    },
                    child: Text('Create Group'),
                  ),
                ],
              ),
            )),
          ),
        ));
  }
}
