import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memories_through_lenses/components/group_card.dart';
import 'package:memories_through_lenses/components/toggle_row.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:memories_through_lenses/size_config.dart';

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
    SizeConfig().init(context);

    return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.blue,
          elevation: 0,
          title: Text(
            'Edit Group',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Select Group Dropdown
                  Text(
                    'Select Group',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: Text(
                          'Choose a group to edit',
                          style: GoogleFonts.poppins(color: Colors.grey[400]),
                        ),
                        value: currentGroup,
                        items: groups.map((group) {
                          return DropdownMenuItem(
                            value: group.groupID,
                            child: Text(
                              group.name,
                              style: GoogleFonts.poppins(),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            currentGroup = value.toString();
                            for (Group group in groups) {
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
                        },
                      ),
                    ),
                  ),

                  if (currentGroup != null) ...[
                    const SizedBox(height: 24),

                    // Group Name Field
                    Text(
                      'Group Name',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: groupNameController,
                      style: GoogleFonts.poppins(),
                      decoration: InputDecoration(
                        hintText: 'Enter group name',
                        hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Group Description Field
                    Text(
                      'Group Description',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: groupDescriptionController,
                      style: GoogleFonts.poppins(),
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter group description',
                        hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Members Section
                    Text(
                      'Group Members',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      height: SizeConfig.blockSizeVertical! * 35,
                      child: users.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No friends to add',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: users.length,
                              itemBuilder: (context, index) {
                                return GroupFriendCard(
                                  name: users[index].name,
                                  uid: users[index].uid,
                                  groupID: currentGroup!,
                                  groupName: currentGroupName!,
                                  mode: 'edit',
                                );
                              },
                            ),
                    ),

                    const SizedBox(height: 20),

                    // Private Toggle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ToggleRow(
                        title: 'Private Group',
                        initialValue: isPrivate,
                        onToggled: (value) {
                          setState(() {
                            isPrivate = value;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (groupNameController.text.trim().isEmpty ||
                                  groupDescriptionController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Please fill out all fields',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              try {
                                await Database().updateGroup(
                                  currentGroup!,
                                  groupNameController.text.trim(),
                                  groupDescriptionController.text.trim(),
                                  isPrivate,
                                );

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Group updated successfully',
                                        style: GoogleFonts.poppins(),
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to update group: ${e.toString()}',
                                        style: GoogleFonts.poppins(),
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              'Save Changes',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            onPressed: () async {
                              // Show confirmation dialog
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: Text(
                                      'Delete Group',
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                    ),
                                    content: Text(
                                      'Are you sure you want to delete this group? This will remove all posts and cannot be undone.',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop(false);
                                        },
                                        child: Text(
                                          'Cancel',
                                          style: GoogleFonts.poppins(color: Colors.grey),
                                        ),
                                      ),
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        onPressed: () {
                                          Navigator.of(context).pop(true);
                                        },
                                        child: Text(
                                          'Delete',
                                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (confirmed == true && mounted) {
                                try {
                                  await Database().deleteGroup(currentGroup!);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Group deleted successfully',
                                          style: GoogleFonts.poppins(),
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    Navigator.pop(context);
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to delete group: ${e.toString()}',
                                          style: GoogleFonts.poppins(),
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            child: Text(
                              'Delete Group',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ));
  }
}
