import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:memories_through_lenses/components/buttons.dart';
import 'package:memories_through_lenses/components/friend_card.dart';
import 'package:memories_through_lenses/components/post.dart';
import 'package:memories_through_lenses/providers/user_provider.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:memories_through_lenses/services/streams.dart';
import 'package:memories_through_lenses/size_config.dart';
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

// Separate StatefulWidget for SearchBar to prevent rebuilds
class SearchBarWidget extends StatefulWidget {
  final Function(String) onSearch;
  final VoidCallback onClear;

  const SearchBarWidget({
    super.key,
    required this.onSearch,
    required this.onClear,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _controller = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _controller.text.trim();
    setState(() {
      _isSearching = query.isNotEmpty;
    });
    widget.onSearch(query);
  }

  void _clearSearch() {
    _controller.clear();
    setState(() {
      _isSearching = false;
    });
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: 'Search posts by caption...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _isSearching
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
        onChanged: (value) {
          _performSearch();
        },
      ),
    );
  }
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
  ContentType selected = ContentType.popular;
  late FocusNode _focusNode;

  // Each Pair holds (key: group display name, value: stable Firestore groupID).
  // The dropdown is keyed on the groupID (unique) — never the display name,
  // since two groups can legitimately share the same name.
  List<Pair> dropdownPairs = [];
  // Currently selected groupID (stable unique id), or null when no groups.
  String? dropdownValue;

  // list of posts (mediaURL, likes, dislikes)
  List<PostData> posts = [];
  List<PostData> filteredPosts = [];
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    // Load initial data from provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<UserProvider>(context, listen: false);
      provider.refreshAll();
    });
  }

  void _updateDropdownFromGroups(List<Map<String, dynamic>> groups) {
    String? previousValue = dropdownValue;
    dropdownPairs.clear();

    // Build the item list, de-duplicating on the stable groupID so that a
    // duplicated Firestore doc can never produce two items with the same value.
    // Display names are intentionally NOT de-duplicated (two groups may share
    // a name); the groupID keeps them distinct.
    final Set<String> seenGroupIds = {};
    for (var group in groups) {
      String name = group['name'] ?? '';
      String groupID = group['groupID'] ?? '';
      if (name.isNotEmpty && groupID.isNotEmpty && seenGroupIds.add(groupID)) {
        dropdownPairs.add(Pair(name, groupID));
      }
    }

    // Reconcile the selected value so DropdownButton always has exactly one
    // matching item. If the previously selected group is still present, keep
    // it; otherwise fall back to the first group, or null when there are none.
    final bool previousStillPresent = previousValue != null &&
        dropdownPairs.any((pair) => pair.value == previousValue);
    if (previousStillPresent) {
      dropdownValue = previousValue;
    } else if (dropdownPairs.isNotEmpty) {
      dropdownValue = dropdownPairs.first.value;
    } else {
      dropdownValue = null;
    }
  }

  void getPosts(String groupID, Map<String, dynamic>? userData) {
    Database()
        .getPosts(
            groupID, (selected == ContentType.popular) ? 'popular' : 'newest')
        .then((value) {
      List<PostData> temp = [];
      List<dynamic> blockedUsers = userData?['blocked'] ?? [];
      List<dynamic> blockedPosts = userData?['reported_posts'] ?? [];
      String currentUserId = Auth().user?.uid ?? '';

      for (var element in value) {
        print('Checking post: ${element['id']}');
        if (blockedUsers.contains(element['user_id']) ||
            blockedPosts.contains(element['id'])) {
          print('  -> BLOCKED (reported or user blocked)');
          continue;
        }
        print('  -> ADDED to feed');

        String userOpinion = "none";
        if (element['likes']?.contains(currentUserId) ?? false) {
          userOpinion = "like";
        } else if (element['dislikes']?.contains(currentUserId) ?? false) {
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

  void _handleSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredPosts = List.from(posts);
        isSearching = false;
      });
    } else {
      final filtered = posts.where((post) {
        return post.caption.toLowerCase().contains(query.toLowerCase());
      }).toList();

      setState(() {
        filteredPosts = filtered;
        isSearching = true;
      });
    }
  }

  void _handleClearSearch() {
    setState(() {
      filteredPosts = List.from(posts);
      isSearching = false;
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: AppStreams.userDataStream,
      builder: (context, userSnapshot) {
        // Check if user is authenticated
        if (Auth().user == null) {
          // User logged out, return empty container while auth state changes
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Get user data from stream
        Map<String, dynamic>? userData;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          userData = userSnapshot.data!.data();
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: AppStreams.userGroupsStream,
          builder: (context, groupsSnapshot) {
            // Update dropdown when groups change
            if (groupsSnapshot.hasData) {
              List<Map<String, dynamic>> groups =
                  groupsSnapshot.data!.docs.map((doc) {
                final data = doc.data();
                data['groupID'] = doc.id;
                return data;
              }).toList();

              // Update dropdown items if groups changed
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _updateDropdownFromGroups(groups);
                    // Auto-load posts for first group (dropdownValue is a groupID)
                    if (dropdownValue != null && posts.isEmpty) {
                      getPosts(dropdownValue!, userData);
                    }
                  });
                }
              });
            }

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
                        (userData?.containsKey("profile_image") ?? false)
                            ? SizedBox(
                                height: SizeConfig.blockSizeHorizontal! * 25,
                                width: SizeConfig.blockSizeHorizontal! * 25,
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(100),
                                    child: CachedNetworkImage(
                                      imageUrl: userData!["profile_image"],
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          const CircularProgressIndicator(),
                                      errorWidget: (context, url, error) =>
                                          Image.asset(
                                              "assets/generic_profile.png"),
                                    )),
                              )
                            : SizedBox(
                                height: SizeConfig.blockSizeHorizontal! * 25,
                                width: SizeConfig.blockSizeHorizontal! * 25,
                                child:
                                    Image.asset("assets/generic_profile.png")),
                        Text(
                          "${userData?['name'] ?? 'User'}",
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
                              SizedBox(
                                  height: SizeConfig.blockSizeVertical! * 2),
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
                              SizedBox(
                                  height: SizeConfig.blockSizeVertical! * 2),
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
                              SizedBox(
                                  height: SizeConfig.blockSizeVertical! * 2),
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
                              SizedBox(
                                  height: SizeConfig.blockSizeVertical! * 2),
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
                              SizedBox(
                                  height: SizeConfig.blockSizeVertical! * 2),
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
                              SizedBox(
                                  height: SizeConfig.blockSizeVertical! * 2),
                              SizedBox(
                                height: SizeConfig.blockSizeVertical! * 5,
                                child: MenuButton(
                                  text: "Log Out",
                                  style: const TextStyle(
                                      fontSize: 20, color: Colors.white),
                                  onPressed: () async {
                                    try {
                                      // Clear provider data first
                                      final provider =
                                          Provider.of<UserProvider>(context,
                                              listen: false);
                                      provider.clear();

                                      // Then logout - StreamBuilder will handle navigation
                                      await Auth().logout();
                                    } catch (e) {
                                      print('Error during logout: $e');
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
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
                endDrawer: Drawer(
                  child: SafeArea(
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
                          child: userData == null ||
                                  ((userData['friends']
                                              as Map<String, dynamic>?)
                                          ?.isEmpty ??
                                      true)
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
                                  itemCount: (userData!['friends']
                                          as Map<String, dynamic>)
                                      .length,
                                  itemBuilder: (context, index) {
                                    final friends = userData!['friends']
                                        as Map<String, dynamic>;
                                    final entry =
                                        friends.entries.elementAt(index);
                                    return FriendCard(
                                      type: FriendCardType.currentFriend,
                                      name: entry.value['name'] ?? 'Unknown',
                                      uid: entry.key,
                                      onPressed: () {
                                        setState(() {
                                          // Handle friend removal here
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                body: Column(
                  children: [
                    SearchBarWidget(
                      onSearch: _handleSearch,
                      onClear: _handleClearSearch,
                    ),
                    // Fixed header section
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Column(
                        children: [
                          // Group selector
                          SizedBox(
                            height: SizeConfig.blockSizeVertical! * 5,
                            width: SizeConfig.blockSizeHorizontal! * 90,
                            child: dropdownPairs.isEmpty
                                ? const Center(
                                    child: Text('No groups available',
                                        style: TextStyle(fontSize: 20)),
                                  )
                                : DropdownButton<String>(
                                    // value is a groupID; items are keyed by
                                    // groupID so exactly one item always matches.
                                    value: dropdownValue,
                                    hint: const Text('Select a group',
                                        style: TextStyle(fontSize: 20)),
                                    items: dropdownPairs
                                        .map<DropdownMenuItem<String>>(
                                      (Pair pair) {
                                        return DropdownMenuItem<String>(
                                          value: pair.value,
                                          child: Text(pair.key,
                                              style: const TextStyle(
                                                  fontSize: 20)),
                                        );
                                      },
                                    ).toList(),
                                    onChanged: (String? value) {
                                      if (value == null) return;

                                      setState(() {
                                        dropdownValue = value;
                                      });
                                      getPosts(value, userData);
                                    },
                                  ),
                          ),
                          SizedBox(
                            width: SizeConfig.blockSizeHorizontal! * 90,
                            height: SizeConfig.blockSizeVertical! * 7,
                            child: SegmentedButton(
                              selectedIcon: selected == ContentType.recent
                                  ? Icon(CupertinoIcons.star)
                                  : Icon(CupertinoIcons.flame),
                              segments: <ButtonSegment<ContentType>>[
                                ButtonSegment<ContentType>(
                                  value: ContentType.recent,
                                  label: Container(
                                    height: SizeConfig.blockSizeVertical! * 3,
                                    alignment: Alignment.center,
                                    child: const Text('Recent',
                                        style: TextStyle(fontSize: 20)),
                                  ),
                                  icon: const Icon(CupertinoIcons.star),
                                ),
                                ButtonSegment<ContentType>(
                                  value: ContentType.popular,
                                  label: Container(
                                    height: SizeConfig.blockSizeVertical! * 3,
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
                                  print(selected);
                                });

                                if (dropdownValue != null) {
                                  // dropdownValue is a groupID.
                                  getPosts(dropdownValue!, userData);
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
                      child: filteredPosts.isEmpty && isSearching
                          ? const Center(
                              child: Text(
                                'No posts found matching your search',
                                style:
                                    TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            )
                          : filteredPosts.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Select a group to view posts',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.grey),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: filteredPosts.length,
                                  itemBuilder: (context, index) {
                                    return PostCard(
                                      // Stable per-post key so Flutter keeps
                                      // each PostCard's State attached to the
                                      // same post when the list is reordered
                                      // (e.g. switching Popular/Recent) instead
                                      // of recycling State by list position,
                                      // which made like/dislike counts appear
                                      // on the wrong posts.
                                      key: ValueKey(filteredPosts[index].id),
                                      id: filteredPosts[index].id,
                                      creator: filteredPosts[index].creator,
                                      mediaURL: filteredPosts[index].mediaURL,
                                      mediaType: filteredPosts[index].mediaType,
                                      caption: filteredPosts[index].caption,
                                      created_at:
                                          filteredPosts[index].created_at,
                                      likes: filteredPosts[index].likes,
                                      dislikes: filteredPosts[index].dislikes,
                                      userOpinion:
                                          filteredPosts[index].userOpinion,
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
