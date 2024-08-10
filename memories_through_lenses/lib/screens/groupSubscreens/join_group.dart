import 'package:flutter/material.dart';
import 'package:memories_through_lenses/shared/singleton.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:provider/provider.dart';
import 'package:memories_through_lenses/components/group_card.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final Singleton singleton = Singleton();

  List<GroupCard> searchedGroups = [
    GroupCard(name: 'Group 1', groupID: '1', type: GroupCardType.request),
    GroupCard(name: 'Group 2', groupID: '2', type: GroupCardType.request),
    GroupCard(name: 'Group 3', groupID: '3', type: GroupCardType.request),
    GroupCard(name: 'Group 4', groupID: '4', type: GroupCardType.request),
    GroupCard(name: 'Group 5', groupID: '5', type: GroupCardType.request),
  ];
  List<GroupCard> pendingGroups = [
    GroupCard(name: 'Group 6', groupID: '6', type: GroupCardType.invite),
    GroupCard(name: 'Group 7', groupID: '7', type: GroupCardType.invite),
    GroupCard(name: 'Group 8', groupID: '8', type: GroupCardType.invite),
    GroupCard(name: 'Group 9', groupID: '9', type: GroupCardType.invite),
    GroupCard(name: 'Group 10', groupID: '10', type: GroupCardType.invite),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Sent Requests"),
        ),
        body: Center(
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

              return Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: SizeConfig.blockSizeHorizontal! * 80,
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Search for Group',
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
        ));
  }
}
