import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:video_player/video_player.dart';
import 'package:memories_through_lenses/shared/singleton.dart';

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
  bool isPlaying = false;
  XFile? imageFile;
  String cameraMode = "photo";

  final Singleton singleton = Singleton();

  Future<void> initCamera() async {
    cameras = await availableCameras();
    if (kDebugMode) print(cameras);

    if (cameras.isEmpty) {
      if (kDebugMode) print("No cameras found");
      return;
    }

    controller = CameraController(cameras[0], ResolutionPreset.high);
    controller!.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
    await controller!.lockCaptureOrientation();
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: (videoFile == null)
          ? Stack(
              children: [
                (controller != null)
                    ? SizedBox(
                        width: SizeConfig.blockSizeHorizontal! * 100,
                        height: SizeConfig.blockSizeVertical! * 100,
                        child: AspectRatio(
                            aspectRatio: controller!.value.aspectRatio,
                            child: CameraPreview(controller!)))
                    : Container(
                        color: Colors.black,
                        width: SizeConfig.blockSizeHorizontal! * 100,
                        height: SizeConfig.blockSizeVertical! * 100,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        )),
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
                              print("photo");
                              final image = await controller!.takePicture();
                              imageFile = image;
                              print(image.path);
                              setState(() {
                                singleton.imageFile = imageFile as File;
                                singleton.videoFile = null;
                                singleton.notifyListenersSafe();
                                Navigator.pop(context);
                              });
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
                                setState(() {
                                  singleton.videoFile = videoFile as File;
                                  singleton.imageFile = null;
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
                            singleton.videoFile = videoFile as File;
                            singleton.imageFile = null;
                            singleton.notifyListenersSafe();
                            Navigator.pop(context);
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
