import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/friend_card.dart';
import 'package:memories_through_lenses/providers/user_provider.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:provider/provider.dart';

class SentScreen extends StatefulWidget {
  const SentScreen({super.key});

  @override
  State<SentScreen> createState() => _SentScreenState();
}

class _SentScreenState extends State<SentScreen> {
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
          title: Text("Sent Requests",
              style:
                  GoogleFonts.merriweather(fontSize: 30, color: Colors.black)),
        ),
        body: Center(
          child: Consumer<UserProvider>(
            builder: (context, provider, child) {
              List<Widget> outgoingRequests = [];
              List<Widget> currentFriends = [];

              Map<String, dynamic> requests =
                  provider.userData?['outgoing_requests'] ?? {};
              Map<String, dynamic> friends = provider.userData?['friends'] ?? {};

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

              for (var element in searchResults) {
                bool alreadyFriends = false;
                if (element['uid'] == Auth().user!.uid) {
                  continue;
                }
                var newFriend = FriendCard(
                  type: FriendCardType.addFriend,
                  name: element['name'],
                  uid: element['uid'],
                  onPressed: () {
                    setState(() {});
                  },
                );

                // check if the user is already a friend or part of outgoing requests
                for (var friend in currentFriends) {
                  if (friend is FriendCard) {
                    if (friend.uid == newFriend.uid) {
                      alreadyFriends = true;
                      break;
                    }
                  }
                }

                if (alreadyFriends) {
                  continue;
                }

                for (var request in outgoingRequests) {
                  if (request is FriendCard) {
                    if (request.uid == newFriend.uid) {
                      alreadyFriends = true;
                      break;
                    }
                  }
                }
                if (alreadyFriends) {
                  continue;
                }
                combined.add(FriendCard(
                  type: FriendCardType.addFriend,
                  name: element['name'],
                  uid: element['uid'],
                  onPressed: () {
                    setState(() {});
                  },
                ));
              }
              combined.addAll(outgoingRequests);

              return SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Add Friends",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
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
                    const Text(
                      "Current Friends",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
