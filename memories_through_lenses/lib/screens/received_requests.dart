import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/friend_card.dart';

class ReceivedScreen extends StatefulWidget {
  const ReceivedScreen({super.key});

  @override
  State<ReceivedScreen> createState() => _ReceivedScreenState();
}

class _ReceivedScreenState extends State<ReceivedScreen> {
  @override
  Widget build(BuildContext context) {
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
                      child: ListView(children: [FriendCard()]))),
              SizedBox(
                height: SizeConfig.blockSizeVertical! * 2,
              ),
              ElevatedButton(onPressed: () {}, child: Text("Outgoing Requests"))
            ],
          ),
        ));
  }
}
