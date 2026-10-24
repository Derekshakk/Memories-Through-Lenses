import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memories_through_lenses/components/comment.dart';
import 'package:memories_through_lenses/components/comment_input.dart';
import 'package:memories_through_lenses/components/post_image.dart';
import 'package:memories_through_lenses/components/report_dialog.dart';
import 'package:memories_through_lenses/providers/user_provider.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:memories_through_lenses/services/comment_threads.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:memories_through_lenses/services/streams.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

/// Post detail: the photo, its full caption, and threaded comments.
class CommentScreen extends StatefulWidget {
  const CommentScreen({
    super.key,
    required this.id,
    required this.mediaURL,
    required this.mediaType,
    required this.creator,
    this.caption,
  });

  final String id;
  final String mediaURL;
  final String mediaType;
  final String creator;

  /// Full caption. When omitted (older call sites) it is loaded from the post.
  final String? caption;

  @override
  State<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  VideoPlayerController? _controller;
  Future<void>? _videoInit;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _commentsSub;
  List<Map<String, dynamic>> comments = [];
  bool _isLoading = true;
  String? _loadError;
  bool _submitting = false;

  String? _caption;

  // Live author names/photos keyed by uid. Comments store a copy of the
  // username at write time, which was usually empty (and goes stale after a
  // rename), so the current profile is preferred for display.
  final Map<String, Map<String, dynamic>> _authors = {};
  final Set<String> _authorRequests = {};

  // Comments the user reported (hidden for them, like reported posts).
  final Set<String> _hiddenComments = {};
  Set<String> _blockedUsers = {};

  // Reply target.
  String? _replyParentId;
  String? _replyToUid;
  String? _replyToName;
  String? _replyToText;

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == "video") {
      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.mediaURL));
      _videoInit = _controller!.initialize();
    }
    _caption = widget.caption;
    if (_caption == null) _loadCaption();

    final userData =
        Provider.of<UserProvider>(context, listen: false).userData;
    _hiddenComments.addAll(
        (userData?['reported_comments'] as List?)?.whereType<String>() ??
            const <String>[]);
    _blockedUsers =
        ((userData?['blocked'] as List?)?.whereType<String>() ?? const [])
            .toSet();

    _subscribe();
  }

  void _subscribe() {
    _commentsSub?.cancel();
    setState(() {
      _isLoading = comments.isEmpty;
      _loadError = null;
    });
    // Live: new comments/replies (including your own, before the server
    // confirms them) appear without a manual reload.
    _commentsSub = AppStreams.getPostCommentsStream(widget.id).listen(
      (snapshot) {
        if (!mounted) return;
        final list = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          if (data['profilePic'] is! String) data['profilePic'] = '';
          return data;
        }).toList();
        setState(() {
          comments = list;
          _isLoading = false;
          _loadError = null;
        });
        _loadAuthors(list);
      },
      onError: (Object e) {
        debugPrint('Error loading comments: $e');
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _loadError = 'Could not load comments.';
        });
      },
    );
  }

  Future<void> _loadCaption() async {
    try {
      final post =
          await Database().getPost(widget.id).timeout(const Duration(seconds: 15));
      if (mounted) setState(() => _caption = post?['caption'] ?? '');
    } catch (e) {
      debugPrint('Error loading caption: $e');
    }
  }

  void _loadAuthors(List<Map<String, dynamic>> list) {
    final missing = list
        .map((c) => c['uid'])
        .whereType<String>()
        .where((uid) => uid.isNotEmpty && _authorRequests.add(uid))
        .toList();
    for (final uid in missing) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 15))
          .then((doc) {
        if (!mounted) return;
        final data = doc.data();
        if (data != null) setState(() => _authors[uid] = data);
      }).catchError((Object e) {
        debugPrint('Error loading comment author: $e');
        _authorRequests.remove(uid); // allow a later retry
      });
    }
  }

  String _nameFor(Map<String, dynamic> comment) {
    final live = _authors[comment['uid']]?['name'];
    if (live is String && live.trim().isNotEmpty) return live;
    final stored = comment['username'];
    if (stored is String && stored.trim().isNotEmpty) return stored;
    return _authors.containsKey(comment['uid']) ||
            !_authorRequests.contains(comment['uid'])
        ? 'Unknown User'
        : '…';
  }

  String _photoFor(Map<String, dynamic> comment) {
    final live = _authors[comment['uid']]?['profile_image'];
    if (live is String && live.isNotEmpty) return live;
    final stored = comment['profilePic'];
    return stored is String ? stored : '';
  }

  @override
  void dispose() {
    _commentsSub?.cancel();
    _commentController.dispose();
    _inputFocus.dispose();
    _controller?.dispose();
    super.dispose();
  }

  String _formatDate(Object? raw) {
    final date = commentDate(raw);
    return "${date.month}/${date.day}/${date.year}";
  }

  void _startReply(Map<String, dynamic> comment, {String? threadRootId}) {
    setState(() {
      // Replies are one level deep: replying to a reply joins its thread.
      _replyParentId = threadRootId ?? comment['id'] as String;
      _replyToUid = comment['uid'] as String?;
      _replyToName = _nameFor(comment);
      _replyToText = comment['description']?.toString();
    });
    _inputFocus.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyParentId = null;
      _replyToUid = null;
      _replyToName = null;
      _replyToText = null;
    });
  }

  Future<void> _postComment() async {
    // Trim only the ends: line breaks inside the comment are kept.
    final text = _commentController.text.trim();
    if (text.isEmpty || _submitting) return;

    setState(() => _submitting = true);
    try {
      final name =
          Provider.of<UserProvider>(context, listen: false).userData?['name'];
      await Database().createComment(
        widget.id,
        text,
        username: name is String ? name : null,
        parentId: _replyParentId,
        replyToUid: _replyParentId == null ? null : _replyToUid,
        replyToName: _replyParentId == null ? null : _replyToName,
      );
      if (!mounted) return;
      _commentController.clear();
      _cancelReply();
    } catch (e) {
      debugPrint('Error posting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not post your comment. Please try again.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _reportComment(Map<String, dynamic> comment) async {
    final id = comment['id'] as String;
    final outcome = await showReportCommentDialog(
      context,
      postId: widget.id,
      commentId: id,
      commentText: comment['description']?.toString() ?? '',
      commentAuthor: comment['uid']?.toString() ?? '',
    );
    if (outcome == ReportOutcome.reported && mounted) {
      // Hidden for the reporter (recorded in their reported_comments).
      setState(() => _hiddenComments.add(id));
      unawaited(
          Provider.of<UserProvider>(context, listen: false).loadUserData());
    }
  }

  Future<void> _deleteComment(Map<String, dynamic> comment,
      {required bool hasReplies}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete comment?'),
        content: Text(hasReplies
            ? 'This also deletes the replies to this comment.'
            : 'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Database().deleteComment(widget.id, comment['id'] as String);
      if (_replyParentId == comment['id']) _cancelReply();
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not delete the comment. Please try again.'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Widget _buildComment(Map<String, dynamic> c,
      {String? threadRootId, bool hasReplies = false}) {
    final me = Auth().user?.uid;
    final mine = c['uid'] == me;
    final isReply = threadRootId != null;
    return Comment(
      key: ValueKey('comment_${c['id']}'),
      username: _nameFor(c),
      profilePic: _photoFor(c),
      date: _formatDate(c['date']),
      description: c['description']?.toString() ?? '',
      likes: (c['likes'] as List?) ?? const [],
      postId: widget.id,
      commentId: c['id'] as String,
      authorId: c['uid']?.toString() ?? '',
      isReply: isReply,
      replyToName: isReply ? c['reply_to_name']?.toString() : null,
      onReply: () => _startReply(c, threadRootId: threadRootId),
      onReport: mine ? null : () => _reportComment(c),
      onDelete: mine
          ? () => _deleteComment(c, hasReplies: hasReplies)
          : null,
    );
  }

  List<Widget> _buildCommentSlivers(List<CommentThread> threads) {
    if (_isLoading) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }
    if (_loadError != null && comments.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Text(_loadError!, style: GoogleFonts.poppins()),
                TextButton(onPressed: _subscribe, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ];
    }
    if (threads.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Icon(Icons.comment_outlined, size: 60, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No comments yet',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to comment!',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      SliverList.separated(
        itemCount: threads.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final thread = threads[index];
          final rootId = thread.comment['id'] as String;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildComment(thread.comment,
                  hasReplies: thread.replies.isNotEmpty),
              for (final reply in thread.replies)
                _buildComment(reply, threadRootId: rootId),
            ],
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final threads = buildCommentThreads(
      comments,
      hiddenCommentIds: _hiddenComments,
      blockedUserIds: _blockedUsers,
    );
    final visibleCount =
        threads.fold<int>(0, (n, t) => n + 1 + t.replies.length);
    final caption = _caption;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      // The body shrinks above the keyboard; the composer (and the reply
      // preview inside it) is pinned to the bottom of that space.
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        title: Text(
          'Comments',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            // Photo, caption and comments scroll together, so opening the
            // keyboard never squeezes a fixed-height photo over the list.
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildMedia(context)),
                if (caption != null && caption.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      // The full caption, never clipped (the feed shows a
                      // short preview).
                      child: MarkdownBody(
                        data: caption,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        Icon(Icons.comment_outlined,
                            color: AppColors.muted(context, Colors.grey[700]!),
                            size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '$visibleCount ${visibleCount == 1 ? 'Comment' : 'Comments'}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted(context, Colors.grey[800]!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: Divider(height: 1)),
                ..._buildCommentSlivers(threads),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ],
            ),
          ),
          CommentInputBar(
            controller: _commentController,
            focusNode: _inputFocus,
            submitting: _submitting,
            onSubmit: _postComment,
            replyingToName: _replyParentId == null ? null : _replyToName,
            replyingToText: _replyParentId == null ? null : _replyToText,
            onCancelReply: _cancelReply,
          ),
        ],
      ),
    );
  }

  Widget _buildMedia(BuildContext context) {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.width * 0.9,
      margin: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppColors.subtle(context),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: widget.mediaType == "image"
                  ? PostImage(url: widget.mediaURL, fit: BoxFit.contain)
                  : FutureBuilder(
                      future: _videoInit,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done &&
                            _controller != null) {
                          return VideoPlayer(_controller!);
                        }
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
            ),
          ),
          // Report button
          if (widget.creator != Auth().user?.uid)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: IconButton(
                  icon: const Icon(Icons.report, color: Colors.white, size: 20),
                  tooltip: 'Report post',
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
    );
  }
}
