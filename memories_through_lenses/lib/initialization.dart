import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:memories_through_lenses/screens/login.dart';
import 'package:memories_through_lenses/screens/home.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:memories_through_lenses/shared/singleton.dart';

class Initializer extends StatelessWidget {
  const Initializer({super.key});

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    Singleton singleton = Singleton();
    User? user = Auth().user;

    if (user != null) {
      return StreamBuilder<Object>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            print("Snapshot: $snapshot");
            if (snapshot.connectionState == ConnectionState.waiting ||
                !snapshot.hasData) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            // print("User data: ${snapshot.data}");
            singleton.setUserData((snapshot.data as DocumentSnapshot).data()
                as Map<String, dynamic>);

            print(singleton.userData);

            return HomePage();
          });
    }
    return LoginPage();
  }
}
