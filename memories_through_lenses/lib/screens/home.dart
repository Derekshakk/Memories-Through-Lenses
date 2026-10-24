import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:memories_through_lenses/components/buttons.dart';
import 'package:memories_through_lenses/components/friend_card.dart';
import 'package:memories_through_lenses/components/post.dart';
import 'package:memories_through_lenses/providers/preferences_provider.dart';
import 'package:memories_through_lenses/providers/user_provider.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:memories_through_lenses/services/streams.dart';
import 'package:memories_through_lenses/services/username.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/theme/app_colors.dart';
import 'package:provider/provider.dart';

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
                  tooltip: 'Clear search',
                  onPressed: _clearSearch,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25.0),
          ),
          filled: true,
          fillColor: AppColors.subtle(context),
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
  late FeedSort selected;
  late FocusNode _focusNode;

  // Each Pair holds (key: group display name, value: stable Firestore groupID).
  // The dropdown is keyed on the groupID (unique) — never the display name,
  // since two groups can legitimately share the same name.
  List<Pair> dropdownPairs = [];
  // Currently selected groupID (stable unique id), or null when no groups.
  String? dropdownValue;

  // Live user document + groups. Subscribed ONCE in initState. These used to
  // be StreamBuilders whose stream getter returned a brand-new Firestore
  // stream on every build, and the groups builder scheduled a setState after
  // every frame — an endless rebuild/re-subscribe loop that kept the feed
  // (and its images) churning.
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _groupsSub;
  Map<String, dynamic>? userData;
  bool _groupsLoaded = false;
  String? _groupsError;

  // Unfiltered posts for the selected group, as returned by Firestore.
  List<Map<String, dynamic>> _rawPosts = [];
  // list of posts (mediaURL, likes, dislikes)
  List<PostData> posts = [];
  List<PostData> filteredPosts = [];
  bool isSearching = false;
  String _query = '';
  bool _loadingPosts = false;
  String? _postsError;
  int _postsRequest = 0;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    // Remembered across launches (PreferencesProvider persists it).
    selected = Provider.of<PreferencesProvider>(context, listen: false).feedSort;

    _userSub = AppStreams.userDataStream.listen((snapshot) {
      if (!mounted) return;
      final previous = userData;
      setState(() {
        userData = snapshot.exists ? snapshot.data() : null;
      });
      // Re-filter immediately when the user blocks someone or reports a post,
      // instead of waiting for the next manual refresh.
      if (!_sameFilters(previous, userData)) _applyFilters();
    }, onError: (Object e) {
      debugPrint('Error listening to user data: $e');
    });

    _groupsSub = AppStreams.userGroupsStream.listen((snapshot) {
      if (!mounted) return;
      final groups = snapshot.docs.map((doc) {
        final data = doc.data();
        data['groupID'] = doc.id;
        return data;
      }).toList();
      final before = dropdownValue;
      setState(() {
        _groupsLoaded = true;
        _groupsError = null;
        _updateDropdownFromGroups(groups);
      });
      // Load when the first group appears or the selected group disappears.
      if (dropdownValue != null &&
          (dropdownValue != before || _rawPosts.isEmpty && !_loadingPosts)) {
        getPosts(dropdownValue!);
      } else if (dropdownValue == null) {
        setState(() {
          _rawPosts = [];
          posts = [];
          filteredPosts = [];
        });
      }
    }, onError: (Object e) {
      debugPrint('Error listening to groups: $e');
      if (mounted) {
        setState(() {
          _groupsLoaded = true;
          _groupsError = 'Could not load your groups.';
        });
      }
    });
  }

  static bool _sameFilters(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    String key(Map<String, dynamic>? d) =>
        '${d?['blocked'] ?? const []}|${d?['reported_posts'] ?? const []}';
    return key(a) == key(b);
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

  Future<void> getPosts(String groupID) async {
    // Only the latest request may update the feed; switching group or sort
    // quickly must never let an older response overwrite a newer one.
    final request = ++_postsRequest;
    setState(() {
      _loadingPosts = true;
      _postsError = null;
    });
    try {
      final value = await Database()
          .getPosts(groupID, (selected == FeedSort.popular) ? 'popular' : 'newest')
          .timeout(const Duration(seconds: 20));
      if (!mounted || request != _postsRequest) return;
      _rawPosts = value;
      _loadingPosts = false;
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading posts: $e');
      if (!mounted || request != _postsRequest) return;
      setState(() {
        _loadingPosts = false;
        _postsError = e is TimeoutException
            ? 'Loading posts is taking too long. Check your connection.'
            : 'Could not load posts.';
      });
    }
  }

  void _applyFilters() {
    List<PostData> temp = [];
    List<dynamic> blockedUsers = userData?['blocked'] ?? [];
    List<dynamic> blockedPosts = userData?['reported_posts'] ?? [];
    String currentUserId = Auth().user?.uid ?? '';

    for (var element in _rawPosts) {
      if (blockedUsers.contains(element['user_id']) ||
          blockedPosts.contains(element['id'])) {
        continue;
      }

      String userOpinion = "none";
      if (element['likes']?.contains(currentUserId) ?? false) {
        userOpinion = "like";
      } else if (element['dislikes']?.contains(currentUserId) ?? false) {
        userOpinion = "dislike";
      }

      final createdAt = element['created_at'];
      temp.add(PostData(
        id: element['id'] ?? '',
        creator: element['user_id'] ?? '',
        mediaURL: element['image_url'] ?? '',
        mediaType: 'image',
        caption: element['caption'] ?? '',
        likes: element['likes']?.length ?? 0,
        dislikes: element['dislikes']?.length ?? 0,
        created_at: createdAt is Timestamp
            ? DateTime.fromMillisecondsSinceEpoch(createdAt.seconds * 1000)
            : DateTime.now(),
        userOpinion: userOpinion,
      ));
    }

    temp = temp.reversed.toList();
    if (mounted) {
      setState(() {
        posts = temp;
        _filter();
      });
    }
  }

  void _filter() {
    if (_query.isEmpty) {
      filteredPosts = List.from(posts);
      isSearching = false;
    } else {
      final q = _query.toLowerCase();
      filteredPosts =
          posts.where((post) => post.caption.toLowerCase().contains(q)).toList();
      isSearching = true;
    }
  }

  void _handleSearch(String query) {
    setState(() {
      _query = query;
      _filter();
    });
  }

  void _handleClearSearch() {
    setState(() {
      _query = '';
      _filter();
    });
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _groupsSub?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  Widget _buildFeed() {
    if (!_groupsLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_groupsError != null && dropdownPairs.isEmpty) {
      return _FeedMessage(icon: Icons.cloud_off, text: _groupsError!);
    }
    if (dropdownValue == null) {
      return const _FeedMessage(
        icon: Icons.groups_outlined,
        text: 'Join or create a group from the menu to see posts',
      );
    }
    if (_loadingPosts && posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_postsError != null && posts.isEmpty) {
      return _FeedMessage(
        icon: Icons.cloud_off,
        text: _postsError!,
        actionLabel: 'Retry',
        onAction: () => getPosts(dropdownValue!),
      );
    }
    final Widget content;
    if (filteredPosts.isEmpty) {
      content = _FeedMessage(
        icon: isSearching ? Icons.search_off : Icons.photo_library_outlined,
        text: isSearching
            ? 'No posts found matching your search'
            : 'No posts in this group yet',
        scrollable: true,
      );
    } else {
      content = ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: filteredPosts.length,
        itemBuilder: (context, index) {
          return PostCard(
            // Stable per-post key so Flutter keeps each PostCard's State
            // attached to the same post when the list is reordered (e.g.
            // switching Popular/Recent) instead of recycling State by list
            // position, which made like/dislike counts appear on the wrong
            // posts.
            key: ValueKey(filteredPosts[index].id),
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
      );
    }
    return RefreshIndicator(
      onRefresh: () => getPosts(dropdownValue!),
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);

    final friends = userData?['friends'];
    final Map<String, dynamic> friendMap =
        friends is Map<String, dynamic> ? friends : const {};
    final List<MapEntry<String, dynamic>> friendEntries =
        friendMap.entries.toList();

    return Focus(
      focusNode: _focusNode,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          // Explicit, distinct icons: both drawers used to show the same
          // default hamburger icon.
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          actions: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.people_alt_outlined),
                tooltip: 'Friends',
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ),
          ],
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
                                  Image.asset("assets/generic_profile.png"),
                            )),
                      )
                    : SizedBox(
                        height: SizeConfig.blockSizeHorizontal! * 25,
                        width: SizeConfig.blockSizeHorizontal! * 25,
                        child: Image.asset("assets/generic_profile.png")),
                Text(
                  Username.displayName(userData?['name'], fallback: 'User'),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
                      _menuItem(Icons.add_a_photo_outlined, "Create Post",
                          () => Navigator.pushNamed(context, '/create')),
                      _menuItem(Icons.menu_book_outlined, "Your Yearbook",
                          () => Navigator.pushNamed(context, '/yearbook')),
                      _menuItem(Icons.face_retouching_natural, "Scan Face",
                          () => Navigator.pushNamed(context, '/scan_face')),
                      _menuItem(Icons.person_add_alt_1_outlined,
                          "Add/Delete Friends",
                          () => Navigator.pushNamed(context, '/received')),
                      _menuItem(Icons.groups_outlined, "Manage Groups",
                          () => Navigator.pushNamed(context, '/group')),
                      _menuItem(Icons.settings_outlined, "Settings",
                          () => Navigator.pushNamed(context, '/settings')),
                      _menuItem(Icons.logout, "Log Out", () async {
                        try {
                          // Clear provider data first
                          final provider =
                              Provider.of<UserProvider>(context, listen: false);
                          provider.clear();

                          // Then logout - AuthGate will handle navigation
                          await Auth().logout();
                        } catch (e) {
                          print('Error during logout: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Error logging out. Please try again.'),
                              ),
                            );
                          }
                        }
                      }),
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
                  child: Row(
                    children: [
                      Icon(Icons.people_alt_outlined),
                      SizedBox(width: 8),
                      Text(
                        "Friends",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: userData == null
                      ? const Center(child: CircularProgressIndicator())
                      : friendEntries.isEmpty
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
                              itemCount: friendEntries.length,
                              itemBuilder: (context, index) {
                                final entry = friendEntries[index];
                                final value = entry.value;
                                return FriendCard(
                                  key: ValueKey('drawer_friend_${entry.key}'),
                                  type: FriendCardType.currentFriend,
                                  name: value is Map
                                      ? (value['name']?.toString() ?? 'Unknown')
                                      : 'Unknown',
                                  uid: entry.key,
                                  onPressed: () {},
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
                        ? Center(
                            child: Text(
                                _groupsLoaded
                                    ? 'No groups available'
                                    : 'Loading groups...',
                                style: const TextStyle(fontSize: 20)),
                          )
                        : DropdownButton<String>(
                            // value is a groupID; items are keyed by
                            // groupID so exactly one item always matches.
                            value: dropdownValue,
                            isExpanded: true,
                            hint: const Text('Select a group',
                                style: TextStyle(fontSize: 20)),
                            items: dropdownPairs.map<DropdownMenuItem<String>>(
                              (Pair pair) {
                                return DropdownMenuItem<String>(
                                  value: pair.value,
                                  child: Text(pair.key,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 20)),
                                );
                              },
                            ).toList(),
                            onChanged: (String? value) {
                              if (value == null) return;

                              setState(() {
                                dropdownValue = value;
                                _rawPosts = [];
                                posts = [];
                                filteredPosts = [];
                              });
                              getPosts(value);
                            },
                          ),
                  ),
                  SizedBox(
                    width: SizeConfig.blockSizeHorizontal! * 90,
                    height: SizeConfig.blockSizeVertical! * 7,
                    child: SegmentedButton<FeedSort>(
                      selectedIcon: selected == FeedSort.recent
                          ? const Icon(CupertinoIcons.star)
                          : const Icon(CupertinoIcons.flame),
                      segments: <ButtonSegment<FeedSort>>[
                        ButtonSegment<FeedSort>(
                          value: FeedSort.recent,
                          label: Container(
                            height: SizeConfig.blockSizeVertical! * 3,
                            alignment: Alignment.center,
                            child: const Text('Recent',
                                style: TextStyle(fontSize: 20)),
                          ),
                          icon: const Icon(CupertinoIcons.star),
                        ),
                        ButtonSegment<FeedSort>(
                          value: FeedSort.popular,
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
                        });
                        unawaited(Provider.of<PreferencesProvider>(context,
                                listen: false)
                            .setFeedSort(value.first));

                        if (dropdownValue != null) {
                          // dropdownValue is a groupID.
                          getPosts(dropdownValue!);
                        }
                      },
                    ),
                  ),
                  // Search bar
                ],
              ),
            ),
            // Scrollable posts section
            Expanded(child: _buildFeed()),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String text, VoidCallback onPressed) {
    return Padding(
      padding: EdgeInsets.only(bottom: SizeConfig.blockSizeVertical! * 2),
      // Minimum (not fixed) height so larger text sizes don't clip labels.
      child: ConstrainedBox(
        constraints:
            BoxConstraints(minHeight: SizeConfig.blockSizeVertical! * 5),
        child: MenuButton(
          icon: icon,
          text: text,
          style: const TextStyle(fontSize: 20, color: Colors.white),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _FeedMessage extends StatelessWidget {
  const _FeedMessage({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
    this.scrollable = false,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Inside a RefreshIndicator the message must scroll so pull-to-refresh
  /// still works on an empty feed.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
    if (!scrollable) return Center(child: body);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: body),
        ),
      ),
    );
  }
}
