import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/toggle_row.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
      child: Center(
          child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Group Name',
              ),
            ),
            Container(
              color: Colors.grey,
              height: SizeConfig.blockSizeVertical! * 60,
              width: SizeConfig.blockSizeHorizontal! * 90,
              child: ListView.builder(
                itemCount: 5,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text('User $index'),
                  );
                },
              ),
            ),
            ToggleRow(
              title: 'Private',
            ),
            ElevatedButton(
              onPressed: () {},
              child: Text('Create Group'),
            ),
          ],
        ),
      )),
    ));
  }
}
