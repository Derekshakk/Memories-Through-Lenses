import 'package:flutter/material.dart';

class GroupScreen extends StatelessWidget {
  const GroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
            child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/join_group');
            },
            child: Text('Join Group')),
        ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/create_group');
            },
            child: Text('Create Group')),
      ],
    )));
  }
}
