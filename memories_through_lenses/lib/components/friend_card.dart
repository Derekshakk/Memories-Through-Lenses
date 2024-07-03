import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';

enum FriendCardType {
  request,
  currentFriend,
  addFriend,
}

class FriendCard extends StatelessWidget {
  const FriendCard({super.key, required this.type, required this.name});
  final FriendCardType type;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Card(
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
          Expanded(child: Text(name)),

          // ternary expression
          // (expression) ? (if true) : (if false)
          (type != FriendCardType.addFriend)
              ? SizedBox(
                  width: SizeConfig.blockSizeHorizontal! * 10,
                  height: SizeConfig.blockSizeHorizontal! * 10,
                  child: ElevatedButton(
                      onPressed: () {},
                      style: ButtonStyle(
                        padding: MaterialStateProperty.all(EdgeInsets.zero),
                        backgroundColor: MaterialStateProperty.all(Colors.red),
                        shape: MaterialStateProperty.all(const CircleBorder()),
                      ),
                      child: const Icon(Icons.cancel, color: Colors.white)),
                )
              : Container(),
          (type != FriendCardType.currentFriend)
              ? SizedBox(width: SizeConfig.blockSizeHorizontal! * 2)
              : Container(),
          (type != FriendCardType.currentFriend)
              ? SizedBox(
                  width: SizeConfig.blockSizeHorizontal! * 10,
                  height: SizeConfig.blockSizeHorizontal! * 10,
                  child: ElevatedButton(
                      onPressed: () {},
                      style: ButtonStyle(
                        padding: MaterialStateProperty.all(EdgeInsets.zero),
                        backgroundColor:
                            MaterialStateProperty.all(Colors.green),
                        shape: MaterialStateProperty.all(const CircleBorder()),
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
