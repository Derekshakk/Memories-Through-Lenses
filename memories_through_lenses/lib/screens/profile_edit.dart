import 'dart:io';

import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:image_picker/image_picker.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:memories_through_lenses/shared/singleton.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  File? _profileImage;

  // TextEditingController nameController = TextEditingController();
  TextEditingController usernameController = TextEditingController();
  final Singleton _singleton = Singleton();
  int _usernameLength = 0;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    usernameController.text = _singleton.userData['name'];
    _usernameLength = usernameController.text.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            InkWell(
              onTap: () {
                showModalBottomSheet(
                    context: context,
                    builder: (context) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            title: const Text('Camera'),
                            onTap: () async {
                              try {
                                final image = await ImagePicker().pickImage(
                                     source: ImageSource.camera,
                                     imageQuality: 50,
                                     maxWidth: 150);
                                 if (image != null) {
                                   setState(() {
                                     _profileImage = File(image.path);
                                   });
                                 }
                                 Navigator.pop(context);
                              } catch (e) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Camera error: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                          ),
                          ListTile(
                            title: const Text('Gallery'),
                            onTap: () async {
                              try {
                                final image = await ImagePicker()
                                    .pickImage(source: ImageSource.gallery);
                                if (image != null) {
                                  setState(() {
                                    _profileImage = File(image.path);
                                  });
                                }
                                Navigator.pop(context);
                              } catch (e) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Gallery error: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      );
                    });
              },
              child: SizedBox(
                  height: SizeConfig.blockSizeHorizontal! * 25,
                  width: SizeConfig.blockSizeHorizontal! * 25,
                  child: _singleton.userData['profile_image'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: Image.network(
                              _singleton.userData['profile_image'],
                              fit: BoxFit.cover))
                      : (_profileImage == null)
                          ? Image.asset("assets/generic_profile.png")
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(100),
                              child: Image.file(_profileImage!,
                                  fit: BoxFit.cover))),
            ),
            // Padding(
            //   padding: const EdgeInsets.all(8.0),
            //   child: TextField(
            //     controller: nameController,
            //     decoration: const InputDecoration(
            //       labelText: 'Display Name',
            //     ),
            //   ),
            // ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: usernameController,
                maxLength: 35,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter username (max 35 characters)',
                  counterText: '$_usernameLength/35',
                  counterStyle: TextStyle(
                    color: _usernameLength > 45 ? Colors.red : 
                           _usernameLength > 40 ? Colors.orange : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: _usernameLength > 45 ? Colors.red : Colors.blue,
                      width: 2.0,
                    ),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _usernameLength = value.length;
                  });
                },
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // String oldDisplayName = (Auth().user!.displayName != null)
                  //     ? Auth().user!.displayName!
                  //     : '';
                  String oldUsername = _singleton.userData['name'];

                  String newUsername = (usernameController.text.isEmpty)
                      ? oldUsername
                      : usernameController.text;

                  // Validate username length
                  if (newUsername.length > 35) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Username cannot exceed 35 characters'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (_profileImage == null) {
                    await Database().updateProfile(newUsername, null);
                  } else {
                    String imageUrl = await Database().uploadProfileImage(_profileImage!);
                    await Database().updateProfile(newUsername, imageUrl);
                  }

                  Navigator.pushNamedAndRemoveUntil(
                      context, '/', (route) => false);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error saving profile: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Current Username: ',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${_singleton.userData['name']}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
