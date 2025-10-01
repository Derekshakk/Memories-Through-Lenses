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

  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _postMedia = File(image.path);
        mediaType = 'image';
      });
    }
  }

  Future<void> _pickImageFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _postMedia = File(image.path);
        mediaType = 'image';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final provider = Provider.of<UserProvider>(context);

    // Get media from provider on first build
    if (_postMedia == null) {
      if (provider.imageFile != null) {
        _postMedia = provider.imageFile;
        mediaType = 'image';
        provider.imageFile = null;
      }
    }

    setGroups(provider.groups);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        title: Text(
          'Create Post',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Preview Section
                Text(
                  'Your Photo',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: SizeConfig.blockSizeVertical! * 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _postMedia != null
                        ? Image.file(
                            _postMedia!,
                            fit: BoxFit.cover,
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Image Selected',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Choose a photo from gallery or camera',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // Image Selection Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pickImageFromGallery,
                        icon: const Icon(Icons.photo_library, size: 20),
                        label: Text(
                          'Gallery',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pickImageFromCamera,
                        icon: const Icon(Icons.camera_alt, size: 20),
                        label: Text(
                          'Camera',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Caption Field
                Text(
                  'Caption',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _captionController,
                  style: GoogleFonts.poppins(),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Write a caption for your photo...',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Select Group Section
                Text(
                  'Select Group',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  height: SizeConfig.blockSizeVertical! * 25,
                  child: groups.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.groups_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No Groups Available',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create or join a group to post',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: groups.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final group = groups[index];
                            final isSelected = _selectedGroup == group.key;
                            return ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              tileColor: isSelected ? Colors.blue.withOpacity(0.1) : null,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.blue
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.group,
                                  color: isSelected ? Colors.white : Colors.grey[600],
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                group.value,
                                style: GoogleFonts.poppins(
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  color: isSelected ? Colors.blue : Colors.grey[800],
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle, color: Colors.blue)
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedGroup = group.key;
                                });
                              },
                            );
                          },
                        ),
                ),

                const SizedBox(height: 32),

                // Post Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_postMedia != null && _selectedGroup != '' && !uploading)
                        ? () {
                            setState(() {
                              uploading = true;
                              _message = '';
                            });
                            Database()
                                .createPost(_selectedGroup,
                                    _captionController.text, _postMedia!)
                                .then((value) {
                              if (!value) {
                                setState(() {
                                  uploading = false;
                                  _message =
                                      'Error uploading post. Image is classified as inappropriate';
                                });
                              } else {
                                Navigator.pushNamedAndRemoveUntil(
                                    context, '/home', (route) => false);
                              }
                            });
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: uploading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Uploading...',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'Share Post',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                if (_message.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _message,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.red[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
