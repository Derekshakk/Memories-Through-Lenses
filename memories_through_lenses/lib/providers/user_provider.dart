import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:memories_through_lenses/services/streams.dart';

/// Modern replacement for Singleton using Provider pattern
/// Manages user state without causing excessive rebuilds
class UserProvider extends ChangeNotifier {
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _groups = [];

  // For camera/create post flow
  File? imageFile;
  File? videoFile;

  Map<String, dynamic>? get userData => _userData;
  List<Map<String, dynamic>> get groups => _groups;

  /// Initialize user data from Firestore (one-time load)
  Future<void> loadUserData() async {
    try {
      final uid = Auth().user?.uid;
      if (uid == null) return;

      print('========== USERPROVIDER DEBUG ==========');
      print('Loading user data for UID: $uid');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        _userData = userDoc.data();
        print('User data loaded successfully');
        print('Reported posts: ${_userData?['reported_posts']}');
        notifyListeners();
        print('notifyListeners() called');
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  /// Load user's groups (one-time load)
  Future<void> loadGroups() async {
    try {
      final uid = Auth().user?.uid;
      if (uid == null) return;

      final groupsSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .where('members', arrayContains: uid)
          .get();

      _groups = groupsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['groupID'] = doc.id;
        return data;
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading groups: $e');
    }
  }

  /// Refresh both user data and groups
  Future<void> refreshAll() async {
    await Future.wait([
      loadUserData(),
      loadGroups(),
    ]);
  }

  /// Set image file for post creation
  void setImageFile(File? file) {
    imageFile = file;
    notifyListeners();
  }

  /// Set video file for post creation
  void setVideoFile(File? file) {
    videoFile = file;
    notifyListeners();
  }

  /// Clear media files after use
  void clearMediaFiles() {
    imageFile = null;
    videoFile = null;
    notifyListeners();
  }

  /// Clear all data (for logout)
  void clear() {
    _userData = null;
    _groups = [];
    imageFile = null;
    videoFile = null;
    notifyListeners();
  }
}
