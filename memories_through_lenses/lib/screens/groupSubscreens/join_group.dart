import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/group_card.dart';
import 'package:memories_through_lenses/services/streams.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:memories_through_lenses/services/auth.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  List<GroupCard> searchedGroups = [];
  List<GroupCard> pendingGroups = [];
  String? userSchool;
  bool isLoadingGroups = true;
  bool isLoadingPending = true;

  @override
  void initState() {
    super.initState();
    loadUserSchool();
    getGroupRequests();
  }

  Future<void> loadUserSchool() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(Auth().user!.uid)
          .get();

      if (userDoc.exists && mounted) {
        setState(() {
          userSchool = userDoc.data()?['school'];
        });
        if (userSchool != null) {
          getGroupsCollection();
        } else {
          // No school assigned, stop loading
          if (mounted) {
            setState(() {
              isLoadingGroups = false;
            });
          }
        }
      } else {
        // User doc doesn't exist, stop loading
        if (mounted) {
          setState(() {
            isLoadingGroups = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user school: $e');
      if (mounted) {
        setState(() {
          isLoadingGroups = false;
        });
      }
    }
  }

  Future<void> getGroupsCollection() async {
    if (userSchool == null) return;

    try {
      setState(() {
        isLoadingGroups = true;
      });

      searchedGroups.clear();

      // Get user data for group_requests
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(Auth().user!.uid)
          .get();

      List<dynamic> groupRequests = userDoc.data()?['group_requests'] ?? [];

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('groups')
          .where('school', isEqualTo: userSchool)
          .get();

      List<GroupCard> fetchedGroups = [];
      for (var doc in snapshot.docs) {
        // check that user is not owner of the group
        if (doc['owner'] != Auth().user!.uid &&
            !groupRequests.contains(doc.id)) {
          fetchedGroups.add(GroupCard(
            name: doc['name'],
            groupID: doc.id,
            type: GroupCardType.request,
          ));
        }
      }

      if (mounted) {
        setState(() {
          searchedGroups = fetchedGroups;
          isLoadingGroups = false;
        });
      }
    } catch (e) {
      print('Error loading groups: $e');
      if (mounted) {
        setState(() {
          isLoadingGroups = false;
        });
      }
    }
  }

  Future<void> search(String query) async {
    // Implement search functionality here
    if (query.isEmpty) {
      await getGroupsCollection();
    } else {
      setState(() {
        searchedGroups = searchedGroups
            .where((group) =>
                group.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    }
  }

  Future<void> getGroupRequests() async {
    try {
      setState(() {
        isLoadingPending = true;
      });

      pendingGroups.clear();

      // Fetch group requests from the user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(Auth().user!.uid)
          .get();

      List<dynamic> groupRequests = userDoc.data()?['group_requests'] ?? [];

      for (var groupID in groupRequests) {
        final groupDoc = await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupID)
            .get();

        if (groupDoc.exists && mounted) {
          Map<String, dynamic> groupData =
              groupDoc.data() as Map<String, dynamic>;
          setState(() {
            pendingGroups.add(GroupCard(
                name: groupData['name'],
                groupID: groupID,
                type: GroupCardType.invite));
          });
        }
      }

      if (mounted) {
        setState(() {
          isLoadingPending = false;
        });
      }
    } catch (e) {
      print('Error loading group requests: $e');
      if (mounted) {
        setState(() {
          isLoadingPending = false;
        });
      }
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
          'Join Group',
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
                // Search Field
                Text(
                  'Search Groups',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (value) {
                    search(value);
                  },
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    hintText: 'Search for a group to join...',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
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

                const SizedBox(height: 24),

                // Available Groups Section
                Text(
                  'Available Groups',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
                  child: isLoadingGroups
                      ? const Center(child: CircularProgressIndicator())
                      : searchedGroups.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.groups_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Groups Found',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try searching for a different group',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: searchedGroups.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) => searchedGroups[index],
                            ),
                ),

                const SizedBox(height: 32),

                // Pending Requests Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pending Requests',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    if (pendingGroups.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${pendingGroups.length}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  height: SizeConfig.blockSizeVertical! * 25,
                  child: isLoadingPending
                      ? const Center(child: CircularProgressIndicator())
                      : pendingGroups.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.pending_outlined,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No Pending Requests',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: pendingGroups.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) => pendingGroups[index],
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
