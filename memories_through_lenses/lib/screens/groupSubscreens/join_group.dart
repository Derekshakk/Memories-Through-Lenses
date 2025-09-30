import 'package:flutter/material.dart';
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
        }
      }
    } catch (e) {
      print('Error loading user school: $e');
    }
  }

  Future<void> getGroupsCollection() async {
    if (userSchool == null) return;

    try {
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
        });
      }
    } catch (e) {
      print('Error loading groups: $e');
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
    } catch (e) {
      print('Error loading group requests: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Join Group"),
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: SizeConfig.blockSizeHorizontal! * 80,
                      child: TextField(
                        onChanged: (value) {
                          search(value);
                        },
                        decoration: InputDecoration(
                          labelText: 'Search for Group to join',
                        ),
                      ),
                    ),
                    SizedBox(
                        width: SizeConfig.blockSizeHorizontal! * 80,
                        height: SizeConfig.blockSizeVertical! * 30,
                        child: Card(
                            color: Colors.blue,
                            child: ListView.builder(
                                itemCount: searchedGroups.length,
                                itemBuilder: (context, index) =>
                                    searchedGroups[index]))),
                    SizedBox(
                      height: SizeConfig.blockSizeVertical! * 2,
                    ),
                    Text("Pending Group Invites you sent"),
                    SizedBox(
                        width: SizeConfig.blockSizeHorizontal! * 80,
                        height: SizeConfig.blockSizeVertical! * 30,
                        child: Card(
                            color: Colors.blue,
                            child: ListView.builder(
                                itemCount: pendingGroups.length,
                                itemBuilder: (context, index) =>
                                    pendingGroups[index]))),
                    SizedBox(
                      height: SizeConfig.blockSizeVertical! * 2,
                    ),
                  ],
                ),
          ),
        ));
  }
}
