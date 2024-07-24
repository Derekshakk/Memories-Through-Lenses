import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: Center(
                child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          color: Colors.grey,
          height: SizeConfig.blockSizeVertical! * 40,
          width: SizeConfig.blockSizeHorizontal! * 90,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {},
                  child: Text('Upload Image or Video'),
                ),
                SizedBox(
                  height: SizeConfig.blockSizeVertical! * 2,
                ),
                ElevatedButton(
                  onPressed: () {},
                  child: Text('Take Image or Video'),
                ),
              ],
            ),
          ),
        ),
        Column(
          children: [
            Text('Select Group', style: TextStyle(fontSize: 25)),
            SizedBox(
              width: SizeConfig.blockSizeHorizontal! * 90,
              height: SizeConfig.blockSizeVertical! * 20,
              child: Card(
                color: Colors.grey,
                child: ListWheelScrollView(
                  itemExtent: 50,
                  children: [
                    ListTile(
                      tileColor: Colors.white,
                      title: Text("Group 1"),
                      onTap: () {},
                    ),
                    ListTile(
                      tileColor: Colors.white,
                      title: Text("Group 2"),
                      onTap: () {},
                    ),
                    ListTile(
                      tileColor: Colors.white,
                      title: Text("Group 3"),
                      onTap: () {},
                    ),
                    ListTile(
                      tileColor: Colors.white,
                      title: Text("Group 4"),
                      onTap: () {},
                    ),
                    ListTile(
                      tileColor: Colors.white,
                      title: Text("Group 5"),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(
          width: SizeConfig.blockSizeHorizontal! * 90,
          child: ElevatedButton(
            onPressed: () {},
            child: Text('Snap and Share', style: TextStyle(fontSize: 20)),
          ),
        )
      ],
    ))));
  }
}
