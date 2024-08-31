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

            List<dynamic> groups = singleton.userData["groups"];

            for (int i = 0; i < groups.length; i++) {
              String groupID = groups[i].toString();
              print(groupID);
            }

            // get the groups collection
            var groupsCollection =
                FirebaseFirestore.instance.collection('groups');
            // get the groups that the user is a part of in the members list
            var userGroups = groupsCollection
                .where('members', arrayContains: user.uid)
                .snapshots();

            // convert the userGroups to a list
            // print("User groups: ");

            singleton.groupData = [];

            userGroups.forEach((element) {
              // convert json query snapshot to list
              List<DocumentSnapshot> userGroupsList = element.docs;
              for (var element in userGroupsList) {
                // print(element.data());
                Map<String, dynamic> groupData =
                    element.data() as Map<String, dynamic>;

                // add groupID to groupData, it's the key of the document
                groupData["groupID"] = element.id;

                singleton.groupData.add(groupData);
              }
              singleton.notifyListenersSafe();
            });

            return HomePage();
          });
    }
    return LoginPage();
  }
}
