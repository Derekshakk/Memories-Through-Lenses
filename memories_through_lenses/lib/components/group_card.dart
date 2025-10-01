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
                      onPressed: () async {
                        if (type == GroupCardType.request) {
                          // Send join request for public groups
                          final userRef = FirebaseFirestore.instance
                              .collection('users')
                              .doc(Auth().user!.uid);

                          // Add groupID to user's group_requests list
                          await userRef.update({
                            'group_requests': FieldValue.arrayUnion([groupID]),
                          });

                          // Add user to group's join_requests list
                          final groupRef = FirebaseFirestore.instance
                              .collection('groups')
                              .doc(groupID);
                          await groupRef.update({
                            'join_requests':
                                FieldValue.arrayUnion([Auth().user!.uid])
                          });

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Join request sent!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            Navigator.pop(context);
                          }
                        } else {
                          // Accept invite (GroupCardType.notification)
                          final userRef = FirebaseFirestore.instance
                              .collection('users')
                              .doc(Auth().user!.uid);

                          // Add groupID to user's groups list
                          await userRef.update({
                            'groups': FieldValue.arrayUnion([groupID]),
                          });

                          // Get the current 'group_invites' map and remove the groupID from it
                          final doc = await userRef.get();
                          if (doc.exists) {
                            Map<String, dynamic> groupInvites =
                                doc['group_invites'] ?? {};
                            groupInvites.remove(groupID);

                            // Update the user's document with the modified map
                            await userRef.update({
                              'group_invites': groupInvites,
                            });
                          }

                          // Add user to group's members list
                          final groupRef = FirebaseFirestore.instance
                              .collection('groups')
                              .doc(groupID);
                          await groupRef.update({
                            'members': FieldValue.arrayUnion([Auth().user!.uid])
                          });

                          if (context.mounted) {
                            Navigator.pushNamedAndRemoveUntil(
                                context, '/home', (route) => false);
                          }
                        }
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
      this.mode = 'create',
      this.profileImage});
  final String name;
  final String uid;
  final String groupID;
  final String groupName;
  final String mode;
  final String? profileImage;

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
                  child: CircleAvatar(
                    radius: SizeConfig.blockSizeHorizontal! * 5,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: widget.profileImage != null
                        ? NetworkImage(widget.profileImage!)
                        : null,
                    child: widget.profileImage == null
                        ? Icon(Icons.person, color: Colors.grey[600])
                        : null,
                  ),
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
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                height: _selected ? SizeConfig.blockSizeVertical! * 20 : 0,
                width: SizeConfig.blockSizeHorizontal! * 90,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: SizeConfig.blockSizeHorizontal! * 90,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.swap_horiz, size: 20),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          onPressed: () async {
                            // Show confirmation dialog
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Transfer Ownership'),
                                content: Text(
                                  'Are you sure you want to transfer ownership of this group? You will no longer be the owner and cannot undo this action.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text(
                                      'Transfer',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true) {
                              // transfer ownership of group to user with uid
                              final groupRef = FirebaseFirestore.instance
                                  .collection('groups')
                                  .doc(widget.groupID);
                              await groupRef.update({'owner': widget.uid});

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Ownership transferred successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.pushNamedAndRemoveUntil(
                                    context, '/group', (route) => false);
                              }
                            }
                          },
                            label: const Text('Transfer Ownership'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: SizeConfig.blockSizeHorizontal! * 90,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.person_remove, size: 20),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          onPressed: () async {
                            // Show confirmation dialog
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Kick Member'),
                                content: Text('Are you sure you want to remove this member from the group?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Kick', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true) {
                              // remove user from group's members list
                              final groupRef = FirebaseFirestore.instance
                                  .collection('groups')
                                  .doc(widget.groupID);
                              await groupRef.update({
                                'members': FieldValue.arrayRemove([widget.uid])
                              });

                              // remove group from user's groups list
                              final userRef = FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(widget.uid);
                              await userRef.update({
                                'groups': FieldValue.arrayRemove([widget.groupID])
                              });

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Member kicked from group'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                // Navigate back to refresh the list
                                Navigator.pushNamedAndRemoveUntil(
                                    context, '/group', (route) => false);
                              }
                            }
                          },
                            label: const Text('Kick'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: SizeConfig.blockSizeHorizontal! * 90,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.person_add, size: 20),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          onPressed: () async {
                            final currentUserId = Auth().user!.uid;

                            // Check if trying to send to yourself
                            if (widget.uid == currentUserId) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('You cannot send a friend request to yourself'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            // Check if already friends
                            final currentUserDoc = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUserId)
                                .get();

                            final currentUserData = currentUserDoc.data();
                            final friends = currentUserData?['friends'] ?? {};
                            final outgoingRequests = currentUserData?['outgoing_requests'] ?? {};

                            if (friends.containsKey(widget.uid)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('This user is already your friend'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            if (outgoingRequests.containsKey(widget.uid)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Friend request already sent to this user'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            // Show confirmation dialog
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Send Friend Request'),
                                content: Text('Send a friend request to this user?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Send Request'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true) {
                              // Send friend request
                              final currentUserName = currentUserData?['name'] ?? 'Unknown';

                              // Add to target user's friend_requests
                              final targetUserRef = FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(widget.uid);

                              await targetUserRef.update({
                                'friend_requests.$currentUserId': {
                                  'name': currentUserName,
                                }
                              });

                              // Add to current user's outgoing_requests
                              final currentUserRef = FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(currentUserId);

                              await currentUserRef.update({
                                'outgoing_requests.${widget.uid}': {
                                  'name': widget.name,
                                }
                              });

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Friend request sent!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          },
                            label: const Text('Send Friend Request'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : Container()
      ],
    );
  }
}
// const Icon(Icons.cancel, color: Colors.white)
