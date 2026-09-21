import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:video_player/video_player.dart';
import 'package:memories_through_lenses/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:memories_through_lenses/services/post_creation.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late List<CameraDescription> cameras;
  CameraController? controller;
  XFile? videoFile;
  VideoPlayerController? videoController;
  bool isRecording = false;
  bool _capturing = false;
  bool isPlaying = false;
  XFile? imageFile;
  String cameraMode = "photo";
  String? _errorMessage;
  bool _isInitializing = true;

  int _selectedCameraIndex = 0;

  Future<void> initCamera() async {
    try {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });

      cameras = await availableCameras().timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (kDebugMode) print(cameras);

      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = "No cameras found on this device";
            _isInitializing = false;
          });
        }
        return;
      }

      controller = CameraController(cameras[0], ResolutionPreset.high);
      await controller!.initialize().timeout(const Duration(seconds: 20));

      if (!mounted) return;

      await controller!
          .lockCaptureOrientation()
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;

      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      if (kDebugMode) print("Camera initialization error: $e");
      if (mounted) {
        setState(() {
          _errorMessage =
              "Camera access denied or unavailable. Please grant camera permission in settings.";
          _isInitializing = false;
        });
      }
    }
  }

  // Method to switch between cameras.
  Future<void> _switchCamera() async {
    if (_capturing) return;
    try {
      if (cameras.length < 2) return;
      _selectedCameraIndex = (_selectedCameraIndex + 1) % cameras.length;
      if (controller != null) {
        await controller!.dispose().timeout(const Duration(seconds: 5));
      }
      if (!mounted) return;
      controller = CameraController(
          cameras[_selectedCameraIndex], ResolutionPreset.high);
      await controller!.initialize().timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {});
      await controller!
          .lockCaptureOrientation()
          .timeout(const Duration(seconds: 10));
    } catch (error) {
      PostTrace('camera')
          .event('camera_switch', 'error', {'code': PostTrace.code(error)});
      if (mounted) {
        setState(() {
          _errorMessage =
              'Could not switch cameras. Please reopen the camera and try again.';
        });
      }
    }
  }

  void setupVideoplayer() {
    if (videoFile != null) {
      videoController = VideoPlayerController.file(File(videoFile!.path))
        ..initialize().then((_) {
          // setState(() {});
        });
    }
  }

  @override
  void initState() {
    super.initState();

    initCamera();
  }

  @override
  void dispose() {
    final camera = controller;
    if (camera != null) {
      unawaited(camera
          .dispose()
          .timeout(const Duration(seconds: 5))
          .catchError((Object error) {
        PostTrace('camera')
            .event('camera_dispose', 'error', {'code': PostTrace.code(error)});
      }));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);

    return Scaffold(
      body: (videoFile == null)
          ? Stack(
              children: [
                if (_errorMessage != null)
                  Container(
                    color: Colors.black,
                    width: SizeConfig.blockSizeHorizontal! * 100,
                    height: SizeConfig.blockSizeVertical! * 100,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.camera_alt_outlined,
                              size: 80,
                              color: Colors.white54,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Go Back'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (controller != null && controller!.value.isInitialized)
                  SizedBox(
                      width: SizeConfig.blockSizeHorizontal! * 100,
                      height: SizeConfig.blockSizeVertical! * 100,
                      child: AspectRatio(
                          aspectRatio: controller!.value.aspectRatio,
                          child: CameraPreview(controller!)))
                else
                  Container(
                      color: Colors.black,
                      width: SizeConfig.blockSizeHorizontal! * 100,
                      height: SizeConfig.blockSizeVertical! * 100,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )),
                // back button in the top-left corner.
                Positioned(
                  top: SizeConfig.blockSizeVertical! * 5,
                  left: SizeConfig.blockSizeHorizontal! * 5,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
                // Camera flip button in the top-right corner.
                Positioned(
                  top: SizeConfig.blockSizeVertical! * 5,
                  right: SizeConfig.blockSizeHorizontal! * 5,
                  child: IconButton(
                    icon: const Icon(Icons.flip_camera_android,
                        color: Colors.white),
                    onPressed: _switchCamera,
                  ),
                ),
                // photo / video toggle
                Positioned(
                  top: SizeConfig.blockSizeVertical! * 5,
                  left: SizeConfig.blockSizeHorizontal! * 38.5,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(Icons.photo_camera,
                            color: (cameraMode == 'photo')
                                ? Colors.white
                                : Colors.grey[700]),
                        onPressed: () {
                          cameraMode = "photo";
                          setState(() {});
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.videocam,
                            color: (cameraMode == 'video')
                                ? Colors.white
                                : Colors.grey[700]),
                        onPressed: () {
                          cameraMode = "video";
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 30,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // IconButton(
                      //   icon: Icon(Icons.camera),
                      //   onPressed: () async {
                      //     final image = await controller!.takePicture();
                      //     print(image.path);
                      //   },
                      // ),
                      SizedBox(
                        width: SizeConfig.blockSizeHorizontal! * 20,
                        height: SizeConfig.blockSizeHorizontal! * 20,
                        child: IconButton(
                          padding: const EdgeInsets.all(0),
                          iconSize: 80,
                          icon: Icon(Icons.circle,
                              color:
                                  (!isRecording) ? Colors.white : Colors.red),
                          onPressed: () async {
                            print("pressed");
                            if (cameraMode == 'photo') {
                              if (_capturing ||
                                  controller?.value.isInitialized != true) {
                                return;
                              }
                              _capturing = true;
                              final trace = PostTrace(
                                  'capture-${DateTime.now().microsecondsSinceEpoch}');
                              trace.event('camera_capture', 'start');
                              try {
                                final image = await controller!
                                    .takePicture()
                                    .timeout(const Duration(seconds: 30));
                                trace.event('camera_capture', 'success');
                                if (!context.mounted) return;
                                final provider = Provider.of<UserProvider>(
                                    context,
                                    listen: false);
                                provider.setImageFile(File(image.path));
                                provider.setVideoFile(null);
                                Navigator.pushNamed(context, '/create');
                              } catch (error) {
                                trace.event('camera_capture', 'error',
                                    {'code': PostTrace.code(error)});
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content: Text(
                                        'Could not capture the photo. Please try again.'),
                                  ));
                                }
                              } finally {
                                _capturing = false;
                              }
                            } else {
                              if (!controller!.value.isRecordingVideo) {
                                isRecording = true;
                                setState(() {});
                                await controller!.startVideoRecording();
                              } else {
                                isRecording = false;
                                setState(() {});
                                final video =
                                    await controller!.stopVideoRecording();
                                // print(video.path);
                                videoFile = video;
                                setupVideoplayer();
                                final provider = Provider.of<UserProvider>(
                                    context,
                                    listen: false);
                                provider.setVideoFile(File(videoFile!.path));
                                provider.setImageFile(null);
                                setState(() {
                                  // singleton.notifyListenersSafe();
                                });
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Stack(
              children: [
                SizedBox(
                    width: SizeConfig.blockSizeHorizontal! * 100,
                    height: SizeConfig.blockSizeVertical! * 100,
                    child: VideoPlayer(videoController!)),
                Positioned(
                  bottom: 30,
                  left: 16,
                  right: 16,
                  child: Stack(children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        SizedBox(
                          width: SizeConfig.blockSizeHorizontal! * 90,
                          height: SizeConfig.blockSizeVertical! * 100,
                          child: IconButton(
                            icon: (!isPlaying)
                                ? const Icon(
                                    Icons.play_arrow,
                                    size: 100,
                                    color: Colors.white,
                                  )
                                : Container(),
                            onPressed: () {
                              if (isPlaying) {
                                videoController!.pause();
                              } else {
                                videoController!.play();
                              }
                              isPlaying = !isPlaying;
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          iconSize: SizeConfig.blockSizeHorizontal! * 20,
                          color: Colors.white,
                          icon: Icon(Icons.cancel),
                          onPressed: () {
                            videoFile = null;
                            setState(() {});
                          },
                        ),
                        SizedBox(
                          height: SizeConfig.blockSizeVertical! * 100,
                        ),
                        IconButton(
                          iconSize: SizeConfig.blockSizeHorizontal! * 20,
                          color: Colors.white,
                          icon: Icon(Icons.check_circle),
                          onPressed: () {
                            final provider = Provider.of<UserProvider>(context,
                                listen: false);
                            provider.setVideoFile(File(videoFile!.path));
                            provider.setImageFile(null);
                            Navigator.pushNamed(context, '/create');
                          },
                        )
                      ],
                    )
                  ]),
                ),
              ],
            ),
    );
  }
}
