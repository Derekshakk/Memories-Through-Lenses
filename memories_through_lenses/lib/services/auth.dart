import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class Auth {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final user = FirebaseAuth.instance.currentUser;

  // Stream to listen to authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<String?> signUp(
      String email, String password, String name, String school) async {
    try {
      // Check if email already exists
      String? duplicateCheck = await _checkEmailExists(email);
      if (duplicateCheck != null) {
        return duplicateCheck; // Return error message
      }

      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Send email verification
      await userCredential.user!.sendEmailVerification();

      // Add user to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'name': name,
        'email': email,
        'friends': {},
        'friend_requests': {},
        'outgoing_requests': {},
        'groups': [],
        'group_requests': [],
        'group_invites': {},
        'school': school,
        'yearbook': [],
      });

      return null; // Success
    } catch (e) {
      print(e);
      if (e.toString().contains('email-already-in-use')) {
        return 'An account with this email already exists. Please use a different email or try logging in.';
      } else if (e.toString().contains('weak-password')) {
        return 'Password is too weak. Please choose a stronger password.';
      } else if (e.toString().contains('invalid-email')) {
        return 'Please enter a valid email address.';
      } else {
        return 'An error occurred during signup. Please try again.';
      }
    }
  }

  Future<String?> _checkEmailExists(String email) async {
    try {
      // Check if email exists in Firestore
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return 'An account with this email already exists. Please use a different email or try logging in.';
      }
      return null; // Email doesn't exist
    } catch (e) {
      print('Error checking email: $e');
      return null; // Allow signup to proceed if check fails
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      var result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return result.user != null;
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> updateUsername(String displayName) async {
    await user!.updateDisplayName(displayName);
  }

  /// Sends a Firebase password-reset email.
  ///
  /// Returns `null` if Firebase accepted the request, otherwise a
  /// user-friendly error message. The exact Firebase error code and message
  /// are logged to aid diagnosis. No passwords or credentials are logged.
  Future<String?> forgotPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null; // Firebase accepted the request.
    } on FirebaseAuthException catch (e) {
      // Surface the exact code/message for debugging. The password-reset
      // flow involves no passwords, so nothing sensitive is logged here.
      debugPrint('Password reset failed [code=${e.code}]: ${e.message}');
      switch (e.code) {
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'user-not-found':
          return 'No account was found with that email address.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a moment and try again.';
        case 'operation-not-allowed':
          return 'Password reset via email is not enabled for this app. '
              'Please contact support.';
        case 'network-request-failed':
          return 'Network error. Please check your connection and try again.';
        default:
          return 'Could not send the reset email (${e.code}). '
              'Please try again.';
      }
    } catch (e) {
      debugPrint('Unexpected password reset error: $e');
      return 'An unexpected error occurred. Please try again.';
    }
  }

  Future<void> deleteUser() async {
    // delete user from Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .delete();
    // delete user from Firebase Auth
    await user!.delete().then(
      (value) {
        // log out after deleting the user
        logout();
      },
    );
  }
}
