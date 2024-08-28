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
      'owner': _auth.user!.uid
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
}
