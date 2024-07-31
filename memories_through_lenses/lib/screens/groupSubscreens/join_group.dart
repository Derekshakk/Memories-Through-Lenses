import 'package:flutter/material.dart';
import 'package:memories_through_lenses/shared/singleton.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:provider/provider.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final Singleton singleton = Singleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Sent Requests"),
        ),
        body: Center(
          child: Consumer<Singleton>(
            builder: (context, _singleton, child) {
              List<Widget> searchedGroups = [];
              List<Widget> pendingGroups = [];

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
