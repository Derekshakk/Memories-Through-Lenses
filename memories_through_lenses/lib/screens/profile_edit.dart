import 'dart:io';

import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:image_picker/image_picker.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  File? _profileImage;
  TextEditingController usernameController = TextEditingController();
  int _usernameLength = 0;
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(Auth().user!.uid)
          .get();

      if (userDoc.exists && mounted) {
        final data = userDoc.data();
        print('Loaded user data: ${data?['name']}'); // Debug
        setState(() {
          userData = data;
          usernameController.text = userData?['name'] ?? '';
          _usernameLength = usernameController.text.length;
          isLoading = false;
        });
      } else {
        print('User document does not exist'); // Debug
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        title: Text(
          'Edit Profile',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with gradient background
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.blue, Colors.lightBlue],
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  // Profile Image
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 70,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _profileImage != null
                              ? FileImage(_profileImage!)
                              : (userData?['profile_image'] != null
                                  ? NetworkImage(userData!['profile_image'])
                                  : const AssetImage('assets/generic_profile.png')) as ImageProvider,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              builder: (context) {
                                return Container(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Change Profile Picture',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      ListTile(
                                        leading: const Icon(Icons.camera_alt,
                                            color: Colors.blue),
                                        title: const Text('Camera'),
                                        onTap: () async {
                                          try {
                                            final image = await ImagePicker()
                                                .pickImage(
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
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Camera error: ${e.toString()}'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.photo_library,
                                            color: Colors.blue),
                                        title: const Text('Gallery'),
                                        onTap: () async {
                                          try {
                                            final image = await ImagePicker()
                                                .pickImage(
                                                    source: ImageSource.gallery);
                                            if (image != null) {
                                              setState(() {
                                                _profileImage = File(image.path);
                                              });
                                            }
                                            Navigator.pop(context);
                                          } catch (e) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Gallery error: ${e.toString()}'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 5,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Current Username Display
                  Text(
                    userData?['name']?.toString() ?? 'No Username Set',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    Auth().user?.email ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
            // Form section
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'Username',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: usernameController,
                    maxLength: 35,
                    style: GoogleFonts.poppins(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Enter your username',
                      hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                      counterText: '$_usernameLength/35',
                      counterStyle: GoogleFonts.poppins(
                        color: _usernameLength > 30
                            ? Colors.orange
                            : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(
                          color: _usernameLength > 35
                              ? Colors.red
                              : Colors.blue,
                          width: 2.0,
                        ),
                      ),
                      prefixIcon:
                          const Icon(Icons.person_outline, color: Colors.blue),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _usernameLength = value.length;
                      });
                    },
                  ),
                  const SizedBox(height: 30),
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          String oldUsername = userData?['name'] ?? '';
                          String newUsername = (usernameController.text.isEmpty)
                              ? oldUsername
                              : usernameController.text;

                          if (newUsername.length > 35) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Username cannot exceed 35 characters',
                                  style: GoogleFonts.poppins(),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          // Show loading indicator
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );

                          if (_profileImage == null) {
                            await Database().updateProfile(newUsername, null);
                          } else {
                            String imageUrl = await Database()
                                .uploadProfileImage(_profileImage!);
                            await Database()
                                .updateProfile(newUsername, imageUrl);
                          }

                          Navigator.pop(context); // Close loading dialog
                          Navigator.pushNamedAndRemoveUntil(
                              context, '/', (route) => false);
                        } catch (e) {
                          Navigator.pop(context); // Close loading dialog
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Error saving profile: ${e.toString()}',
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Save Changes',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
