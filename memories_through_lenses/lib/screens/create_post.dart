import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:memories_through_lenses/providers/user_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

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
  final TextEditingController _captionController = TextEditingController();
  File? _postMedia;
  String mediaType = '';
  String _selectedGroup = '';
  List<Pair> groups = [];
  bool uploading = false;
  String _message = '';

  late VideoPlayerController _controller;

  void initVideoPlayer() {
    if (_postMedia != null) {
      _controller = VideoPlayerController.file(_postMedia!)
        ..initialize().then((_) {
          setState(() {});
        });
    }
  }

  void setGroups(List<Map<String, dynamic>> groupData) {
    groups.clear();
    for (var group in groupData) {
      groups.add(Pair(key: group['groupID'], value: group['name']));
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    if (mediaType == 'video') _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<UserProvider>(context);

    // Get media from provider on first build
    if (_postMedia == null) {
      if (provider.imageFile != null) {
        _postMedia = provider.imageFile;
        mediaType = 'image';
        provider.imageFile = null;
      } else if (provider.videoFile != null) {
        _postMedia = provider.videoFile;
        mediaType = 'video';
        initVideoPlayer();
        provider.videoFile = null;
      }
    }

    setGroups(provider.groups);
    return Scaffold(
        appBar: AppBar(
          title: Text(
            'Create Post',
            style: GoogleFonts.merriweather(fontSize: 30, color: Colors.black),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
            },
          ),
        ),
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
                    child: (_postMedia != null && mediaType == 'image')
                        ? SizedBox(
                            height: SizeConfig.blockSizeVertical! * 40,
                            width: SizeConfig.blockSizeHorizontal! * 90,
                            child: Image.file(
                              _postMedia!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : (_postMedia != null && mediaType == 'video')
                            ? SizedBox(
                                height: SizeConfig.blockSizeVertical! * 40,
                                width: SizeConfig.blockSizeHorizontal! * 90,
                                child: VideoPlayer(_controller),
                              )
                            : const Center(
                                child: Text('No Image Selected',
                                    style: TextStyle(fontSize: 20))),
                  )),
              ElevatedButton(
                onPressed: () async {
                  await ImagePicker()
                      .pickImage(source: ImageSource.gallery)
                      .then(
                    (value) {
                      if (value != null) {
                        setState(() {
                          _postMedia = File(value.path);
                          mediaType = 'image';
                        });
                      }
                    },
                  );
                },
                child: Text('Upload Image'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/camera');
                },
                child: Text('Take Image'),
              ),
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
                            _message = '';
                          });
                          Database()
                              .createPost(_selectedGroup,
                                  _captionController.text, _postMedia!)
                              .then((value) {
                            if (!value)
                              setState(() {
                                uploading = false;
                                _message =
                                    'Error uploading post. Image is classified as inappropriate';
                              });
                            else
                              Navigator.pushNamedAndRemoveUntil(
                                  context, '/', (route) => false);
                          });
                        }
                      : null,
                  child: Text((!uploading) ? 'Snap and Share' : 'Uploading...',
                      style: TextStyle(fontSize: 20)),
                ),
              ),
              Text(
                  textAlign: TextAlign.center,
                  _message,
                  style: TextStyle(fontSize: 20, color: Colors.red)),
            ],
          )),
        )));
  }
}
