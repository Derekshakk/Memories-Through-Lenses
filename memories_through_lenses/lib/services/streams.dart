import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:memories_through_lenses/services/auth.dart';

/// Centralized streams provider for Firebase data
class AppStreams {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream of current user's data
  static Stream<DocumentSnapshot<Map<String, dynamic>>> get userDataStream {
    final uid = Auth().user?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }
    return _firestore.collection('users').doc(uid).snapshots();
  }

  /// Stream of groups where current user is a member
  static Stream<QuerySnapshot<Map<String, dynamic>>> get userGroupsStream {
    final uid = Auth().user?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }
    return _firestore
        .collection('groups')
        .where('members', arrayContains: uid)
        .snapshots();
  }

  /// Stream of posts for a specific group
  static Stream<QuerySnapshot<Map<String, dynamic>>> getGroupPostsStream(
    String groupId,
    String sortBy,
  ) {
    // Fetch all posts for the group without server-side sorting
    // Sorting will be done client-side to avoid index requirements
    return _firestore
        .collection('posts')
        .where('group_id', isEqualTo: groupId)
        .snapshots();
  }

  /// Stream of schools (for signup)
  static Stream<QuerySnapshot<Map<String, dynamic>>> get schoolsStream {
    return _firestore.collection('schools').snapshots();
  }

  /// Stream of groups for a specific school (for joining groups)
  static Stream<QuerySnapshot<Map<String, dynamic>>> getSchoolGroupsStream(
      String schoolId) {
    return _firestore
        .collection('groups')
        .where('school', isEqualTo: schoolId)
        .snapshots();
  }

  /// Stream of comments for a specific post
  static Stream<QuerySnapshot<Map<String, dynamic>>> getPostCommentsStream(
      String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('date', descending: true)
        .snapshots();
  }

  /// Stream of friend requests for current user
  static Stream<DocumentSnapshot<Map<String, dynamic>>> get friendRequestsStream {
    final uid = Auth().user?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }
    return _firestore.collection('users').doc(uid).snapshots();
  }

  /// Stream of specific user's data
  static Stream<DocumentSnapshot<Map<String, dynamic>>> getUserStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  /// Stream of specific group's data
  static Stream<DocumentSnapshot<Map<String, dynamic>>> getGroupStream(String groupId) {
    return _firestore.collection('groups').doc(groupId).snapshots();
  }

  /// Stream of groups owned by current user (for editing)
  static Stream<QuerySnapshot<Map<String, dynamic>>> get ownedGroupsStream {
    final uid = Auth().user?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }
    return _firestore
        .collection('groups')
        .where('owner', isEqualTo: uid)
        .snapshots();
  }
}