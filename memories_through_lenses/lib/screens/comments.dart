import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:video_player/video_player.dart';
import 'package:memories_through_lenses/size_config.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == "video") {
      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.mediaURL));
    }
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
                    color: Colors.blue,
                    width: SizeConfig.blockSizeHorizontal! * 100,
                    child: Column(
                      children: [
                        // comments
                        Expanded(
                          child: ListView(
                            children: [
                              Container(
                                height: SizeConfig.blockSizeVertical! * 15,
                                color: Colors.amber,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const CircleAvatar(
                                        radius: 20,
                                        backgroundImage: NetworkImage(
                                            'https://imageio.forbes.com/specials-images/imageserve/5d35eacaf1176b0008974b54/0x0.jpg?format=jpg&crop=4560,2565,x790,y784,safe&height=900&width=1600&fit=bounds'),
                                      ),
                                      Container(
                                        // color: Colors.white,
                                        width: SizeConfig.blockSizeHorizontal! *
                                            70,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text("Username"),
                                            Text(
                                                "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."),
                                            // TextButton(
                                            //   style: TextButton.styleFrom(
                                            //       padding: EdgeInsets.zero),
                                            //   onPressed: () {},
                                            //   child: Text("Reply"),
                                            // ),
                                            // TextButton(
                                            //   style: TextButton.styleFrom(
                                            //       padding: EdgeInsets.zero),
                                            //   onPressed: () {},
                                            //   child: Text("View Replies"),
                                            // )
                                          ],
                                        ),
                                      ),
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            onPressed: () {},
                                            icon: const Icon(
                                                Icons.favorite_border),
                                          ),
                                          Text("0"),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ),
                              ListTile(
                                title: const Text("Comment 2"),
                              ),
                              ListTile(
                                title: const Text("Comment 3"),
                              ),
                              ListTile(
                                title: const Text("Comment 4"),
                              ),
                              ListTile(
                                title: const Text("Comment 5"),
                              ),
                              ListTile(
                                title: const Text("Comment 6"),
                              ),
                              ListTile(
                                title: const Text("Comment 7"),
                              ),
                              ListTile(
                                title: const Text("Comment 8"),
                              ),
                              ListTile(
                                title: const Text("Comment 9"),
                              ),
                              ListTile(
                                title: const Text("Comment 10"),
                              ),
                            ],
                          ),
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
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {},
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
