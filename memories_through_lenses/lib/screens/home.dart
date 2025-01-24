import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/post.dart';
import 'package:memories_through_lenses/components/buttons.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:memories_through_lenses/shared/singleton.dart';
import 'package:memories_through_lenses/components/friend_card.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:provider/provider.dart';

enum ContentType { recent, popular }

class PostData {
  final String id;
  final String creator;
  final String mediaURL;
  final String mediaType;
  final int likes;
  final int dislikes;
  final String caption;
  final DateTime created_at;
  PostData(
      {required this.id,
      required this.creator,
      required this.mediaURL,
      required this.mediaType,
      required this.caption,
      required this.likes,
      required this.dislikes,
      required this.created_at});
}

class Pair {
  final String key;
  final String value;

  Pair(this.key, this.value);
}

class HomePage extends StatefulWidget {
  HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Singleton singleton = Singleton();
  ContentType selected = ContentType.popular;
  bool timelineLoaded = false;

  List<String> dropdownItems = ["Item 1", "Item 2", "Item 3"];
  List<Pair> dropdownPairs = [
    Pair("Item 1", "1"),
    Pair("Item 2", "2"),
    Pair("Item 3", "3")
  ];
  String dropdownValue = "";

  // list of posts (mediaURL, likes, dislikes)
  List<PostData> posts = [
    // PostData(
    //     id: "1",
    //     mediaURL: "https://picsum.photos/200",
    //     mediaType: "image",
    //     caption: "This is a caption",
    //     likes: 0,
    //     dislikes: 0),
    // PostData(
    //     id: "2",
    //     mediaURL: "https://www.youtube.com/watch?v=jNQXAC9IVRw",
    //     mediaType: "video",
    //     caption: "This is a caption",
    //     likes: 0,
    //     dislikes: 0),
    // PostData(
    //     id: "3",
    //     mediaURL: "https://picsum.photos/200",
    //     mediaType: "image",
    //     caption: "This is a caption",
    //     likes: 0,
    //     dislikes: 0),
    // PostData(
    //     id: "4",
    //     mediaURL: "https://picsum.photos/200",
    //     mediaType: "image",
    //     caption: "This is a caption",
    //     likes: 0,
    //     dislikes: 0),
    // PostData(
    //     id: "5",
    //     mediaURL: "https://picsum.photos/200",
    //     mediaType: "image",
    //     caption: "This is a caption",
    //     likes: 0,
    //     dislikes: 0),
  ];

  void getGroups() {
    dropdownItems.clear();
    dropdownPairs.clear();
    // print("SINGLETON: ${singleton.groupData}");
    List<Map<String, dynamic>> groups = singleton.groupData;
    for (var element in groups) {
      // print("ADDING: ${element['name']}");
      dropdownItems.add(element['name']);
      dropdownPairs.add(Pair(element['name'], element['groupID']));
    }

    // print("dropdownItems: $dropdownItems");

    if (dropdownItems.isNotEmpty) dropdownValue = dropdownItems[0];
  }

  void getPosts(String groupID) {
    Database()
        .getPosts(
            groupID, (selected == ContentType.popular) ? 'popular' : 'newest')
        .then((value) {
      List<PostData> temp = [];
      List<dynamic> blockedUsers = (singleton.userData['blocked'] != null)
          ? singleton.userData['blocked']
          : [];
      List<dynamic> blockedPosts =
          (singleton.userData['reported_posts'] != null)
              ? singleton.userData['reported_posts']
              : [];
      // print("VALUE: $value");
      for (var element in value) {
        if (blockedUsers.contains(element['user_id']) ||
            blockedPosts.contains(element['id'])) {
          continue;
        }

        temp.add(PostData(
            id: element['id'],
            creator: element['user_id'],
            mediaURL: element['image_url'],
            mediaType: 'image',
            caption: element['caption'],
            likes: element['likes'].length,
            dislikes: element['dislikes'].length,
            // Timestamp to datetime
            created_at: DateTime.fromMillisecondsSinceEpoch(
                element['created_at'].seconds * 1000)));
      }

      // reverse the list so that the newest post is at the top
      temp = temp.reversed.toList();

      setState(() {
        posts = temp;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    getGroups();

    // set a timer to run after 1 seconds
    Timer(const Duration(seconds: 1), () {
      setState(() {
        selected = ContentType.popular;
        // print("${singleton.groupData}");
        timelineLoaded = true;
        getGroups();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (dropdownPairs.isNotEmpty) {
      String groupID = dropdownPairs
          .firstWhere((element) => element.key == dropdownValue)
          .value;
      if (groupID.isNotEmpty && posts.isEmpty) {
        // print("dropdownPairs: $dropdownPairs");
        getPosts(groupID);
      }
    }

    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
        ),
        drawer: Drawer(
          backgroundColor: const Color.fromARGB(255, 44, 44, 44),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                SizedBox(
                  height: SizeConfig.blockSizeVertical! * 10,
                ),
                (singleton.userData.containsKey("profile_image"))
                    ? SizedBox(
                        height: SizeConfig.blockSizeHorizontal! * 25,
                        width: SizeConfig.blockSizeHorizontal! * 25,
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: Image.network(
                              singleton.userData["profile_image"],
                              fit: BoxFit.cover,
                            )),
                      )
                    : SizedBox(
                        height: SizeConfig.blockSizeHorizontal! * 25,
                        width: SizeConfig.blockSizeHorizontal! * 25,
                        child: Image.asset("assets/generic_profile.png")),
                Text(
                  "${(Auth().user!.displayName != null) ? Auth().user!.displayName : 'User'}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20),
                ),
                Padding(
                    padding: const EdgeInsets.fromLTRB(85, 0, 85, 0),
                    child: ElevatedButton(
                        onPressed: () {
                          print("Edit profile");
                          Navigator.pushNamed(context, '/profile_edit');
                        },
                        child: const Text("Edit"))),
                Expanded(
                  child: ListView(
                    children: [
                      SizedBox(
                        height: SizeConfig.blockSizeVertical! * 5,
                        child: MenuButton(
                          text: "Create Post",
                          style: const TextStyle(
                              fontSize: 20, color: Colors.white),
                          onPressed: () {
                            Navigator.pushNamed(context, '/create');
                          },
                        ),
                      ),
                      SizedBox(height: SizeConfig.blockSizeVertical! * 2),
                      SizedBox(
                        height: SizeConfig.blockSizeVertical! * 5,
                        child: MenuButton(
                          text: "Your Yearbook",
                          style: const TextStyle(
                              fontSize: 20, color: Colors.white),
                          onPressed: () {
                            Navigator.pushNamed(context, '/yearbook');
                          },
                        ),
                      ),
                      SizedBox(height: SizeConfig.blockSizeVertical! * 2),
                      SizedBox(
                        height: SizeConfig.blockSizeVertical! * 5,
                        child: MenuButton(
                          text: "Add/Delete Friends",
                          style: const TextStyle(
                              fontSize: 20, color: Colors.white),
                          onPressed: () {
                            Navigator.pushNamed(context, '/received');
                          },
                        ),
                      ),
                      SizedBox(height: SizeConfig.blockSizeVertical! * 2),
                      SizedBox(
                        height: SizeConfig.blockSizeVertical! * 5,
                        child: MenuButton(
                          style: const TextStyle(
                              fontSize: 20, color: Colors.white),
                          text: "Manage Groups",
                          onPressed: () {
                            Navigator.pushNamed(context, '/group');
                          },
                        ),
                      ),
                      SizedBox(height: SizeConfig.blockSizeVertical! * 2),
                      SizedBox(
                        height: SizeConfig.blockSizeVertical! * 5,
                        child: MenuButton(
                          style: const TextStyle(
                              fontSize: 20, color: Colors.white),
                          text: "Settings",
                          onPressed: () {
                            Navigator.pushNamed(context, '/settings');
                          },
                        ),
                      ),
                      // TODO: add a "see personal yearbook" button
                      SizedBox(height: SizeConfig.blockSizeVertical! * 2),
                      SizedBox(
                        height: SizeConfig.blockSizeVertical! * 5,
                        child: MenuButton(
                          text: "Log Out",
                          style: const TextStyle(
                              fontSize: 20, color: Colors.white),
                          onPressed: () {
                            Auth().logout().then(
                              (value) {
                                Navigator.pushNamedAndRemoveUntil(
                                    context, '/', (route) => false);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        endDrawer: Drawer(child: Consumer(
          builder: (context, _singleton, child) {
            List<Widget> currentFriends = [];
            Map<String, dynamic> friends = singleton.userData['friends'];

            print("populating current friends list");
            friends.forEach((key, value) {
              print("key: $key, value: $value");
              currentFriends.add(FriendCard(
                type: FriendCardType.currentFriend,
                name: value['name'],
                uid: key,
                onPressed: () {
                  setState(() {
                    print("removing friend: $key");
                  });
                },
              ));
            });
            print("current friends list: $currentFriends");

            return ListView.builder(
              itemCount: currentFriends.length,
              itemBuilder: (context, index) {
                return currentFriends[index];
              },
            );
          },
        )),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                height: SizeConfig.blockSizeVertical! * 5,
                width: SizeConfig.blockSizeHorizontal! * 90,
                child: Consumer<Singleton>(
                  builder: (context, _singleton, child) {
                    // getGroups();
                    return DropdownButton(
                        value: dropdownValue,
                        items: dropdownItems.map<DropdownMenuItem<String>>(
                          (String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value,
                                  style: const TextStyle(fontSize: 20)),
                            );
                          },
                        ).toList(),
                        onChanged: (value) {
                          setState(() {
                            String groupID = dropdownPairs
                                .firstWhere((element) => element.key == value)
                                .value;
                            getPosts(groupID);
                          });
                        });
                  },
                  // child: DropdownButton(
                  //     value: dropdownValue,
                  //     items: dropdownItems.map<DropdownMenuItem<String>>(
                  //       (String value) {
                  //         return DropdownMenuItem<String>(
                  //           value: value,
                  //           child: Text(value),
                  //         );
                  //       },
                  //     ).toList(),
                  //     onChanged: (value) {
                  //       setState(() {
                  //         dropdownValue = value.toString();
                  //       });
                  //     }),
                ),
              ),
              SizedBox(
                width: SizeConfig.blockSizeHorizontal! * 90,
                height: SizeConfig.blockSizeVertical! * 5,
                child: SegmentedButton(
                    segments: <ButtonSegment<ContentType>>[
                      ButtonSegment<ContentType>(
                          value: ContentType.recent,
                          label: Container(
                              height: SizeConfig.blockSizeVertical! * 4,
                              alignment: Alignment.center,
                              child: const Text('Recent',
                                  style: TextStyle(fontSize: 20))),
                          icon: const Icon(CupertinoIcons.star)),
                      ButtonSegment<ContentType>(
                          value: ContentType.popular,
                          label: Container(
                              height: SizeConfig.blockSizeVertical! * 4,
                              alignment: Alignment.center,
                              child: const Text('Popular',
                                  style: TextStyle(fontSize: 20))),
                          icon: const Icon(CupertinoIcons.flame))
                    ],
                    selected: {
                      selected
                    },
                    onSelectionChanged: (value) {
                      setState(() {
                        print("VALUE: $value");
                        selected = value.first;
                        print("${singleton.groupData}");
                        getGroups();
                        getPosts(dropdownPairs
                            .firstWhere(
                                (element) => element.key == dropdownValue)
                            .value);
                      });
                    }),
              ),
              SizedBox(
                  height: SizeConfig.blockSizeVertical! * 70,
                  width: SizeConfig.blockSizeHorizontal! * 100,
                  // color: Colors.red,
                  child: (timelineLoaded)
                      ? ListView.builder(
                          itemCount: posts.length,
                          itemBuilder: (context, index) {
                            return PostCard(
                                id: posts[index].id,
                                creator: posts[index].creator,
                                mediaURL: posts[index].mediaURL,
                                mediaType: posts[index].mediaType,
                                caption: posts[index].caption,
                                likes: posts[index].likes,
                                dislikes: posts[index].dislikes);
                          },
                        )
                      : const Center(
                          child: CircularProgressIndicator(),
                        ))
            ],
          ),
        ));
  }
}
