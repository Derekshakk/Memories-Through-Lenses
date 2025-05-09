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

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    usernameController.text = _singleton.userData['name'];
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
                              // final image = await ImagePicker().pickImage(
                              //     source: ImageSource.camera,
                              //     imageQuality: 50,
                              //     maxWidth: 150);
                              // if (image != null) {
                              //   setState(() {
                              //     _profileImage = File(image.path);
                              //   });
                              // }
                              // Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            title: const Text('Gallery'),
                            onTap: () async {
                              await ImagePicker()
                                  .pickImage(source: ImageSource.gallery)
                                  .then(
                                (value) {
                                  if (value != null) {
                                    setState(() {
                                      _profileImage = File(value.path);
                                    });
                                  }
                                },
                              );
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
                decoration: const InputDecoration(
                  labelText: 'Username',
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // String oldDisplayName = (Auth().user!.displayName != null)
                //     ? Auth().user!.displayName!
                //     : '';
                String oldUsername = _singleton.userData['name'];

                String newUsername = (usernameController.text.isEmpty)
                    ? oldUsername
                    : usernameController.text;

                if (_profileImage == null) {
                  Database().updateProfile(newUsername, null);
                } else {
                  Database().uploadProfileImage(_profileImage!).then((value) {
                    Database().updateProfile(newUsername, value);
                  });
                }

                Navigator.pushNamedAndRemoveUntil(
                    context, '/', (route) => false);
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
