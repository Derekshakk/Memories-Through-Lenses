import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:video_player/video_player.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/comment.dart';

class CommentScreen extends StatefulWidget {
  const CommentScreen(
      {super.key,
      required this.id,
      required this.mediaURL,
      required this.mediaType,
      required this.creator});
  final String id;
  final String mediaURL;
  final String mediaType;
  final String creator;

  @override
  State<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  late VideoPlayerController _controller;
  TextEditingController commentController = TextEditingController();

  List<Map<String, dynamic>> comments = [];

  String timestampToDateString(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return "${date.month}/${date.day}/${date.year}";
  }

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == "video") {
      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.mediaURL));
    }

    // get comments
    Database().getComments(widget.id).then((value) {
      setState(() {
        comments = value;
        print("Comments: $comments");
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    print(widget.mediaURL);
    return Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: Center(
            // TODO: add singlechildscrollview
            child: Column(
              children: [
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
                              ? Image.network(
                                  widget.mediaURL,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
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
                                    backgroundColor: const Color.fromARGB(
                                        132, 158, 158, 158),
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
                Expanded(
                  child: Container(
                    color: Colors.white,
                    width: SizeConfig.blockSizeHorizontal! * 100,
                    child: Column(
                      children: [
                        // comments
                        Expanded(
                          child: ListView.builder(
                              itemCount: comments.length,
                              itemBuilder: (context, index) {
                                return Comment(
                                  username: comments[index]["username"],
                                  profilePic: comments[index]["profilePic"],
                                  date: timestampToDateString(
                                      comments[index]["date"]),
                                  description: comments[index]["description"],
                                  likes: comments[index]["likes"],
                                  postId: widget.id,
                                  commentId: comments[index]["id"],
                                );
                              }),
                        ),
                        // comment input
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    hintText: "Add a comment...",
                                  ),
                                  controller: commentController,
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Database()
                                      .createComment(
                                          widget.id, commentController.text)
                                      .then((value) {
                                    // get comments
                                    Database()
                                        .getComments(widget.id)
                                        .then((value) {
                                      setState(() {
                                        comments = value;
                                        print("Comments: $comments");
                                      });
                                    });
                                  });
                                  commentController.clear();
                                },
                                child: const Text("Post"),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ));
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
