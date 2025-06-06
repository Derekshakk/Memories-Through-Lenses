import 'dart:math';

import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:memories_through_lenses/services/database.dart';

import '../shared/singleton.dart';

enum FriendCardType {
  request,
  sentRequest,
  currentFriend,
  addFriend,
}

class FriendCard extends StatelessWidget {
  FriendCard(
      {super.key,
      required this.type,
      required this.name,
      required this.uid,
      required this.onPressed});

  final FriendCardType type;
  final String name;
  final String uid;
  final Function onPressed;
  Singleton singleton = Singleton();

  @override
  Widget build(BuildContext context) {
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          SizedBox(
            width: min(SizeConfig.blockSizeHorizontal! * 10, 75),
            height: min(SizeConfig.blockSizeHorizontal! * 10, 75),
            child: ElevatedButton(
                onPressed: () {},
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                  backgroundColor: WidgetStateProperty.all(Colors.grey),
                  shape: WidgetStateProperty.all(const CircleBorder()),
                ),
                child: const Icon(Icons.person, color: Colors.white)),
          ),
          SizedBox(width: SizeConfig.blockSizeHorizontal! * 2),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 20))),

          if (type == FriendCardType.request)
            SizedBox(
              width: min(SizeConfig.blockSizeHorizontal! * 10, 75),
              height: min(SizeConfig.blockSizeHorizontal! * 10, 75),
              child: ElevatedButton(
                  onPressed: () {
                    // determine database path depending on type
                    String path = (type == FriendCardType.request)
                        ? 'friend_requests'
                        : 'friends';

                    // remove friend request or friend at users/{uid}/friend_requests/uid or users/{uid}/friends/uid
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(Auth().user!.uid)
                        .update({
                      '$path.$uid': FieldValue.delete(),
                    }).catchError((error) {
                      print('Failed to delete friend request: $error');
                    }).then((value) {
                      Database().blockUser(uid).then((value) {
                        onPressed();
                      });
                    });
                  },
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                    backgroundColor: WidgetStateProperty.all(Colors.orange),
                    shape: WidgetStateProperty.all(const CircleBorder()),
                  ),
                  child: const Icon(Icons.block, color: Colors.white)),
            ),

          SizedBox(width: SizeConfig.blockSizeHorizontal! * 2),

          // ternary expression
          // (expression) ? (if true) : (if false)
          (type != FriendCardType.sentRequest &&
                  type != FriendCardType.addFriend)
              ? SizedBox(
                  width: min(SizeConfig.blockSizeHorizontal! * 10, 75),
                  height: min(SizeConfig.blockSizeHorizontal! * 10, 75),
                  child: ElevatedButton(
                      onPressed: () {
                        // determine database path depending on type
                        String path = (type == FriendCardType.request)
                            ? 'friend_requests'
                            : 'friends';

                        // remove friend request or friend at users/{uid}/friend_requests/uid or users/{uid}/friends/uid
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(Auth().user!.uid)
                            .update({
                          '$path.$uid': FieldValue.delete(),
                        }).catchError((error) {
                          print('Failed to delete friend request: $error');
                        }).then((value) {
                          onPressed();
                        });
                      },
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(EdgeInsets.zero),
                        backgroundColor: WidgetStateProperty.all(Colors.red),
                        shape: WidgetStateProperty.all(const CircleBorder()),
                      ),
                      child: const Icon(Icons.cancel, color: Colors.white)),
                )
              : Container(),
          (type == FriendCardType.addFriend)
              ? SizedBox(
                  width: min(SizeConfig.blockSizeHorizontal! * 10, 75),
                  height: min(SizeConfig.blockSizeHorizontal! * 10, 75),
                  child: ElevatedButton(
                      onPressed: () {
                        // add friend request at users/{uid}/friend_requests/$uid
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(Auth().user!.uid)
                            .update({
                          'outgoing_requests.$uid': {'name': name},
                        }).catchError((error) {
                          print('Failed to add friend request: $error');
                        }).then((value) {
                          // write request on receiver's side
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .update({
                            'friend_requests.${Auth().user!.uid}': {
                              'name': singleton.userData['name']
                            },
                          }).catchError((error) {
                            print('Failed to add outgoing request: $error');
                          }).then((value) {
                            onPressed();
                          });
                        });
                      },
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(EdgeInsets.zero),
                        backgroundColor: WidgetStateProperty.all(Colors.blue),
                        shape: WidgetStateProperty.all(const CircleBorder()),
                      ),
                      child: const Icon(Icons.person_add, color: Colors.white)),
                )
              : Container(),
          (type != FriendCardType.currentFriend &&
                  type != FriendCardType.addFriend)
              ? SizedBox(width: SizeConfig.blockSizeHorizontal! * 2)
              : Container(),
          (type != FriendCardType.currentFriend &&
                  type != FriendCardType.addFriend)
              ? SizedBox(
                  width: min(SizeConfig.blockSizeHorizontal! * 10, 75),
                  height: min(SizeConfig.blockSizeHorizontal! * 10, 75),
                  child: ElevatedButton(
                      onPressed: () {
                        // add friend of value uid at users/{uid}/friends/$uid and delete request at users/{uid}/friend_requests/$uid
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(Auth().user!.uid)
                            .update({
                          'friends.$uid': {'name': name},
                          'friend_requests.$uid': FieldValue.delete(),
                        }).catchError((error) {
                          print('Failed to add friend: $error');
                        }).then((value) {
                          // add user as friend of value Auth().user!.uid at users/$uid/friends/Auth().user!.uid
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .update({
                            'friends.${Auth().user!.uid}': {
                              'name': singleton.userData['name']
                            },
                            'outgoing_requests.${Auth().user!.uid}':
                                FieldValue.delete(),
                          }).catchError((error) {
                            print('Failed to add friend: $error');
                          }).then((value) {
                            onPressed();
                          });
                        });
                      },
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(EdgeInsets.zero),
                        backgroundColor: WidgetStateProperty.all(Colors.green),
                        shape: WidgetStateProperty.all(const CircleBorder()),
                      ),
                      child:
                          const Icon(Icons.check_circle, color: Colors.white)),
                )
              : Container(),
        ],
      ),
    ));
  }
}
