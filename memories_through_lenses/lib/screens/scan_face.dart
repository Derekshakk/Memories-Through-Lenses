import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:chewie/chewie.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:video_player/video_player.dart';

class ScanFace extends StatefulWidget {
  @override
  _ScanFaceState createState() => _ScanFaceState();
}

class _ScanFaceState extends State<ScanFace> {
  File? _videoFile;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  String _message = "";
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo(ImageSource source) async {
    final XFile? video = await _picker.pickVideo(source: source);
    if (video != null) {
      setState(() {
        _videoFile = File(video.path);
        _initializeVideoPlayer();
      });
    }
  }

  void _initializeVideoPlayer() {
    if (_videoFile == null) return;

    _videoController?.dispose(); // Dispose previous controllers
    _chewieController?.dispose();

    _videoController = VideoPlayerController.file(_videoFile!)
      ..initialize().then((_) {
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: false,
          looping: false,
        );
        setState(() {});
      });
  }

  Future<void> _uploadVideo() async {
    if (_videoFile == null) {
      print("No video selected");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select or record a video of your face")),
      );
      return;
    }
    setState(() {
      _isUploading = true;
      _message = "";
    });
    var url = await FirebaseDatabase.instance
        .ref('face_recognition_server_url')
        .once()
        .then((value) => value.snapshot.value.toString());
    print("Face Recognition Server URL: $url");
    var request = http.MultipartRequest(
      'POST',
      Uri.parse(url), // Flask server URL
    );
    request.files
        .add(await http.MultipartFile.fromPath('file', _videoFile!.path));
    request.fields['userID'] = Auth().user!.uid;

    var response = await request.send();
    var responseBody = await response.stream.bytesToString();
    var jsonResponse = json.decode(responseBody);

    if (response.statusCode == 200) {
      print("✅ Success! Face Encoding: ${jsonResponse['message']}");
      setState(() {
        _isUploading = false;
        _message = jsonResponse['message'];
      });
    } else {
      setState(() {
        _isUploading = false;
        _message = jsonResponse['error'];
      });
      print("❌ Error: ${jsonResponse['error']}");
    }
    _showDialog();
  }

  //show dialog to confirm if user wants to register face
  void _showDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Register Face"),
          content: Text(_message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/', (route) => false);
              },
              child: Text("ok"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("Register Face",
              style:
                  GoogleFonts.merriweather(fontSize: 30, color: Colors.black))),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _videoFile == null
                ? Container(
                    alignment: Alignment.center,
                    width: MediaQuery.of(context).size.width * 0.9,
                    height: MediaQuery.of(context).size.height * 0.3,
                    child: Text("No video selected or recorded",
                        style: TextStyle(fontSize: 20)))
                : Column(
                    children: [
                      Text("Video Preview"),
                      _chewieController != null &&
                              _videoController != null &&
                              _videoController!.value.isInitialized
                          ? Container(
                              decoration: BoxDecoration(
                                color: Colors.black,
                              ),
                              width: MediaQuery.of(context).size.width * 0.9,
                              height: MediaQuery.of(context).size.height * 0.3,
                              child: AspectRatio(
                                aspectRatio:
                                    _videoController!.value.aspectRatio,
                                child: Chewie(controller: _chewieController!),
                              ),
                            )
                          : CircularProgressIndicator(),
                    ],
                  ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () =>
                  _isUploading ? null : _pickVideo(ImageSource.camera),
              child: Text("Record Video", style: TextStyle(fontSize: 20)),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () =>
                  _isUploading ? null : _pickVideo(ImageSource.gallery),
              child: Text("Pick Video from Gallery",
                  style: TextStyle(fontSize: 20)),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isUploading ? null : _uploadVideo,
              child: Text(_isUploading ? "Uploading" : "Scan & Register Face",
                  style: TextStyle(fontSize: 20)),
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
