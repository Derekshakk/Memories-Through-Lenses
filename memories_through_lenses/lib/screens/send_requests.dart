import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/friend_card.dart';
import 'package:memories_through_lenses/shared/singleton.dart';
import 'package:provider/provider.dart';

class SentScreen extends StatefulWidget {
  const SentScreen({super.key});

  @override
  State<SentScreen> createState() => _SentScreenState();
}

class _SentScreenState extends State<SentScreen> {
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
              List<Widget> outgoingRequests = [];
              List<Widget> currentFriends = [];

              Map<String, dynamic> requests =
                  singleton.userData['outgoing_requests'];
              Map<String, dynamic> friends = singleton.userData['friends'];

              requests.forEach((key, value) {
                outgoingRequests.add(FriendCard(
                  type: FriendCardType.addFriend,
                  name: value['name'],
                  uid: key,
                ));
              });

              print("populating current friends list");
              friends.forEach((key, value) {
                print("key: $key, value: $value");
                currentFriends.add(FriendCard(
                  type: FriendCardType.currentFriend,
                  name: value['name'],
                  uid: key,
                ));
              });
              print("current friends list: $currentFriends");

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                      width: SizeConfig.blockSizeHorizontal! * 80,
                      height: SizeConfig.blockSizeVertical! * 30,
                      child: Card(
                          color: Colors.blue,
                          child: ListView.builder(
                              itemCount: currentFriends.length,
                              itemBuilder: (context, index) =>
                                  currentFriends[index]))),
                  SizedBox(
                    height: SizeConfig.blockSizeVertical! * 2,
                  ),
                  SizedBox(
                      width: SizeConfig.blockSizeHorizontal! * 80,
                      height: SizeConfig.blockSizeVertical! * 30,
                      child: Card(
                          color: Colors.blue,
                          child: ListView.builder(
                              itemCount: outgoingRequests.length,
                              itemBuilder: (context, index) =>
                                  outgoingRequests[index]))),
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
