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
  final String userOpinion; // "like", "dislike", or "none"
  PostData(
      {required this.id,
      required this.creator,
      required this.mediaURL,
      required this.mediaType,
      required this.caption,
      required this.likes,
      required this.dislikes,
      required this.created_at,
      this.userOpinion = "none"}); // default is "none" if not specified
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

  List<String> dropdownItems = [];
  List<Pair> dropdownPairs = [];
  String? dropdownValue;

  // list of posts (mediaURL, likes, dislikes)
  List<PostData> posts = [];

  void getGroups() {
    if (singleton.groupData == null) return;
    
    String? previousValue = dropdownValue;
    dropdownItems.clear();
    dropdownPairs.clear();
    
    List<Map<String, dynamic>> groups = singleton.groupData;
    for (var element in groups) {
      String name = element['name'] ?? '';
      String groupID = element['groupID'] ?? '';
      if (name.isNotEmpty && groupID.isNotEmpty) {
        dropdownItems.add(name);
        dropdownPairs.add(Pair(name, groupID));
      }
    }

    if (dropdownItems.isNotEmpty) {
      if (previousValue != null && dropdownItems.contains(previousValue)) {
        dropdownValue = previousValue;
      } else {
        dropdownValue = dropdownItems[0];
      }
    }
  }

  void getPosts(String groupID) {
    Database()
        .getPosts(
            groupID, (selected == ContentType.popular) ? 'popular' : 'newest')
        .then((value) {
      List<PostData> temp = [];
      List<dynamic> blockedUsers = singleton.userData?['blocked'] ?? [];
      List<dynamic> blockedPosts = singleton.userData?['reported_posts'] ?? [];

      for (var element in value) {
        if (blockedUsers.contains(element['user_id']) ||
            blockedPosts.contains(element['id'])) {
          continue;
        }

        String userOpinion = "none";
        if (element['likes']?.contains(singleton.userData?['uid']) ?? false) {
          userOpinion = "like";
        } else if (element['dislikes']?.contains(singleton.userData?['uid']) ?? false) {
          userOpinion = "dislike";
        }

        temp.add(PostData(
          id: element['id'] ?? '',
          creator: element['user_id'] ?? '',
          mediaURL: element['image_url'] ?? '',
          mediaType: 'image',
          caption: element['caption'] ?? '',
          likes: element['likes']?.length ?? 0,
          dislikes: element['dislikes']?.length ?? 0,
          created_at: element['created_at'] != null 
              ? DateTime.fromMillisecondsSinceEpoch(
                  element['created_at'].seconds * 1000)
              : DateTime.now(),
          userOpinion: userOpinion,
        ));
      }

      temp = temp.reversed.toList();
      if (mounted) {
        setState(() {
          posts = temp;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    getGroups();

    Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          selected = ContentType.popular;
          timelineLoaded = true;
          getGroups();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  "${singleton.userData['name'] ?? 'User'}",
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
                          text: "Scan Face",
                          style: const TextStyle(
                              fontSize: 20, color: Colors.white),
                          onPressed: () {
                            Navigator.pushNamed(context, '/scan_face');
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
                      SizedBox(height: SizeConfig.blockSizeVertical! * 2),
                      SizedBox(
                        height: SizeConfig.blockSizeVertical! * 5,
                        child: MenuButton(
                          text: "Log Out",
                          style: const TextStyle(
                              fontSize: 20, color: Colors.white),
                          onPressed: () async {
                            try {
                              await Auth().logout();
                              if (mounted) {
                                Navigator.pushReplacementNamed(context, '/');
                              }
                            } catch (e) {
                              print('Error during logout: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Error logging out. Please try again.'),
                                  ),
                                );
                              }
                            }
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
            Map<String, dynamic>? friends = singleton.userData?['friends'] as Map<String, dynamic>?;

            if (friends != null) {
              friends.forEach((key, value) {
                if (value != null && value['name'] != null) {
                  currentFriends.add(FriendCard(
                    type: FriendCardType.currentFriend,
                    name: value['name'],
                    uid: key,
                    onPressed: () {
                      setState(() {
                        // Handle friend removal here
                      });
                    },
                  ));
                }
              });
            }

            return SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "Friends",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: currentFriends.isEmpty
                        ? const Center(
                            child: Text(
                              'No friends yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: currentFriends.length,
                            itemBuilder: (context, index) {
                              return currentFriends[index];
                            },
                          ),
                  ),
                ],
              ),
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
                    if (dropdownItems.isEmpty) {
                      return const Center(
                        child: Text('No groups available',
                            style: TextStyle(fontSize: 20)),
                      );
                    }
                    
                    return DropdownButton<String>(
                      value: dropdownValue,
                      hint: const Text('Select a group',
                          style: TextStyle(fontSize: 20)),
                      items: dropdownItems.map<DropdownMenuItem<String>>(
                        (String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value,
                                style: const TextStyle(fontSize: 20)),
                          );
                        },
                      ).toList(),
                      onChanged: (String? value) {
                        if (value == null) return;
                        
                        final groupPair = dropdownPairs
                            .firstWhere((element) => element.key == value,
                                orElse: () => Pair('', ''));
                                
                        if (groupPair.value.isEmpty) return;
                        
                        setState(() {
                          dropdownValue = value;
                        });
                        getPosts(groupPair.value);
                      },
                    );
                  },
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
                            style: TextStyle(fontSize: 20)),
                      ),
                      icon: const Icon(CupertinoIcons.star),
                    ),
                    ButtonSegment<ContentType>(
                      value: ContentType.popular,
                      label: Container(
                        height: SizeConfig.blockSizeVertical! * 4,
                        alignment: Alignment.center,
                        child: const Text('Popular',
                            style: TextStyle(fontSize: 20)),
                      ),
                      icon: const Icon(CupertinoIcons.flame),
                    ),
                  ],
                  selected: {selected},
                  onSelectionChanged: (value) {
                    setState(() {
                      selected = value.first;
                    });
                    
                    if (dropdownValue != null) {
                      final groupPair = dropdownPairs
                          .firstWhere((element) => element.key == dropdownValue,
                              orElse: () => Pair('', ''));
                      if (groupPair.value.isNotEmpty) {
                        getPosts(groupPair.value);
                      }
                    }
                  },
                ),
              ),
              SizedBox(
                height: SizeConfig.blockSizeVertical! * 70,
                width: SizeConfig.blockSizeHorizontal! * 100,
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
                            dislikes: posts[index].dislikes,
                            userOpinion: posts[index].userOpinion,
                          );
                        },
                      )
                    : const Center(
                        child: CircularProgressIndicator(),
                      ),
              ),
            ],
          ),
        ));
  }
}
