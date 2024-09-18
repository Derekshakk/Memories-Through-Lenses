import 'package:flutter/material.dart';
import 'package:memories_through_lenses/shared/singleton.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:provider/provider.dart';
import 'package:memories_through_lenses/components/group_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:memories_through_lenses/services/auth.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final Singleton singleton = Singleton();

  List<GroupCard> searchedGroups = [
    // GroupCard(name: 'Group 1', groupID: '1', type: GroupCardType.request),
    // GroupCard(name: 'Group 2', groupID: '2', type: GroupCardType.request),
    // GroupCard(name: 'Group 3', groupID: '3', type: GroupCardType.request),
    // GroupCard(name: 'Group 4', groupID: '4', type: GroupCardType.request),
    // GroupCard(name: 'Group 5', groupID: '5', type: GroupCardType.request),
  ];
  List<GroupCard> pendingGroups = [
    // GroupCard(name: 'Group 6', groupID: '6', type: GroupCardType.invite),
    // GroupCard(name: 'Group 7', groupID: '7', type: GroupCardType.invite),
    // GroupCard(name: 'Group 8', groupID: '8', type: GroupCardType.invite),
    // GroupCard(name: 'Group 9', groupID: '9', type: GroupCardType.invite),
    // GroupCard(name: 'Group 10', groupID: '10', type: GroupCardType.invite),
  ];

  Future<void> getGroupsCollection() async {
    searchedGroups.clear(); // Clear the existing groups
    // Fetch groups from Firestore
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('groups').get();
    List<GroupCard> fetchedGroups = [];
    for (var doc in snapshot.docs) {
      // check that user is not owner of the group
      if (doc['owner'] != Auth().user!.uid &&
          !singleton.userData['group_requests'].contains(doc.id)) {
        fetchedGroups.add(GroupCard(
          name: doc['name'],
          groupID: doc.id,
          type: GroupCardType.request,
        ));
      }
    }
    setState(() {
      searchedGroups = fetchedGroups;
    });
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

  void getGroupRequests() {
    pendingGroups.clear(); // Clear the existing groups
    // Fetch group requests from the user data in singleton
    singleton.userData['group_requests'].forEach((value) {
      // get the group data from the group collection (the value is the groupID)
      FirebaseFirestore.instance
          .collection('groups')
          .doc(value)
          .get()
          .then((groupDoc) {
        if (groupDoc.exists) {
          Map<String, dynamic> groupData =
              groupDoc.data() as Map<String, dynamic>;
          pendingGroups.add(GroupCard(
              name: groupData['name'],
              groupID: value,
              type: GroupCardType.invite));
          setState(() {}); // Update the UI
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    getGroupsCollection();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Sent Requests"),
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Consumer<Singleton>(
              builder: (context, _singleton, child) {
                // List<Widget> searchedGroups = [];
                // List<Widget> pendingGroups = [];

                // Map<String, dynamic> requests =
                //     singleton.userData['outgoing_requests'];
                // Map<String, dynamic> friends = singleton.userData['friends'];

                // requests.forEach((key, value) {
                //   outgoingRequests.add(FriendCard(
                //     type: FriendCardType.addFriend,
                //     name: value['name'],
                //     uid: key,
                //   ));
                // });

                // print("populating current friends list");
                // friends.forEach((key, value) {
                //   print("key: $key, value: $value");
                //   currentFriends.add(FriendCard(
                //     type: FriendCardType.currentFriend,
                //     name: value['name'],
                //     uid: key,
                //   ));
                // });
                // print("current friends list: $currentFriends");
                getGroupRequests(); // Fetch group requests when building the widget

                return Column(
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
                );
              },
            ),
          ),
        ));
  }
}
