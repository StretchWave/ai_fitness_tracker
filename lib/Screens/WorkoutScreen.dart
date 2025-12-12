import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../services/pose_service.dart';
import '../painters/pose_painter.dart';

class WorkoutScreen extends StatefulWidget {
  @override
  _WorkoutScreenState createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  CameraController? _cameraController;
  PoseService poseService = PoseService();
  Map<PoseLandmarkType, PoseLandmark>? _currentLandmarks;

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    poseService.dispose();
    super.dispose();
  }

  Future<void> initCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.first;

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();

    _cameraController!.startImageStream((CameraImage image) async {
final WriteBuffer buffer = WriteBuffer();
for (Plane plane in image.planes) {
  buffer.putUint8List(plane.bytes);
}
final bytes = buffer.done().buffer.asUint8List();

final inputImage = InputImage.fromBytes(
  bytes: bytes,
  metadata: InputImageMetadata(
    size: Size(image.width.toDouble(), image.height.toDouble()),
    rotation: InputImageRotation.rotation0deg,
    format: InputImageFormat.yuv420, // FIXED
    bytesPerRow: image.planes[0].bytesPerRow,
  ),
);

final poses = await poseService.processFrame(inputImage);


      if (poses.isNotEmpty) {
        final pose = poses.first;

        setState(() {
          _currentLandmarks = pose.landmarks;
        });
      }
    });

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(_cameraController!),

          if (_currentLandmarks != null)
            CustomPaint(
              painter: PosePainter(_currentLandmarks!),
              child: Container(),
            ),
        ],
      ),
    );
  }
}
