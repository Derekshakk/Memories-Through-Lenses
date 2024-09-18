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
                        // add user to group's join_requests list

                        // get firestore ref of the group
                        final groupRef = FirebaseFirestore.instance
                            .collection('groups')
                            .doc(groupID);
                        // add user to the join_requests list
                        groupRef.update({
                          'join_requests':
                              FieldValue.arrayUnion([Auth().user!.uid])
                        });

                        // show snackbar
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Request sent!'),
                          ),
                        );

                        // write group id into user's group_requests list
                        final userRef = FirebaseFirestore.instance
                            .collection('users')
                            .doc(Auth().user!.uid);
                        userRef.update({
                          'group_requests': FieldValue.arrayUnion([groupID])
                        });
                      },
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(EdgeInsets.zero),
                        backgroundColor: WidgetStateProperty.all(Colors.green),
                        shape: WidgetStateProperty.all(const CircleBorder()),
                      ),
                      child: const Icon(Icons.add, color: Colors.white)),
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
                      onPressed: () {},
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(EdgeInsets.zero),
                        backgroundColor: WidgetStateProperty.all(Colors.red),
                        shape: WidgetStateProperty.all(const CircleBorder()),
                      ),
                      child:
                          const Icon(Icons.check_circle, color: Colors.white)),
                )
              : Container()
        ],
      ),
    ));
  }
}

class GroupFriendCard extends StatefulWidget {
  const GroupFriendCard(
      {super.key, required this.name, required this.uid, this.mode = 'create'});
  final String name;
  final String uid;
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: SizeConfig.blockSizeHorizontal! * 90,
                      child: ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.all(Colors.yellow),
                          shape: WidgetStateProperty.all(RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0))),
                        ),
                        onPressed: () {},
                        child: const Text('Transfer Ownership'),
                      ),
                    ),
                    SizedBox(
                      width: SizeConfig.blockSizeHorizontal! * 90,
                      child: ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.all(Colors.yellow),
                          shape: WidgetStateProperty.all(RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0))),
                        ),
                        onPressed: () {},
                        child: const Text('Kick'),
                      ),
                    ),
                    SizedBox(
                      width: SizeConfig.blockSizeHorizontal! * 90,
                      child: ElevatedButton(
                        style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.all(Colors.yellow),
                          shape: WidgetStateProperty.all(RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0))),
                        ),
                        onPressed: () {},
                        child: const Text('Add Friend'),
                      ),
                    ),
                  ],
                ),
              )
            : Container()
      ],
    );
  }
}
// const Icon(Icons.cancel, color: Colors.white)
