import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:memories_through_lenses/services/auth.dart';

class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.name, required this.groupID});
  final String name;
  final String groupID;

  @override
  Widget build(BuildContext context) {
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(child: Text(name)),
          SizedBox(
            width: SizeConfig.blockSizeHorizontal! * 10,
            height: SizeConfig.blockSizeHorizontal! * 10,
            child: ElevatedButton(
                onPressed: () {
                  // determine database path depending on type
                  // String path = (type == FriendCardType.request)
                  //     ? 'friend_requests'
                  //     : 'friends';

                  // // remove friend request or friend at users/{uid}/friend_requests/uid or users/{uid}/friends/uid
                  // FirebaseFirestore.instance
                  //     .collection('users')
                  //     .doc(Auth().user!.uid)
                  //     .update({
                  //   '$path.$uid': FieldValue.delete(),
                  // }).catchError((error) {
                  //   print('Failed to delete friend request: $error');
                  // });
                },
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                  backgroundColor: WidgetStateProperty.all(Colors.red),
                  shape: WidgetStateProperty.all(const CircleBorder()),
                ),
                child: const Icon(Icons.cancel, color: Colors.white)),
          )
        ],
      ),
    ));
  }
}

class GroupFriendCard extends StatefulWidget {
  const GroupFriendCard({super.key, required this.name, required this.uid});
  final String name;
  final String uid;

  @override
  State<GroupFriendCard> createState() => _GroupFriendCardState();
}

class _GroupFriendCardState extends State<GroupFriendCard> {
  bool _selected = false;
  @override
  Widget build(BuildContext context) {
    return InkWell(
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
                    child: ElevatedButton(
                        onPressed: () {},
                        style: ButtonStyle(
                          padding: WidgetStateProperty.all(EdgeInsets.zero),
                          backgroundColor: WidgetStateProperty.all(Colors.grey),
                          shape: WidgetStateProperty.all(const CircleBorder()),
                        ),
                        child: const Icon(Icons.check_circle,
                            color: Colors.white)),
                  )
                : SizedBox(
                    width: SizeConfig.blockSizeHorizontal! * 10,
                    height: SizeConfig.blockSizeHorizontal! * 10,
                    child: ElevatedButton(
                        onPressed: () {},
                        style: ButtonStyle(
                          padding: WidgetStateProperty.all(EdgeInsets.zero),
                          backgroundColor: WidgetStateProperty.all(
                              const Color.fromARGB(132, 158, 158, 158)),
                          shape: WidgetStateProperty.all(const CircleBorder()),
                        ),
                        child: Container()),
                  )
          ],
        ),
      )),
    );
  }
}
// const Icon(Icons.cancel, color: Colors.white)