import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/friend_card.dart';
import 'package:memories_through_lenses/shared/singleton.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:provider/provider.dart';

class SentScreen extends StatefulWidget {
  const SentScreen({super.key});

  @override
  State<SentScreen> createState() => _SentScreenState();
}

class _SentScreenState extends State<SentScreen> {
  final Singleton singleton = Singleton();
  TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> searchResults = [];
  List<Widget> combined = [];

  Future<void> search(String query) async {
    if (query.isEmpty) {
      await Database().getUsers().then((value) {
        setState(() {
          if (value.isNotEmpty) {
            users = value;
          }
        });
      });
    } else {
      setState(() {
        print("searching for $query");
        searchResults = users
            .where((element) =>
                element['name'].toLowerCase().contains(query.toLowerCase()))
            .toList();
        print("search results: $searchResults");
      });
    }
  }

  @override
  void initState() {
    super.initState();
    search("");
  }

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
                  type: FriendCardType.sentRequest,
                  name: value['name'],
                  uid: key,
                  onPressed: () {
                    setState(() {});
                  },
                ));
              });

              print("populating current friends list");
              friends.forEach((key, value) {
                print("key: $key, value: $value");
                currentFriends.add(FriendCard(
                  type: FriendCardType.currentFriend,
                  name: value['name'],
                  uid: key,
                  onPressed: () {
                    setState(() {});
                  },
                ));
              });
              print("current friends list: $currentFriends");

              // for the combined list, add both the earch results and the outgoing requests
              combined.clear();
              searchResults.forEach((element) {
                combined.add(FriendCard(
                  type: FriendCardType.addFriend,
                  name: element['name'],
                  uid: element['uid'],
                  onPressed: () {
                    setState(() {});
                  },
                ));
              });
              combined.addAll(outgoingRequests);

              return SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          SizeConfig.blockSizeHorizontal! * 10,
                          0,
                          SizeConfig.blockSizeHorizontal! * 10,
                          0),
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: "Search for friends",
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (value) {
                          search(value);
                        },
                      ),
                    ),
                    SizedBox(
                        width: SizeConfig.blockSizeHorizontal! * 80,
                        height: SizeConfig.blockSizeVertical! * 30,
                        child: Card(
                            color: Colors.blue,
                            child: ListView.builder(
                                itemCount: combined.length,
                                itemBuilder: (context, index) =>
                                    combined[index]))),
                    SizedBox(
                      height: SizeConfig.blockSizeVertical! * 2,
                    ),
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
                  ],
                ),
              );
            },
          ),
        ));
  }
}
