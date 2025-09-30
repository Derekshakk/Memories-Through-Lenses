import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/friend_card.dart';
import 'package:memories_through_lenses/providers/user_provider.dart';
import 'package:provider/provider.dart';

class ReceivedScreen extends StatefulWidget {
  const ReceivedScreen({super.key});

  @override
  State<ReceivedScreen> createState() => _ReceivedScreenState();
}

class _ReceivedScreenState extends State<ReceivedScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<UserProvider>(context, listen: false);
    List<Widget> requestCards = [];

    Map<String, dynamic> requests = provider.userData?['friend_requests'] ?? {};

    for (var key in requests.keys) {
      requestCards.add(FriendCard(
        type: FriendCardType.request,
        name:
            (requests[key]['name'] != null) ? requests[key]['name'] : "Unknown",
        uid: key,
        onPressed: () {
          setState(() {});
        },
      ));
    }

    print("names: $requestCards");

    return Scaffold(
        appBar: AppBar(
          title: Text("Pending Requests",
              style:
                  GoogleFonts.merriweather(fontSize: 30, color: Colors.black)),
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
                      child: ListView.builder(
                        itemCount: requestCards.length,
                        itemBuilder: (context, index) {
                          return requestCards[index];
                        },
                      ))),
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
