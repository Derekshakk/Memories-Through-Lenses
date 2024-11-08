import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;

class Database {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Auth _auth = Auth();

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
      String displayName, String username, String? profileImage) async {
    if (profileImage != null) {
      _firestore.collection('users').doc(_auth.user!.uid).update({
        'name': username,
        'profile_image': profileImage,
      });
    } else {
      _firestore.collection('users').doc(_auth.user!.uid).update({
        'name': username,
      });
    }

    _auth.user!.updateDisplayName(displayName);
  }

  Future<void> createPost(String groupId, String caption, File image) async {
    var currentTime = DateTime.now();
    var ref = FirebaseStorage.instance
        .ref()
        .child('posts/${_auth.user!.uid}/$currentTime');
    await ref.putFile(image);
    var imageUrl = await ref.getDownloadURL();

    Map<String, String> validationData = {
      'url': imageUrl,
      'user_uid': _auth.user!.uid,
      'image_name': '$currentTime',
    };

    // get the server url from RTDB at node moderation_server_url
    var url = await FirebaseDatabase.instance
        .ref('moderation_server_url')
        .once()
        .then((value) => value.snapshot.value.toString());

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(validationData),
    );

    if (response.statusCode == 200) {
      print('Image processed successfully');
      print(response.body);
    } else {
      print('Failed to process image: ${response.body}');
    }

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

    var posts_list = posts.docs.map((e) => e.data()).toList();

    // for each post, add the id
    for (var i = 0; i < posts_list.length; i++) {
      // print("Attempting to add id to post");
      posts_list[i]['id'] = posts.docs[i].id;
      // print("Added id to post: {${posts_list[i]['id']}");
    }

    if (mode == 'newest') {
      print("Sorting by newest");
      posts_list.sort((a, b) => a['created_at'].compareTo(b['created_at']));
    } else if (mode == 'popular') {
      print("Sorting by popular");
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
