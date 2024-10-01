import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:memories_through_lenses/services/auth.dart';

enum GroupCardType {
  request, // request to join group (red only)
  invite, // invite to join group (green only)
  notification // show both accept and reject buttons
}

class GroupCard extends StatelessWidget {
  const GroupCard(
      {super.key,
      required this.name,
      required this.groupID,
      required this.type});
  final String name;
  final String groupID;
  final GroupCardType type;

  @override
  Widget build(BuildContext context) {
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(child: Text(name)),
          // ternary expression
          // (type == GroupCardType.invite) ? (if true) : (if false)
          (type != GroupCardType.invite)
              ? SizedBox(
                  width: SizeConfig.blockSizeHorizontal! * 10,
                  height: SizeConfig.blockSizeHorizontal! * 10,
                  child: ElevatedButton(
                      onPressed: () {
                        // respond to the invite by writing the group id into the user's groups list and removing the group id from the user's group_invites list
                        final userRef = FirebaseFirestore.instance
                            .collection('users')
                            .doc(Auth().user!.uid);

                        // Add groupID to user's groups list
                        userRef.update({
                          'groups': FieldValue.arrayUnion([groupID]),
                        });

                        // Get the current 'group_invites' map and remove the groupID from it
                        userRef.get().then((doc) {
                          if (doc.exists) {
                            Map<String, dynamic> groupInvites =
                                doc['group_invites'] ?? {};
                            groupInvites.remove(groupID);

                            // Update the user's document with the modified map
                            userRef.update({
                              'group_invites': groupInvites,
                            });
                          }
                        });

                        // Add user to group's members list
                        final groupRef = FirebaseFirestore.instance
                            .collection('groups')
                            .doc(groupID);
                        groupRef.update({
                          'members': FieldValue.arrayUnion([Auth().user!.uid])
                        });

                        Navigator.pushNamedAndRemoveUntil(
                            context, '/', (route) => false);
                      },
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(EdgeInsets.zero),
                        backgroundColor: WidgetStateProperty.all(Colors.green),
                        shape: WidgetStateProperty.all(const CircleBorder()),
                      ),
                      child: const Icon(Icons.add_circle_outline,
                          color: Colors.white)),
                )
              : Container(),
          (type != GroupCardType.request)
              ? SizedBox(
                  width: SizeConfig.blockSizeHorizontal! * 2,
                )
              : Container(),
          (type != GroupCardType.request)
              ? SizedBox(
                  width: SizeConfig.blockSizeHorizontal! * 10,
                  height: SizeConfig.blockSizeHorizontal! * 10,
                  child: ElevatedButton(
                      onPressed: () {
                        // remove user from group's join_requests list

                        // get firestore ref of the group
                        final groupRef = FirebaseFirestore.instance
                            .collection('groups')
                            .doc(groupID);
                        // remove user from the join_requests list
                        groupRef.update({
                          'join_requests':
                              FieldValue.arrayRemove([Auth().user!.uid])
                        });

                        // show snackbar
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invite rejected!'),
                          ),
                        );

                        // remove group id from user's group_invites map
                        final userRef = FirebaseFirestore.instance
                            .collection('users')
                            .doc(Auth().user!.uid);

                        // Get the current 'group_invites' map and remove the key manually
                        userRef.get().then((doc) {
                          if (doc.exists) {
                            Map<String, dynamic> groupInvites =
                                doc['group_invites'] ?? {};
                            groupInvites.remove(groupID);

                            // Update the user's document with the modified map
                            userRef.update({
                              'group_invites': groupInvites,
                            });
                          }
                        });
                      },
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(EdgeInsets.zero),
                        backgroundColor: WidgetStateProperty.all(Colors.red),
                        shape: WidgetStateProperty.all(const CircleBorder()),
                      ),
                      child: const Icon(Icons.cancel_outlined,
                          color: Colors.white)),
                )
              : Container()
        ],
      ),
    ));
  }
}

class GroupFriendCard extends StatefulWidget {
  const GroupFriendCard(
      {super.key,
      required this.name,
      required this.uid,
      this.groupID = '',
      this.groupName = '',
      this.mode = 'create'});
  final String name;
  final String uid;
  final String groupID;
  final String groupName;
  final String mode;

  @override
  State<GroupFriendCard> createState() => _GroupFriendCardState();
}

class _GroupFriendCardState extends State<GroupFriendCard> {
  bool _selected = false;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _selected = !_selected;
              // print(_selected);
            });
          },
          child: Card(
              child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                SizedBox(
                  width: SizeConfig.blockSizeHorizontal! * 10,
                  height: SizeConfig.blockSizeHorizontal! * 10,
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
                Expanded(child: Text(widget.name)),

                // ternary expression
                // (expression) ? (if true) : (if false)
                (_selected)
                    ? SizedBox(
                        width: SizeConfig.blockSizeHorizontal! * 10,
                        height: SizeConfig.blockSizeHorizontal! * 10,
                        child: (widget.mode == 'create')
                            ? ElevatedButton(
                                onPressed: () {},
                                style: ButtonStyle(
                                  padding:
                                      WidgetStateProperty.all(EdgeInsets.zero),
                                  backgroundColor:
                                      WidgetStateProperty.all(Colors.grey),
                                  shape: WidgetStateProperty.all(
                                      const CircleBorder()),
                                ),
                                child: const Icon(Icons.check_circle,
                                    color: Colors.white))
                            : Container(),
                      )
                    : (widget.mode == 'create')
                        ? SizedBox(
                            width: SizeConfig.blockSizeHorizontal! * 10,
                            height: SizeConfig.blockSizeHorizontal! * 10,
                            child: ElevatedButton(
                                onPressed: () {},
                                style: ButtonStyle(
                                  padding:
                                      WidgetStateProperty.all(EdgeInsets.zero),
                                  backgroundColor: WidgetStateProperty.all(
                                      const Color.fromARGB(132, 158, 158, 158)),
                                  shape: WidgetStateProperty.all(
                                      const CircleBorder()),
                                ),
                                child: Container()),
                          )
                        : Container()
              ],
            ),
          )),
        ),
        (widget.mode == 'edit')
            ? AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                color: Colors.yellow,
                height: _selected ? SizeConfig.blockSizeVertical! * 20 : 0,
                width: SizeConfig.blockSizeHorizontal! * 90,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: SizeConfig.blockSizeHorizontal! * 90,
                        child: ElevatedButton(
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.all(Colors.yellow),
                            shape: WidgetStateProperty.all(
                                RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(0))),
                          ),
                          onPressed: () {
                            // transfer ownership of group to user with uid
                            final groupRef = FirebaseFirestore.instance
                                .collection('groups')
                                .doc(widget.groupID);
                            groupRef.update({'owner': widget.uid});
                            Navigator.pushNamedAndRemoveUntil(
                                context, '/', (route) => false);
                          },
                          child: const Text('Transfer Ownership'),
                        ),
                      ),
                      SizedBox(
                        width: SizeConfig.blockSizeHorizontal! * 90,
                        child: ElevatedButton(
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.all(Colors.yellow),
                            shape: WidgetStateProperty.all(
                                RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(0))),
                          ),
                          onPressed: () {
                            // remove user from group's members list
                            final groupRef = FirebaseFirestore.instance
                                .collection('groups')
                                .doc(widget.groupID);
                            groupRef.update({
                              'members': FieldValue.arrayRemove([widget.uid])
                            });
                          },
                          child: const Text('Kick'),
                        ),
                      ),
                      SizedBox(
                        width: SizeConfig.blockSizeHorizontal! * 90,
                        child: ElevatedButton(
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.all(Colors.yellow),
                            shape: WidgetStateProperty.all(
                                RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(0))),
                          ),
                          onPressed: () {
                            // add user to group's join_requests list

                            // get firestore ref of the group
                            final groupRef = FirebaseFirestore.instance
                                .collection('groups')
                                .doc(widget.groupID);
                            // add user to the join_requests list
                            groupRef.update({
                              'join_requests':
                                  FieldValue.arrayUnion([widget.uid])
                            });

                            // show snackbar
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Request sent!'),
                              ),
                            );

                            // write group id and name into user's group_invites list
                            final userRef = FirebaseFirestore.instance
                                .collection('users')
                                .doc(widget.uid);
                            userRef.update({
                              'group_invites': {
                                widget.groupID: widget.groupName
                              }
                            });
                          },
                          child: const Text('Add Friend'),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Container()
      ],
    );
  }
}
// const Icon(Icons.cancel, color: Colors.white)
