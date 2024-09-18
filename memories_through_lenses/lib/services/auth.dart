import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Auth {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final user = FirebaseAuth.instance.currentUser;

  Future<void> signUp(String email, String password, String name) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

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
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      print(e);
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
