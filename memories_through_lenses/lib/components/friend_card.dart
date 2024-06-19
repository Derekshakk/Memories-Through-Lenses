import 'package:flutter/material.dart';

class FriendCard extends StatelessWidget {
  const FriendCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
        child: Row(
      children: [
        IconButton(onPressed: () {}, icon: Icon(Icons.person)),
        Text("Friend Name"),
        IconButton(onPressed: () {}, icon: Icon(Icons.person)),
        IconButton(onPressed: () {}, icon: Icon(Icons.person)),
      ],
    ));
  }
}
