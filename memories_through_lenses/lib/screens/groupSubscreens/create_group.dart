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
    SizeConfig().init(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        title: Text(
          'Create Group',
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

              // Add Members Section
              Text(
                'Add Members',
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
                height: SizeConfig.blockSizeVertical! * 40,
                child: users.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'No Friends Available',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add friends to invite them to your group',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[500],
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
                          );
                        },
                      ),
              ),

              const SizedBox(height: 20),

              // Private Toggle
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ToggleRow(
                  title: 'Private Group',
                  onToggled: (value) {
                    setState(() {
                      isPrivate = value;
                    });
                  },
                ),
              ),

              const SizedBox(height: 32),

              // Create Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (groupNameController.text.isEmpty ||
                        groupDescriptionController.text.isEmpty) {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Text(
                              'Error',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600),
                            ),
                            content: Text(
                              'Please fill out all fields',
                              style: GoogleFonts.poppins(),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  'OK',
                                  style:
                                      GoogleFonts.poppins(color: Colors.blue),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                      return;
                    }

                    // Check for duplicate group name
                    try {
                      final groupsSnapshot = await FirebaseFirestore.instance
                          .collection('groups')
                          .where('name',
                              isEqualTo: groupNameController.text.trim())
                          .get();

                      if (groupsSnapshot.docs.isNotEmpty) {
                        if (mounted) {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: Text(
                                  'Error',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600),
                                ),
                                content: Text(
                                  'A group with this name already exists. Please choose a different name.',
                                  style: GoogleFonts.poppins(),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: Text(
                                      'OK',
                                      style: GoogleFonts.poppins(
                                          color: Colors.blue),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        }
                        return;
                      }

                      // Create the group if no duplicate found
                      await Database().createGroup(
                        groupNameController.text,
                        groupDescriptionController.text,
                        isPrivate,
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Group created successfully!',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      print('Error checking for duplicate group: $e');
                      if (mounted) {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: Text(
                                'Error',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600),
                              ),
                              content: Text(
                                'Failed to create group. Please try again.',
                                style: GoogleFonts.poppins(),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    'OK',
                                    style:
                                        GoogleFonts.poppins(color: Colors.blue),
                                  ),
                                ),
                              ],
                            );
                          },
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
                    'Create Group',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        )),
      ),
    );
  }
}
