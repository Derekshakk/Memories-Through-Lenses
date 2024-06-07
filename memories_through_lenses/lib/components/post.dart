import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:video_player/video_player.dart';

class PostCard extends StatefulWidget {
  PostCard(
      {super.key,
      required this.mediaURL,
      required this.mediaType,
      this.likes = 0,
      this.dislikes = 0});
  final String mediaURL;
  final String mediaType;
  int likes = 0;
  int dislikes = 0;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        width: SizeConfig.blockSizeHorizontal! * 90,
        height: SizeConfig.blockSizeHorizontal! * 90,
        child: Card(
          color: Colors.blue,
          child: Stack(
            children: [
              Image.network(
                widget.mediaURL,
                width: SizeConfig.blockSizeHorizontal! * 100,
                height: SizeConfig.blockSizeHorizontal! * 100,
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
    );
  }
}
