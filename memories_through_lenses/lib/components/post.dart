import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:memories_through_lenses/screens/comments.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:video_player/video_player.dart';

// ignore: must_be_immutable
class PostCard extends StatefulWidget {
  PostCard({
    super.key,
    required this.id,
    required this.mediaURL,
    required this.mediaType,
    required this.caption,
    required this.creator,
    required this.created_at,
    this.likes = 0,
    this.dislikes = 0,
    this.userOpinion = "none",
  });

  final String id;
  final String mediaURL;
  final String mediaType;
  final String creator;
  final DateTime created_at;
  int likes = 0;
  int dislikes = 0;
  final String caption;
  String userOpinion; // "like", "dislike", or "none"

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  Map<String, dynamic>? userData;
  bool isLoadingUserData = true;
  int commentCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchCommentCount();
  }

  Future<void> _fetchUserData() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.creator)
          .get();

      if (mounted) {
        setState(() {
          userData = userDoc.data() as Map<String, dynamic>?;
          isLoadingUserData = false;
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
      if (mounted) {
        setState(() {
          isLoadingUserData = false;
        });
      }
    }
  }

  Future<void> _fetchCommentCount() async {
    try {
      QuerySnapshot commentsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.id)
          .collection('comments')
          .get();

      if (mounted) {
        setState(() {
          commentCount = commentsSnapshot.docs.length;
        });
      }
    } catch (e) {
      print('Error fetching comment count: $e');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      // Show full date for posts older than a week (MM/DD/YYYY format)
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      // Show days ago for posts within a week
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      // Show hours ago for posts within a day
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      // Show minutes ago for posts within an hour
      return '${difference.inMinutes}m ago';
    } else {
      // Show "now" for very recent posts
      return 'now';
    }
  }

  @override
  Widget build(BuildContext context) {
    late VideoPlayerController _controller;
    if (widget.mediaType == "video") {
      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.mediaURL));
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // User info header
          Container(
            width: SizeConfig.blockSizeHorizontal! * 90,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Row(
              children: [
                // Profile image
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[300],
                  ),
                  child: isLoadingUserData
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: userData?['profile_image'] != null
                              ? Image.network(
                                  userData!['profile_image'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Image.asset(
                                      "assets/generic_profile.png",
                                      fit: BoxFit.cover,
                                    );
                                  },
                                )
                              : Image.asset(
                                  "assets/generic_profile.png",
                                  fit: BoxFit.cover,
                                ),
                        ),
                ),
                const SizedBox(width: 12),
                // User name and creation time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLoadingUserData
                            ? "Loading..."
                            : userData?['name'] ?? 'Unknown User',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatDateTime(widget.created_at),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: SizeConfig.blockSizeHorizontal! * 90,
            height: SizeConfig.blockSizeHorizontal! * 90,
            child: Card(
              color: Colors.blue,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10.0),
                    // ternary expression:
                    // (condition) ? (if true) : (if false)
                    child: (widget.mediaType == "image")
                        ? InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CommentScreen(
                                    id: widget.id,
                                    mediaURL: widget.mediaURL,
                                    mediaType: widget.mediaType,
                                    creator: widget.creator,
                                  ),
                                ),
                              );
                            },
                            child: Image.network(
                              widget.mediaURL,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (BuildContext context, Object error,
                                  StackTrace? stackTrace) {
                                return const Center(
                                  child: Text("Image not found"),
                                );
                              },
                            ),
                          )
                        : FutureBuilder(
                            future: _controller.initialize(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.done) {
                                return VideoPlayer(_controller);
                              } else {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                            },
                          ),
                  ),
                  // report button on the top right corner
                  if (widget.creator != Auth().user?.uid)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          SizeConfig.blockSizeHorizontal! * 76, 8, 8, 8),
                      child: SizedBox(
                        height: SizeConfig.blockSizeHorizontal! * 10,
                        width: SizeConfig.blockSizeHorizontal! * 10,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color.fromARGB(132, 158, 158, 158),
                              padding: const EdgeInsets.all(0.0)),
                          child: const Icon(
                            Icons.report,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return ReportPostPopup(
                                  postId: widget.id,
                                  postCreator: widget.creator,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (widget.caption.isNotEmpty)
            SizedBox(
                width: SizeConfig.blockSizeHorizontal! * 52,
                height: SizeConfig.blockSizeHorizontal! * 20,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: SingleChildScrollView(
                      child: MarkdownBody(
                        data: widget.caption,
                        styleSheet: MarkdownStyleSheet(
                          textAlign: WrapAlignment.center,
                          p: const TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // child: Text(
                  //   widget.caption,
                  //   textAlign: TextAlign.center,
                  // ),
                )),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: SizeConfig.blockSizeHorizontal! * 10,
                        height: SizeConfig.blockSizeHorizontal! * 10,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: EdgeInsets.all(0.0)),
                          child: Icon(
                            Icons.thumb_up,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              // widget.likes++;
                              // if the user has already liked the post, then remove the like
                              if (widget.userOpinion == "like") {
                                widget.likes--;
                                widget.userOpinion = "none";
                              } else if (widget.userOpinion == "dislike") {
                                widget.dislikes--;
                                widget.userOpinion = "like";
                                widget.likes++;
                              } else {
                                widget.userOpinion = "like";
                                widget.likes++;
                              }

                              Database().likePost(widget.id);
                            });
                          },
                        ),
                      ),
                      Text("${widget.likes}")
                    ],
                  ),
                  SizedBox(
                    width: SizeConfig.blockSizeHorizontal! * 5,
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: SizeConfig.blockSizeHorizontal! * 10,
                        height: SizeConfig.blockSizeHorizontal! * 10,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: EdgeInsets.all(0.0)),
                          child: Icon(
                            Icons.thumb_down,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              // widget.dislikes++;

                              // if the user has already disliked the post, then remove the dislike
                              if (widget.userOpinion == "dislike") {
                                widget.dislikes--;
                                widget.userOpinion = "none";
                              } else if (widget.userOpinion == "like") {
                                widget.likes--;
                                widget.userOpinion = "dislike";
                                widget.dislikes++;
                              } else {
                                widget.userOpinion = "dislike";
                                widget.dislikes++;
                              }

                              Database().dislikePost(widget.id);
                            });
                          },
                        ),
                      ),
                      Text("${widget.dislikes}"),
                    ],
                  ),
                  SizedBox(
                    width: SizeConfig.blockSizeHorizontal! * 5,
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: SizeConfig.blockSizeHorizontal! * 10,
                        height: SizeConfig.blockSizeHorizontal! * 10,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: EdgeInsets.all(0.0)),
                          child: Icon(
                            Icons.comment,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CommentScreen(
                                  id: widget.id,
                                  mediaURL: widget.mediaURL,
                                  mediaType: widget.mediaType,
                                  creator: widget.creator,
                                ),
                              ),
                            ).then((_) {
                              // Refresh comment count when returning
                              _fetchCommentCount();
                            });
                          },
                        ),
                      ),
                      Text("$commentCount"),
                    ],
                  ),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// report post popup
class ReportPostPopup extends StatelessWidget {
  const ReportPostPopup(
      {super.key, required this.postId, required this.postCreator});

  final String postId;
  final String postCreator;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Report Post"),
      content: const Text("Are you sure you want to report this post?"),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            Database().reportPost(postId, postCreator);
            Navigator.of(context).pop();
          },
          child: const Text("Report"),
        ),
        TextButton(
          onPressed: () {},
          child: Text("Block User"),
        )
      ],
    );
  }
}
