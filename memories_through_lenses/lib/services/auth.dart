import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Auth {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final user = FirebaseAuth.instance.currentUser;

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

  Future<void> forgotPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
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
