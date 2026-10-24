import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:memories_through_lenses/providers/user_provider.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'firebase_post_backend.dart';
import 'post_creation.dart';

class Database {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Auth _auth = Auth();
  final UserProvider? _userProvider;

  Database([this._userProvider]);

  Future<List<Map<String, dynamic>>> getSchools() async {
    var schools = await _firestore.collection('schools').get();
    List<Map<String, dynamic>> result =
        schools.docs.map((e) => e.data()).toList();

    // add the id to each school
    for (var i = 0; i < result.length; i++) {
      result[i]['id'] = schools.docs[i].id;
    }

    return result;
  }

  Future<String> createGroup(
      String name, String description, bool private) async {
    var ref = _firestore.collection('groups').doc();
    await ref.set({
      'name': name,
      'description': description,
      'private': private,
      'members': [_auth.user!.uid],
      'member_count': 1,
      'owner': _auth.user!.uid,
      'join_requests': [],
      'school': 'bkuv1JQ2R3HSkfs2Aotg',
    });

    await _firestore.collection('users').doc(_auth.user!.uid).update({
      'groups': FieldValue.arrayUnion([ref.id])
    });

    return ref.id;
  }

  Future<void> updateGroup(
      String id, String name, String description, bool isPrivate) async {
    _firestore.collection('groups').doc(id).update(
        {'name': name, 'description': description, 'private': isPrivate});
  }

  Future<void> deleteGroup(String groupId) async {
    try {
      // Get the group data first to find all members and invites
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();

      if (!groupDoc.exists) {
        print('Group does not exist');
        return;
      }

      final groupData = groupDoc.data();
      final List<dynamic> members = groupData?['members'] ?? [];
      final List<dynamic> joinRequests = groupData?['join_requests'] ?? [];

      // Remove group from all members' groups array
      for (String memberId in members) {
        await _firestore.collection('users').doc(memberId).update({
          'groups': FieldValue.arrayRemove([groupId])
        });
      }

      // Remove group invites from users who were invited
      final usersSnapshot = await _firestore
          .collection('users')
          .where('group_invites.$groupId', isNull: false)
          .get();

      for (var userDoc in usersSnapshot.docs) {
        await _firestore
            .collection('users')
            .doc(userDoc.id)
            .update({'group_invites.$groupId': FieldValue.delete()});
      }

      // Remove group from users who sent join requests
      for (String userId in joinRequests) {
        await _firestore.collection('users').doc(userId).update({
          'group_requests': FieldValue.arrayRemove([groupId])
        });
      }

      // Delete all posts in this group
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('group_id', isEqualTo: groupId)
          .get();

      for (var postDoc in postsSnapshot.docs) {
        // Delete all comments in each post
        final commentsSnapshot = await _firestore
            .collection('posts')
            .doc(postDoc.id)
            .collection('comments')
            .get();

        for (var commentDoc in commentsSnapshot.docs) {
          await commentDoc.reference.delete();
        }

        // Delete the post
        await postDoc.reference.delete();
      }

      // Finally, delete the group document
      await _firestore.collection('groups').doc(groupId).delete();

      print('Group deleted successfully');
    } catch (e) {
      print('Error deleting group: $e');
      rethrow;
    }
  }

  Future<void> leaveGroup() async {}

  Future<String> uploadProfileImage(File image) async {
    var ref = FirebaseStorage.instance
        .ref()
        .child('profile_images/${_auth.user!.uid}');
    final task = ref.putFile(image);
    try {
      // Same bounded completion logic as post uploads: the native task Future
      // can fail to resolve, which previously left "Save Changes" spinning.
      await waitForStorageUpload(task,
          PostTrace('profile-image-${DateTime.now().microsecondsSinceEpoch}'),
          timeout: const Duration(minutes: 2));
    } catch (e) {
      try {
        await task.cancel();
      } catch (_) {}
      rethrow;
    }
    return await ref.getDownloadURL().timeout(const Duration(seconds: 30));
  }

  /// Updates the signed-in user's name (and photo when given).
  ///
  /// Firestore applies the change locally at once and syncs it when online,
  /// so a slow/missing server acknowledgment is not treated as a failure.
  /// Rule denials and other errors that arrive within the window still throw.
  Future<void> updateProfile(String username, String? profileImage,
      {Duration ackTimeout = const Duration(seconds: 15)}) async {
    final user = _auth.user!;
    final write = _firestore.collection('users').doc(user.uid).update({
      'name': username,
      if (profileImage != null) 'profile_image': profileImage,
    });
    if (profileImage != null) {
      unawaited(user.updatePhotoURL(profileImage).catchError((Object e) {
        print('Error updating auth photo URL: $e');
      }));
    }
    try {
      await write.timeout(ackTimeout);
    } on TimeoutException {
      print('Profile update queued; server acknowledgment pending');
    }
  }

  /// Retain this operation when Firestore acknowledgment is pending.
  PostCreation createPost(String groupId, String caption, Uint8List image) =>
      PostCreation(FirebasePostBackend(groupId, caption), image);

  Future<void> likePost(String postId) async {
    var post = await _firestore.collection('posts').doc(postId).get();
    var likes = post.data()!['likes'];
    var dislikes = post.data()!['dislikes'];

    // If user already liked, remove the like (toggle off)
    if (likes.contains(_auth.user!.uid)) {
      await removeLikePost(postId);
      return;
    }

    // If user previously disliked, remove the dislike
    if (dislikes.contains(_auth.user!.uid)) {
      await removeDislikePost(postId);
    }

    // Add the like
    await _firestore.collection('posts').doc(postId).update({
      'likes': FieldValue.arrayUnion([_auth.user!.uid])
    });
  }

  Future<void> removeLikePost(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'likes': FieldValue.arrayRemove([_auth.user!.uid])
    });
  }

  Future<void> dislikePost(String postId) async {
    var post = await _firestore.collection('posts').doc(postId).get();
    var likes = post.data()!['likes'];
    var dislikes = post.data()!['dislikes'];

    // If user already disliked, remove the dislike (toggle off)
    if (dislikes.contains(_auth.user!.uid)) {
      await removeDislikePost(postId);
      return;
    }

    // If user previously liked, remove the like
    if (likes.contains(_auth.user!.uid)) {
      await removeLikePost(postId);
    }

    // Add the dislike
    await _firestore.collection('posts').doc(postId).update({
      'dislikes': FieldValue.arrayUnion([_auth.user!.uid])
    });
  }

  Future<void> removeDislikePost(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'dislikes': FieldValue.arrayRemove([_auth.user!.uid])
    });
  }

  Future<List<Map<String, dynamic>>> getPosts(
      String groupId, String mode) async {
    var posts = await _firestore
        .collection('posts')
        .where('group_id', isEqualTo: groupId)
        .get();

    var posts_list = posts.docs.map((e) => e.data()).toList();

    // for each post, add the id
    for (var i = 0; i < posts_list.length; i++) {
      // print("Attempting to add id to post");
      posts_list[i]['id'] = posts.docs[i].id;
      // print("Added id to post: {${posts_list[i]['id']}");
    }

    if (mode == 'newest') {
      //print("Sorting by newest");
      posts_list.sort((a, b) => a['created_at'].compareTo(b['created_at']));
    } else if (mode == 'popular') {
      //print("Sorting by popular");
      posts_list.sort((a, b) => b['likes'].length.compareTo(a['likes'].length));

      // reverse the list to get the most popular first
      posts_list = posts_list.reversed.toList();
    }

    // for debug, print the post id, created_at, and likes
    for (var post in posts_list) {
      print(
          "Post ID: ${post['id']} Created At: ${post['created_at']} Likes: ${post['likes'].length}");
    }

    return posts_list;
  }

  Future<Map<String, dynamic>?> getPost(String postId) async {
    // check if the user previously liked the post
    var post = await _firestore.collection('posts').doc(postId).get();
    if (!post.exists) {
      return null;
    }
    var post_data = post.data();
    post_data!['id'] = postId;
    return post_data;
  }

  Future<List<Map<String, dynamic>>> getYearBook() {
    // get every post in the posts collection whose id is in the yearbook array of the user's data from provider
    return _firestore
        .collection('posts')
        .where(FieldPath.documentId,
            whereIn: _userProvider?.userData?['yearbook'] ?? [])
        .get()
        .then((value) {
      var posts_list = value.docs.map((e) => e.data()).toList();

      // for each post, add the id
      for (var i = 0; i < posts_list.length; i++) {
        posts_list[i]['id'] = value.docs[i].id;
      }

      return posts_list;
    });
  }

  Future<void> reportPost(String postId, String postCreator,
      {String? reason, String? details}) async {
    try {
      // Get the post to find the group_id
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      final groupId = postDoc.data()?['group_id'] ?? '';

      await _firestore.collection('reports').add({
        // Reports without a `type` (created before comment reports existed)
        // are post reports; readers must keep treating them that way.
        'type': 'post',
        'post_id': postId,
        'post_creator': postCreator,
        'group_id': groupId,
        'reporter_id': _auth.user!.uid,
        if (reason != null) 'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
        'created_at': Timestamp.now(),
        'status': 'pending', // pending, approved, rejected
      });

      // record the post in the user's reported posts
      await _firestore.collection('users').doc(_auth.user!.uid).update({
        'reported_posts': FieldValue.arrayUnion([postId])
      });
    } catch (e) {
      print('Error reporting post: $e');
      rethrow;
    }
  }

  // Get reports for groups owned by the current user
  Future<List<Map<String, dynamic>>> getReportsForMyGroups() async {
    try {
      print('Getting reports for my groups...');

      // Get all groups owned by current user
      final groupsSnapshot = await _firestore
          .collection('groups')
          .where('owner', isEqualTo: _auth.user!.uid)
          .get();

      List<String> myGroupIds =
          groupsSnapshot.docs.map((doc) => doc.id).toList();
      print('Found ${myGroupIds.length} groups owned by user');

      if (myGroupIds.isEmpty) {
        return [];
      }

      // Get all pending reports for these groups (without orderBy to avoid index requirement)
      final reportsSnapshot = await _firestore
          .collection('reports')
          .where('group_id', whereIn: myGroupIds)
          .where('status', isEqualTo: 'pending')
          .get();

      print('Found ${reportsSnapshot.docs.length} pending reports');

      List<Map<String, dynamic>> reports = [];
      for (var doc in reportsSnapshot.docs) {
        Map<String, dynamic> report = doc.data();
        report['id'] = doc.id;

        // Get post details
        final postDoc =
            await _firestore.collection('posts').doc(report['post_id']).get();
        if (postDoc.exists) {
          report['post_data'] = postDoc.data();
        } else {
          print('Post not found for report: ${doc.id}');
        }

        // Comment reports also carry the comment itself (if still present).
        if (report['type'] == 'comment' && report['comment_id'] is String) {
          final commentDoc = await _firestore
              .collection('posts')
              .doc(report['post_id'])
              .collection('comments')
              .doc(report['comment_id'])
              .get();
          if (commentDoc.exists) report['comment_data'] = commentDoc.data();
        }

        // Get reporter details
        final reporterDoc = await _firestore
            .collection('users')
            .doc(report['reporter_id'])
            .get();
        if (reporterDoc.exists) {
          report['reporter_name'] = reporterDoc.data()?['name'] ?? 'Unknown';
        } else {
          report['reporter_name'] = 'Unknown';
        }

        reports.add(report);
      }

      // Sort by created_at descending (client-side)
      reports.sort((a, b) {
        final aTime = a['created_at'] as Timestamp?;
        final bTime = b['created_at'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      print('Returning ${reports.length} reports');
      return reports;
    } catch (e) {
      print('Error getting reports: $e');
      return [];
    }
  }

  // Approve report and delete the post
  Future<void> approveReport(String reportId, String postId) async {
    try {
      // Update report status
      await _firestore.collection('reports').doc(reportId).update({
        'status': 'approved',
        'reviewed_at': DateTime.now(),
        'reviewed_by': _auth.user!.uid,
      });

      // Delete the post and its comments
      final commentsSnapshot = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .get();

      for (var commentDoc in commentsSnapshot.docs) {
        await commentDoc.reference.delete();
      }

      await _firestore.collection('posts').doc(postId).delete();
    } catch (e) {
      print('Error approving report: $e');
      rethrow;
    }
  }

  // Approve a comment report: delete only that comment (and its replies),
  // never the post.
  Future<void> approveCommentReport(
      String reportId, String postId, String commentId) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': 'approved',
        'reviewed_at': Timestamp.now(),
        'reviewed_by': _auth.user!.uid,
      });
      await deleteComment(postId, commentId);
    } catch (e) {
      print('Error approving comment report: $e');
      rethrow;
    }
  }

  // Reject report and keep the post
  Future<void> rejectReport(String reportId) async {
    try {
      print('Rejecting report: $reportId');

      // Get the report to find the reporter and post
      final reportDoc =
          await _firestore.collection('reports').doc(reportId).get();
      final reportData = reportDoc.data();

      if (reportData != null && reportData['type'] == 'comment') {
        final commentId = reportData['comment_id'];
        final usersSnapshot = await _firestore
            .collection('users')
            .where('reported_comments', arrayContains: commentId)
            .get();
        for (var userDoc in usersSnapshot.docs) {
          await _firestore.collection('users').doc(userDoc.id).update({
            'reported_comments': FieldValue.arrayRemove([commentId])
          });
        }
      } else if (reportData != null) {
        final postId = reportData['post_id'];
        print('Post ID: $postId');

        // Get all users who have this post in their reported_posts list
        final usersSnapshot = await _firestore
            .collection('users')
            .where('reported_posts', arrayContains: postId)
            .get();

        print(
            'Found ${usersSnapshot.docs.length} users with this post in reported_posts');

        // Remove post from all these users' reported_posts lists
        for (var userDoc in usersSnapshot.docs) {
          print('Removing post from user: ${userDoc.id}');
          await _firestore.collection('users').doc(userDoc.id).update({
            'reported_posts': FieldValue.arrayRemove([postId])
          });
        }
      }

      // Update report status
      await _firestore.collection('reports').doc(reportId).update({
        'status': 'rejected',
        'reviewed_at': Timestamp.now(),
        'reviewed_by': _auth.user!.uid,
      });

      print('Report rejected successfully');
    } catch (e) {
      print('Error rejecting report: $e');
      rethrow;
    }
  }

  // Get join requests for groups owned by current user
  Future<List<Map<String, dynamic>>> getJoinRequestsForMyGroups() async {
    try {
      final currentUserId = _auth.user?.uid;
      if (currentUserId == null) {
        print('getJoinRequestsForMyGroups: No current user');
        return [];
      }

      print('========== JOIN REQUESTS DEBUG ==========');
      print('Current User ID: $currentUserId');

      // Get all groups owned by current user
      final groupsSnapshot = await _firestore
          .collection('groups')
          .where('owner', isEqualTo: currentUserId)
          .get();

      print('Found ${groupsSnapshot.docs.length} groups owned by current user');

      List<Map<String, dynamic>> allRequests = [];

      // For each group, get the join requests
      for (var groupDoc in groupsSnapshot.docs) {
        final groupData = groupDoc.data();
        final joinRequests = groupData['join_requests'] as List<dynamic>? ?? [];

        print('Group: ${groupData['name']} (${groupDoc.id})');
        print('  Join requests: $joinRequests');

        // For each user in join_requests, get their info
        for (var userId in joinRequests) {
          print('  Fetching user data for: $userId');
          final userDoc =
              await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data();
            allRequests.add({
              'user_id': userId,
              'user_name': userData?['name'] ?? 'Unknown User',
              'user_email': userData?['email'] ?? '',
              'profile_image': userData?['profile_image'],
              'group_id': groupDoc.id,
              'group_name': groupData['name'] ?? 'Unknown Group',
            });
            print('  Added request from: ${userData?['name']}');
          }
        }
      }

      print('Total join requests found: ${allRequests.length}');
      return allRequests;
    } catch (e) {
      print('Error getting join requests: $e');
      return [];
    }
  }

  // Approve a join request
  Future<void> approveJoinRequest(String userId, String groupId) async {
    try {
      // Add user to group members
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([userId]),
        'join_requests': FieldValue.arrayRemove([userId]),
      });

      // Add group to user's groups
      await _firestore.collection('users').doc(userId).update({
        'groups': FieldValue.arrayUnion([groupId]),
        'group_requests': FieldValue.arrayRemove([groupId]),
      });
    } catch (e) {
      print('Error approving join request: $e');
      rethrow;
    }
  }

  // Reject a join request
  Future<void> rejectJoinRequest(String userId, String groupId) async {
    try {
      // Remove user from group's join_requests
      await _firestore.collection('groups').doc(groupId).update({
        'join_requests': FieldValue.arrayRemove([userId]),
      });

      // Remove group from user's group_requests
      await _firestore.collection('users').doc(userId).update({
        'group_requests': FieldValue.arrayRemove([groupId]),
      });
    } catch (e) {
      print('Error rejecting join request: $e');
      rethrow;
    }
  }

  /// Firestore applies writes locally at once (the comment stream shows them
  /// immediately) and syncs later, so a missing server ack within [_ackTimeout]
  /// is treated as queued, not failed. Errors that arrive in time still throw.
  static const Duration _ackTimeout = Duration(seconds: 15);

  Future<void> _awaitWrite(Future<void> write) async {
    try {
      await write.timeout(_ackTimeout);
    } on TimeoutException {
      print('Write queued; server acknowledgment pending');
    }
  }

  /// Create a comment on a post. [parentId] makes it a reply to that
  /// top-level comment. Returns the new comment id.
  Future<String> createComment(String postId, String comment,
      {String? username,
      String? parentId,
      String? replyToUid,
      String? replyToName}) async {
    final user = _auth.user!;
    // Comments used to store `_userProvider?.userData?['name'] ?? ''`, but
    // callers never passed a provider, so most comments saved an empty name.
    var name = username ?? _userProvider?.userData?['name'];
    if (name is! String || name.trim().isEmpty) {
      try {
        final doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 10));
        name = doc.data()?['name'];
      } catch (e) {
        print('Could not load commenter name: $e');
      }
    }
    final ref =
        _firestore.collection('posts').doc(postId).collection('comments').doc();
    await _awaitWrite(ref.set({
      'uid': user.uid,
      'description': comment,
      'date': DateTime.now(),
      'likes': [],
      'username': name is String ? name : '',
      'profilePic': user.photoURL,
      if (parentId != null) 'parent_id': parentId,
      if (replyToUid != null) 'reply_to_uid': replyToUid,
      if (replyToName != null) 'reply_to_name': replyToName,
    }));
    return ref.id;
  }

  // like a comment by adding the user's uid to the likes array
  Future<void> likeComment(String postId, String commentId) async {
    await _awaitWrite(_firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .update({
      'likes': FieldValue.arrayUnion([_auth.user!.uid])
    }));
  }

  // unlike a comment
  Future<void> removeLikeComment(String postId, String commentId) async {
    await _awaitWrite(_firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .update({
      'likes': FieldValue.arrayRemove([_auth.user!.uid])
    }));
  }

  /// Report a comment for review by the group's owner.
  ///
  /// This used to write an incomplete report (no group_id/status) that the
  /// review screen could never find, and the dialog never called it at all.
  Future<void> reportComment(String postId, String commentId,
      {required String reason,
      String? details,
      String? commentText,
      String? commentAuthor}) async {
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      final groupId = postDoc.data()?['group_id'] ?? '';

      await _firestore.collection('reports').add({
        'type': 'comment',
        'post_id': postId,
        'post_creator': postDoc.data()?['user_id'] ?? '',
        'comment_id': commentId,
        if (commentText != null) 'comment_text': commentText,
        if (commentAuthor != null) 'comment_author': commentAuthor,
        'group_id': groupId,
        'reporter_id': _auth.user!.uid,
        'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
        'created_at': Timestamp.now(),
        'status': 'pending', // pending, approved, rejected
      });

      // Hide the comment from the reporter, mirroring reported_posts.
      await _firestore.collection('users').doc(_auth.user!.uid).update({
        'reported_comments': FieldValue.arrayUnion([commentId])
      });
    } catch (e) {
      print('Error reporting comment: $e');
      rethrow;
    }
  }

  /// Delete a comment. Deleting a top-level comment also deletes its replies
  /// so they aren't left orphaned.
  Future<void> deleteComment(String postId, String commentId) async {
    final comments =
        _firestore.collection('posts').doc(postId).collection('comments');
    final replies =
        await comments.where('parent_id', isEqualTo: commentId).get();
    final batch = _firestore.batch();
    for (final reply in replies.docs) {
      batch.delete(reply.reference);
    }
    batch.delete(comments.doc(commentId));
    await _awaitWrite(batch.commit());
  }

  // edit a comment
  Future<void> editComment(
      String postId, String commentId, String newComment) async {
    await _awaitWrite(_firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .update({'description': newComment}));
  }

  // get all comments for a post
  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    var comments = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .get();

    var comments_list = comments.docs.map((e) => e.data()).toList();

    // for each comment, add the id
    for (var i = 0; i < comments_list.length; i++) {
      comments_list[i]['id'] = comments.docs[i].id;
      // Missing photo → '' so the UI shows the bundled generic avatar
      // (this previously substituted an unrelated stock photo URL).
      if (comments_list[i]['profilePic'] is! String) {
        comments_list[i]['profilePic'] = '';
      }
    }

    return comments_list;
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    var users = await _firestore.collection('users').get();
    List<Map<String, dynamic>> result =
        users.docs.map((e) => e.data()).toList();
    // add the uid to each user
    for (var i = 0; i < result.length; i++) {
      result[i]['uid'] = users.docs[i].id;
    }
    return result;
  }

  // block user function that adds the given uid to the current user's blocked list
  // Only blocks. It never reports anything (see ReportDialog).
  Future<void> blockUser(String uid) async {
    await _awaitWrite(
        _firestore.collection('users').doc(_auth.user!.uid).update({
      'blocked': FieldValue.arrayUnion([uid])
    }));
  }

  // Remove a post from the user's yearbook
  Future<void> removeFromYearbook(String postId) async {
    await _firestore.collection('users').doc(_auth.user!.uid).update({
      'yearbook': FieldValue.arrayRemove([postId])
    });
  }
}
