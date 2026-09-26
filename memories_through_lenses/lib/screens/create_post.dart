import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:memories_through_lenses/providers/user_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:memories_through_lenses/services/image_utils.dart';
import 'package:memories_through_lenses/services/post_creation.dart';

class Pair {
  final String key;
  final String value;

  Pair({required this.key, required this.value});
}

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key, this.createPost, this.pickPhoto});

  final Future<XFile?> Function(ImageSource source)? pickPhoto;

  final PostCreation Function(String group, String caption, Uint8List image)?
      createPost;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _captionController = TextEditingController();
  Uint8List? _postMedia;
  String _selectedGroup = '';
  List<Pair> groups = [];
  bool uploading = false;
  String _message = '';
  String? _selectionId;

  bool _picking = false;
  bool _published = false;
  PostCreation? _submission;
  bool get _locked =>
      uploading || _picking || _published || _submission != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<UserProvider>(context, listen: false);
    final file = provider.imageFile;
    if (file != null && _postMedia == null && !_picking) {
      provider.imageFile = null;
      unawaited(_selectImage(ImageSource.camera, captured: XFile(file.path)));
    }
  }

  void setGroups(List<Map<String, dynamic>> groupData) {
    groups.clear();
    for (var group in groupData) {
      final id = group['groupID'];
      final name = group['name'];
      if (id is String &&
          id.isNotEmpty &&
          !id.contains('/') &&
          name is String) {
        groups.add(Pair(key: id, value: name));
      }
    }
    if (_submission == null &&
        !groups.any((group) => group.key == _selectedGroup)) {
      _selectedGroup = '';
    }
  }

  @override
  void dispose() {
    _submission?.cancel();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromGallery() => _selectImage(ImageSource.gallery);
  Future<void> _pickImageFromCamera() => _selectImage(ImageSource.camera);

  Future<void> _selectImage(ImageSource source, {XFile? captured}) async {
    if (_locked) return;
    final trace =
        PostTrace('selection-${DateTime.now().microsecondsSinceEpoch}');
    var stage = captured != null ? 'camera_handoff' : 'picker_${source.name}';
    setState(() {
      _picking = true;
      _message = '';
    });
    trace.event(stage, 'start');
    try {
      final image = captured ??
          await (widget.pickPhoto?.call(source) ??
                  ImagePicker().pickImage(
                    source: source,
                    maxWidth: 1920,
                    maxHeight: 1920,
                    imageQuality: 90,
                  ))
              .timeout(const Duration(minutes: 2));
      if (image == null) {
        trace.event(stage, 'canceled');
        return;
      }
      trace.event(stage, 'success');
      trace.event('photo', 'picked');
      stage = 'selected_file_length';
      trace.event(stage, 'start');
      final length = await image.length().timeout(const Duration(seconds: 10));
      if (length == 0 || length > ImageUtils.maxInputBytes) {
        throw const FormatException('Empty or oversized photo');
      }
      trace.event(stage, 'success', {'bytes': length});
      stage = 'selected_file_read';
      trace.event(stage, 'start');
      final bytes =
          await image.readAsBytes().timeout(const Duration(seconds: 15));
      trace.event('selected_file_read', 'success', {'bytes': bytes.length});
      if (!mounted) return;
      setState(() {
        _postMedia = bytes;
        _selectionId = trace.id;
        _submission = null;
      });
    } catch (error) {
      trace.event(stage, error is TimeoutException ? 'timeout' : 'failure',
          {'code': PostTrace.code(error)});
      if (mounted) {
        setState(() {
          _message =
              'Could not open this photo. Try again; for an iCloud photo, download it in Photos first.';
        });
      }
    } finally {
      _picking = false;
      if (mounted) setState(() {});
      trace.event('selection_ui', 'idle');
    }
  }

  Future<void> _sharePost() async {
    if (uploading ||
        _picking ||
        _published ||
        _postMedia == null ||
        _selectedGroup.isEmpty) {
      return;
    }
    setState(() {
      uploading = true;
      _message = '';
    });
    PostTrace? trace;
    var success = false;
    try {
      _submission ??= (widget.createPost ?? Database().createPost)(
          _selectedGroup, _captionController.text, _postMedia!);
      trace = _submission!.trace;
      trace.event('ui', 'loading', {'selection': _selectionId});
      await _submission!.submit().timeout(const Duration(minutes: 6));
      success = true;
      _published = true;
    } catch (error) {
      final failure = error is PostCreationFailure
          ? error
          : PostCreationFailure('post creation', error,
              pending: _submission?.pending ?? false);
      trace?.event('ui', 'failure', {
        'code': PostTrace.code(failure.cause),
        'pending': failure.pending,
        'failed_stage': failure.stage
      });
      if (!failure.pending) {
        _submission?.cancel();
        _submission = null;
      }
      _message = failure.message;
    } finally {
      // Clear before navigation, on every result, even if this route is gone.
      uploading = false;
      if (mounted) setState(() {});
      trace?.event('ui', 'idle');
    }
    if (!mounted || !success) return;
    try {
      trace?.event('navigation', 'start');
      // Navigator's Future completes when the new route is popped, not when
      // it appears. Never await it as part of posting.
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      trace?.event('navigation', 'dispatched');
    } catch (error) {
      trace?.event('navigation', 'error', {'code': PostTrace.code(error)});
      setState(() {
        _message =
            'Your post was saved, but Home could not open. Use Back to return home.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    final provider = Provider.of<UserProvider>(context);

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
            Navigator.pushNamedAndRemoveUntil(
                context, '/home', (route) => false);
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
                        ? Image.memory(
                            _postMedia!,
                            fit: BoxFit.cover,
                            cacheWidth: ImageUtils.maxDimension,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text(
                                  'Photo preview unavailable. Select another photo.'),
                            ),
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
                        onPressed: _locked ? null : _pickImageFromGallery,
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
                        onPressed: _locked ? null : _pickImageFromCamera,
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
                  enabled: !_locked,
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
                      borderSide:
                          const BorderSide(color: Colors.blue, width: 2),
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
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final group = groups[index];
                            final isSelected = _selectedGroup == group.key;
                            return ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              tileColor: isSelected
                                  ? Colors.blue.withOpacity(0.1)
                                  : null,
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
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[600],
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                group.value,
                                style: GoogleFonts.poppins(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? Colors.blue
                                      : Colors.grey[800],
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.blue)
                                  : null,
                              onTap: _locked
                                  ? null
                                  : () {
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
                    onPressed: (_postMedia != null &&
                            _selectedGroup.isNotEmpty &&
                            !uploading &&
                            !_picking &&
                            !_published)
                        ? _sharePost
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
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
                        Icon(Icons.error_outline,
                            color: Colors.red[700], size: 20),
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
