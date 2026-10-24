import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:memories_through_lenses/services/username.dart';
import 'package:memories_through_lenses/theme/app_colors.dart';

class Comment extends StatefulWidget {
  const Comment({
    super.key,
    required this.description,
    required this.profilePic,
    required this.username,
    required this.date,
    required this.likes,
    required this.postId,
    required this.commentId,
    this.authorId = '',
    this.isReply = false,
    this.replyToName,
    this.onReply,
    this.onReport,
    this.onDelete,
  });
  final String profilePic;
  final String description;
  final String username;
  final String date;
  final List<dynamic> likes;
  final String postId;
  final String commentId;
  final String authorId;

  /// Replies are indented under their top-level comment.
  final bool isReply;
  final String? replyToName;
  final VoidCallback? onReply;
  final VoidCallback? onReport;
  final VoidCallback? onDelete;

  @override
  State<Comment> createState() => _CommentState();
}

class _CommentState extends State<Comment> {
  bool isLiked = false;
  late List<dynamic> currentLikes;

  @override
  void initState() {
    super.initState();
    currentLikes = List.from(widget.likes);
    checkIfLiked();
  }

  @override
  void didUpdateWidget(Comment oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Live updates from the comment stream: adopt server likes.
    if (oldWidget.likes.length != widget.likes.length ||
        oldWidget.commentId != widget.commentId) {
      currentLikes = List.from(widget.likes);
      checkIfLiked();
    }
  }

  void checkIfLiked() {
    final currentUser = Auth().user?.uid;
    if (currentUser != null) {
      isLiked = currentLikes.contains(currentUser);
    }
  }

  void toggleLike() async {
    final currentUser = Auth().user?.uid;
    if (currentUser == null) return;

    final wasLiked = isLiked;
    setState(() {
      if (wasLiked) {
        currentLikes.remove(currentUser);
      } else {
        currentLikes.add(currentUser);
      }
      isLiked = !wasLiked;
    });
    try {
      if (wasLiked) {
        await Database().removeLikeComment(widget.postId, widget.commentId);
      } else {
        await Database().likeComment(widget.postId, widget.commentId);
      }
    } catch (e) {
      debugPrint('Error toggling comment like: $e');
      if (!mounted) return;
      setState(() {
        if (wasLiked) {
          currentLikes.add(currentUser);
        } else {
          currentLikes.remove(currentUser);
        }
        isLiked = wasLiked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarRadius = widget.isReply ? 15.0 : 20.0;
    final hasMenu = widget.onReport != null || widget.onDelete != null;
    return InkWell(
      // Long-press still reports, as before (now actually submitting).
      onLongPress: widget.onReport,
      child: Container(
        color: AppColors.surface(context),
        padding: EdgeInsets.fromLTRB(widget.isReply ? 56.0 : 8.0, 8.0, 0, 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            widget.profilePic.isEmpty
                ? CircleAvatar(
                    radius: avatarRadius,
                    backgroundImage:
                        const AssetImage("assets/generic_profile.png"),
                  )
                : CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: CachedNetworkImageProvider(
                      widget.profilePic,
                      maxHeight: 100,
                      maxWidth: 100,
                    ),
                  ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          Username.displayName(widget.username),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(widget.date,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Full text with the author's own line breaks preserved.
                  Text.rich(
                    TextSpan(children: [
                      if (widget.replyToName != null)
                        TextSpan(
                          text: '@${Username.displayName(widget.replyToName)} ',
                          style: const TextStyle(
                              color: Colors.blue, fontWeight: FontWeight.w500),
                        ),
                      TextSpan(text: widget.description),
                    ]),
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (widget.onReply != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: widget.onReply,
                      child: const Text('Reply'),
                    ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  onPressed: toggleLike,
                  tooltip: isLiked ? 'Unlike' : 'Like',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : null,
                    size: 20,
                  ),
                ),
                Text(currentLikes.length.toString(),
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
            if (hasMenu)
              PopupMenuButton<String>(
                tooltip: 'More',
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) {
                  if (value == 'report') widget.onReport?.call();
                  if (value == 'delete') widget.onDelete?.call();
                },
                itemBuilder: (context) => [
                  if (widget.onReport != null)
                    const PopupMenuItem(
                      value: 'report',
                      child: ListTile(
                        leading: Icon(Icons.flag_outlined),
                        title: Text('Report'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  if (widget.onDelete != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: Colors.red),
                        title: Text('Delete',
                            style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                ],
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
