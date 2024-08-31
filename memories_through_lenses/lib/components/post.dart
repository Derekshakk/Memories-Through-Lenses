import 'package:flutter/material.dart';
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
    this.likes = 0,
    this.dislikes = 0,
  });
  final String id;
  final String mediaURL;
  final String mediaType;
  int likes = 0;
  int dislikes = 0;
  final String caption;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
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
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      height: SizeConfig.blockSizeHorizontal! * 90,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
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
                                      widget.likes++;
                                      Database().likePost(widget.id);
                                    });
                                  },
                                ),
                              ),
                              Text("${widget.likes}")
                            ],
                          ),
                          SizedBox(
                            width: SizeConfig.blockSizeHorizontal! * 3,
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
                                      widget.dislikes++;
                                      Database().dislikePost(widget.id);
                                    });
                                  },
                                ),
                              ),
                              Text("${widget.dislikes}"),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(widget.caption),
        ],
      ),
    );
  }
}
