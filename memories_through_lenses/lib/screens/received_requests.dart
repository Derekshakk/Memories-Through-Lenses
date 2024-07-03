import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/friend_card.dart';
import 'package:memories_through_lenses/shared/singleton.dart';

class ReceivedScreen extends StatefulWidget {
  const ReceivedScreen({super.key});

  @override
  State<ReceivedScreen> createState() => _ReceivedScreenState();
}

class _ReceivedScreenState extends State<ReceivedScreen> {
  @override
  Widget build(BuildContext context) {
    Singleton singleton = Singleton();
    List<String> names = [];

    // singleton.userData['friend_requests'].forEach((element) {
    //   print("Element: $element");
    //   names.add(element['name']);
    // });

    print(names);

    return Scaffold(
        appBar: AppBar(
          title: Text("Pending Requests"),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                  width: SizeConfig.blockSizeHorizontal! * 80,
                  height: SizeConfig.blockSizeVertical! * 65,
                  child: Card(
                      color: Colors.blue,
                      child: ListView(children: [
                        // FriendCard(
                        //   type: FriendCardType.request,
                        // ),
                        // FriendCard(
                        //   type: FriendCardType.addFriend,
                        // ),
                        // FriendCard(
                        //   type: FriendCardType.currentFriend,
                        // )
                      ]))),
              SizedBox(
                height: SizeConfig.blockSizeVertical! * 2,
              ),
              ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/send');
                  },
                  child: Text("Outgoing Requests"))
            ],
          ),
        ));
  }
}
