import 'package:flutter/material.dart';
import 'package:memories_through_lenses/components/post_image.dart';
import 'package:memories_through_lenses/components/report_dialog.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:video_player/video_player.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:memories_through_lenses/screens/comments.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memories_through_lenses/theme/app_colors.dart';

// ignore: must_be_immutable
class SmallPostCard extends StatefulWidget {
  SmallPostCard({
    super.key,
    required this.id,
    required this.mediaURL,
    required this.mediaType,
    required this.caption,
    required this.creator,
    required this.created_at,
    this.likes = 0,
    this.dislikes = 0,
  });
  final String id;
  final String mediaURL;
  final String mediaType;
  final String creator;
  int likes = 0;
  int dislikes = 0;
  final String caption;
  final DateTime created_at;

  @override
  State<SmallPostCard> createState() => _SmallPostCardState();
}

class _SmallPostCardState extends State<SmallPostCard> {
  String formatDate(DateTime date) {
    return "${date.month}/${date.day}";
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
          Text(
            formatDate(widget.created_at),
            style: GoogleFonts.merriweather(
              fontSize: 12,
              color: AppColors.text(context),
            ),
          ),
          SizedBox(
            width: SizeConfig.blockSizeHorizontal! * 40,
            height: SizeConfig.blockSizeHorizontal! * 40,
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
                                    caption: widget.caption,
                                  ),
                                ),
                              );
                            },
                            child: PostImage(
                              url: widget.mediaURL,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
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
                          onPressed: () => showReportPostDialog(
                            context,
                            postId: widget.id,
                            postCreator: widget.creator,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: SizeConfig.blockSizeHorizontal! * 40,
                  // height: SizeConfig.blockSizeHorizontal! * 10,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                        child: Text(
                      widget.caption,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 3,
                    )),
                  ),
                  // child: Text(
                  //   widget.caption,
                  //   textAlign: TextAlign.center,
                  // ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
