import 'dart:io';

import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:memories_through_lenses/shared/singleton.dart';
import 'package:image_picker/image_picker.dart';

class Pair {
  final String key;
  final String value;

  Pair({required this.key, required this.value});
}

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  Singleton singleton = Singleton();
  final TextEditingController _captionController = TextEditingController();
  File? _postMedia;
  String _selectedGroup = '';
  List<Pair> groups = [];
  bool uploading = false;

  void setGroups() {
    groups.clear();
    List<Map<String, dynamic>> groupData = singleton.groupData;
    for (var group in groupData) {
      groups.add(Pair(key: group['groupID'], value: group['name']));
    }
  }

  @override
  Widget build(BuildContext context) {
    setGroups();
    print("CREATING POST: ${singleton.groupData}");
    return Scaffold(
        body: SafeArea(
            child: SingleChildScrollView(
      child: Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            color: Colors.grey,
            height: SizeConfig.blockSizeVertical! * 40,
            width: SizeConfig.blockSizeHorizontal! * 90,
            child: Center(
                child: (_postMedia != null)
                    ? SizedBox(
                        height: SizeConfig.blockSizeVertical! * 40,
                        width: SizeConfig.blockSizeHorizontal! * 90,
                        child: Image.file(
                          _postMedia!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Text('No Image or Video Selected',
                        style: TextStyle(fontSize: 20))),
          ),
          ElevatedButton(
            onPressed: () async {
              await ImagePicker().pickImage(source: ImageSource.gallery).then(
                (value) {
                  if (value != null) {
                    setState(() {
                      _postMedia = File(value.path);
                    });
                  }
                },
              );
            },
            child: Text('Upload Image or Video'),
          ),
          // ElevatedButton(
          //   onPressed: () {},
          //   child: Text('Take Image or Video'),
          // ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                hintText: 'Caption',
              ),
            ),
          ),
          Column(
            children: [
              const Text('Select Group', style: TextStyle(fontSize: 25)),
              SizedBox(
                width: SizeConfig.blockSizeHorizontal! * 90,
                height: SizeConfig.blockSizeVertical! * 20,
                child: Card(
                  color: Colors.grey,
                  child: ListWheelScrollView(
                    itemExtent: 50,
                    diameterRatio: 1.5,
                    children: groups
                        .map((e) => Center(
                              child: ListTile(
                                tileColor: (_selectedGroup == e.key)
                                    ? Colors.yellow
                                    : Colors.white,
                                title: Text(e.value),
                                onTap: () {
                                  setState(() {
                                    _selectedGroup = e.key;
                                  });
                                },
                              ),
                            ))
                        .toList(),
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedGroup = groups[index].key;
                      });
                    },
                  ),
                ),
              )
            ],
          ),
          SizedBox(
            width: SizeConfig.blockSizeHorizontal! * 90,
            child: ElevatedButton(
              onPressed: (_postMedia != null && _selectedGroup != '')
                  ? () {
                      setState(() {
                        uploading = true;
                      });
                      Database()
                          .createPost(_selectedGroup, _captionController.text,
                              _postMedia!)
                          .then((value) {
                        Navigator.pushNamedAndRemoveUntil(
                            context, '/', (route) => false);
                      });
                    }
                  : null,
              child: Text((!uploading) ? 'Snap and Share' : 'Uploading...',
                  style: TextStyle(fontSize: 20)),
            ),
          )
        ],
      )),
    )));
  }
}
