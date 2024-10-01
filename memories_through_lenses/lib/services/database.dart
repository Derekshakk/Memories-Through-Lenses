import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class Database {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Auth _auth = Auth();

  Future<void> createGroup(
      String name, String description, bool private) async {
    var ref = _firestore.collection('groups').doc();
    ref.set({
      'name': name,
      'description': description,
      'private': private,
      'members': [_auth.user!.uid],
      'member_count': 1,
      'owner': _auth.user!.uid,
      'join_requests': []
    });

    _firestore.collection('users').doc(_auth.user!.uid).update({
      'groups': FieldValue.arrayUnion([ref.id])
    });
  }

  Future<void> updateGroup(
      String id, String name, String description, bool isPrivate) async {
    _firestore.collection('groups').doc(id).update(
        {'name': name, 'description': description, 'private': isPrivate});
  }

  Future<void> deleteGroup() async {}

  Future<void> leaveGroup() async {}

  Future<String> uploadProfileImage(File image) async {
    var ref = FirebaseStorage.instance
        .ref()
        .child('profile_images/${_auth.user!.uid}');
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  Future<void> updateProfile(
      String displayName, String username, String profileImage) async {
    _firestore.collection('users').doc(_auth.user!.uid).update({
      'name': username,
      'profile_image': profileImage,
    });

    _auth.user!.updateDisplayName(displayName);
  }

  Future<void> createPost(String groupId, String caption, File image) async {
    var ref = FirebaseStorage.instance
        .ref()
        .child('posts/${_auth.user!.uid}/${DateTime.now()}');
    await ref.putFile(image);
    var imageUrl = await ref.getDownloadURL();

    _firestore.collection('posts').add({
      'group_id': groupId,
      'user_id': _auth.user!.uid,
      'caption': caption,
      'image_url': imageUrl,
      'likes': [],
      'dislikes': [],
      'comments': [],
      'created_at': DateTime.now()
    });
  }

  Future<void> likePost(String postId) async {
    // check if the user previously disliked the post
    var post = await _firestore.collection('posts').doc(postId).get();
    var dislikes = post.data()!['dislikes'];
    if (dislikes.contains(_auth.user!.uid)) {
      removeDislikePost(postId);
    }

    _firestore.collection('posts').doc(postId).update({
      'likes': FieldValue.arrayUnion([_auth.user!.uid])
    });
  }

  Future<void> removeLikePost(String postId) async {
    _firestore.collection('posts').doc(postId).update({
      'likes': FieldValue.arrayRemove([_auth.user!.uid])
    });
  }

  Future<void> dislikePost(String postId) async {
    // check if the user previously liked the post
    var post = await _firestore.collection('posts').doc(postId).get();
    var likes = post.data()!['likes'];
    if (likes.contains(_auth.user!.uid)) {
      removeLikePost(postId);
    }

    _firestore.collection('posts').doc(postId).update({
      'dislikes': FieldValue.arrayUnion([_auth.user!.uid])
    });
  }

  Future<void> removeDislikePost(String postId) async {
    _firestore.collection('posts').doc(postId).update({
      'dislikes': FieldValue.arrayRemove([_auth.user!.uid])
    });
  }

  Future<List<Map<String, dynamic>>> getPosts(
      String groupId, String mode) async {
    var posts = await _firestore
        .collection('posts')
        .where('group_id', isEqualTo: groupId)
        .get();

    if (mode == 'newest') {
      posts.docs.sort(
          (a, b) => b.data()['created_at'].compareTo(a.data()['created_at']));
    } else if (mode == 'popular') {
      posts.docs.sort((a, b) =>
          b.data()['likes'].length.compareTo(a.data()['likes'].length));
    }

    var posts_list = posts.docs.map((e) => e.data()).toList();

    // for each post, add the id
    for (var i = 0; i < posts_list.length; i++) {
      // print("Attempting to add id to post");
      posts_list[i]['id'] = posts.docs[i].id;
      // print("Added id to post: {${posts_list[i]['id']}");
    }

    return posts_list;
  }

  Future<void> reportPost(String postId, String postCreator) async {
    _firestore.collection('reports').add({
      'post_id': postId,
      'post_creator': postCreator,
      'user_id': _auth.user!.uid,
      'created_at': DateTime.now()
    });

    // record the post in the user's reported posts
    _firestore.collection('users').doc(_auth.user!.uid).update({
      'reported_posts': FieldValue.arrayUnion([postId])
    });
  }

  Future<void> reportAndBlockUser(String postId, String postCreator) async {
    reportPost(postId, postCreator);
    blockUser(postCreator);
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
  Future<void> blockUser(String uid) async {
    _firestore.collection('users').doc(_auth.user!.uid).update({
      'blocked': FieldValue.arrayUnion([uid])
    });
  }
}
