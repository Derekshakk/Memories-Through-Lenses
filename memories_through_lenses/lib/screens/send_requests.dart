import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/friend_card.dart';

class SentScreen extends StatefulWidget {
  const SentScreen({super.key});

  @override
  State<SentScreen> createState() => _SentScreenState();
}

class _SentScreenState extends State<SentScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Sent Requests"),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                  width: SizeConfig.blockSizeHorizontal! * 80,
                  height: SizeConfig.blockSizeVertical! * 30,
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
              SizedBox(
                  width: SizeConfig.blockSizeHorizontal! * 80,
                  height: SizeConfig.blockSizeVertical! * 30,
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
            ],
          ),
        ));
  }
}
