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
import 'package:cloud_firestore/cloud_firestore.dart';

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
  late FocusNode _focusNode;

  List<String> dropdownItems = [];
  List<Pair> dropdownPairs = [];
  String? dropdownValue;

  // list of posts (mediaURL, likes, dislikes)
  List<PostData> posts = [];
  List<PostData> filteredPosts = [];
  
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    print( Auth().user?.uid);
    _focusNode = FocusNode();
    initializeData();

    // Add listener for when the screen gains focus (i.e., when returning from another screen)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.addListener(() {
        if (_focusNode.hasFocus) {
          refreshGroups();
        }
      });
    });
  }

  Future<void> initializeData() async {
    if (!mounted) return;

    try {
      // Wait for singleton data to be ready
      while (singleton.groupData == null && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (!mounted) return;

      setState(() {
        selected = ContentType.popular;
      });

      // Load initial groups data
      await refreshGroups();

      if (mounted) {
        setState(() {
          timelineLoaded = true;
        });
      }
    } catch (e) {
      print('Error initializing data: $e');
      if (mounted) {
        setState(() {
          timelineLoaded = true;
        });
      }
    }
  }

  Future<void> refreshGroups() async {

    try {
      // Get the latest groups data from Firestore
      QuerySnapshot userGroups = await FirebaseFirestore.instance
          .collection('groups')
          .where('members', arrayContains: Auth().user?.uid)
          .get();

      if (!mounted) return;

      setState(() {
        singleton.groupData = [];
        for (var doc in userGroups.docs) {
          Map<String, dynamic> groupData = doc.data() as Map<String, dynamic>;
          groupData["groupID"] = doc.id;
          singleton.groupData.add(groupData);
        }

        // Update the dropdown items
        String? previousValue = dropdownValue;
        dropdownItems.clear();
        dropdownPairs.clear();

        for (var group in singleton.groupData) {
          String name = group['name'] ?? '';
          String groupID = group['groupID'] ?? '';
          if (name.isNotEmpty && groupID.isNotEmpty) {
            dropdownItems.add(name);
            dropdownPairs.add(Pair(name, groupID));
          }
        }

        // Update selected group
        if (dropdownItems.isNotEmpty) {
          if (previousValue != null && dropdownItems.contains(previousValue)) {
            dropdownValue = previousValue;
          } else {
            dropdownValue = dropdownItems[0];
          }

          // Load posts for the selected group
          if (dropdownValue != null) {
            final groupPair = dropdownPairs.firstWhere(
                (element) => element.key == dropdownValue,
                orElse: () => Pair('', ''));
            if (groupPair.value.isNotEmpty) {
              getPosts(groupPair.value);
            }
          }
        } else {
          dropdownValue = null;
          posts.clear();
        }
      });
    } catch (e) {
      print('Error refreshing groups: $e');
      if (mounted) {
        setState(() {
          dropdownItems.clear();
          dropdownPairs.clear();
          dropdownValue = null;
          posts.clear();
        });
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
        } else if (element['dislikes']?.contains(singleton.userData?['uid']) ??
            false) {
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
          filteredPosts = temp; // Initialize filtered posts with all posts
        });
      }
    });
  }

  void _performSearch() {
    final searchQuery = _searchController.text.trim();
    if (searchQuery.isEmpty) {
      if (isSearching) {
        setState(() {
          filteredPosts = List.from(posts);
          isSearching = false;
        });
      }
    } else {
      final filtered = posts.where((post) {
        return post.caption.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
      
      // Only update if the results are different
      if (filtered.length != filteredPosts.length || !isSearching) {
        setState(() {
          filteredPosts = filtered;
          isSearching = true;
        });
      }
    }
  }

  void _filterPosts(String searchQuery) {
    // This method is no longer used but kept for compatibility
    _performSearch();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      filteredPosts = posts;
      isSearching = false;
    });
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search posts by caption...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: isSearching
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onSubmitted: (value) {
                _performSearch();
              },
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(25.0),
            ),
            child: IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: _performSearch,
              tooltip: 'Search',
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Focus(
        focusNode: _focusNode,
        child: Scaffold(
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
                                    Navigator.pushReplacementNamed(
                                        context, '/');
                                  }
                                } catch (e) {
                                  print('Error during logout: $e');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Error logging out. Please try again.'),
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
                Map<String, dynamic>? friends =
                    singleton.userData?['friends'] as Map<String, dynamic>?;

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
            body: Column(
              children: [
                _buildSearchBar(),
                // Fixed header section
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Column(
                    children: [
                      // Group selector
                      SizedBox(
                        height: SizeConfig.blockSizeVertical! * 5,
                        width: SizeConfig.blockSizeHorizontal! * 90,
                        child: dropdownItems.isEmpty
                            ? const Center(
                                child: Text('No groups available',
                                    style: TextStyle(fontSize: 20)),
                              )
                            : DropdownButton<String>(
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
                 
                                  final groupPair = dropdownPairs.firstWhere(
                                      (element) => element.key == value,
                                      orElse: () => Pair('', ''));
                 
                                  if (groupPair.value.isEmpty) return;
                 
                                  setState(() {
                                    dropdownValue = value;
                                  });
                                  getPosts(groupPair.value);
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
                            final groupPair = dropdownPairs.firstWhere(
                                (element) => element.key == dropdownValue,
                                orElse: () => Pair('', ''));
                            if (groupPair.value.isNotEmpty) {
                              getPosts(groupPair.value);
                            }
                          }
                        },
                      ),
                     ),
                      // Search bar

                    ],
                  ),
                ),
                // Scrollable posts section
                Expanded(
                  child: (timelineLoaded)
                      ? filteredPosts.isEmpty && isSearching
                          ? const Center(
                              child: Text(
                                'No posts found matching your search',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredPosts.length,
                              itemBuilder: (context, index) {
                                return PostCard(
                                  id: filteredPosts[index].id,
                                  creator: filteredPosts[index].creator,
                                  mediaURL: filteredPosts[index].mediaURL,
                                  mediaType: filteredPosts[index].mediaType,
                                  caption: filteredPosts[index].caption,
                                  created_at: filteredPosts[index].created_at,
                                  likes: filteredPosts[index].likes,
                                  dislikes: filteredPosts[index].dislikes,
                                  userOpinion: filteredPosts[index].userOpinion,
                                );
                              },
                            )
                      : const Center(
                          child: CircularProgressIndicator(),
                        ),
                ),
              ],
            )));
  }
}
