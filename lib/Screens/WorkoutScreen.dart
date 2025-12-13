import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
// commons types are exported by google_mlkit_pose_detection; no direct alias needed
import 'dart:io';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  PoseDetector? _poseDetector;
  bool _isDetecting = false;
  List<Pose> _poses = [];
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  Future<void> _initialize() async {
    final cameras = await availableCameras();
    // Prefer back camera for body tracking; fall back to first available.
    CameraDescription selected = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () =>
          cameras.isNotEmpty ? cameras.first : throw 'No camera available',
    );

    _controller = CameraController(
      selected,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();

    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
    );

    // start image stream
    await _controller!.startImageStream(_processCameraImage);

    if (mounted) setState(() {});
  }

  Future<void> _stop() async {
    try {
      await _controller?.stopImageStream();
    } catch (_) {}
    await _controller?.dispose();
    await _poseDetector?.close();
  }

  InputImageRotation _rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      case 0:
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;
    try {
      // Concatenate planes' bytes into a single buffer
      final totalLength = image.planes.fold<int>(
        0,
        (sum, p) => sum + p.bytes.length,
      );
      final bytes = Uint8List(totalLength);
      int offset = 0;
      for (final plane in image.planes) {
        bytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
        offset += plane.bytes.length;
      }

      final imageRotation = _rotationIntToImageRotation(
        _controller!.description.sensorOrientation,
      );

      final inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.nv21;

      // The google_mlkit_commons version used here expects a single
      // InputImageMetadata (not a list of plane metadata). Use the first
      // plane's bytesPerRow as the row stride.
      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes.isNotEmpty ? image.planes[0].bytesPerRow : 0,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);

      final poses = await _poseDetector!.processImage(inputImage);

      if (mounted) {
        setState(() {
          _poses = poses;
          _imageSize = Size(image.width.toDouble(), image.height.toDouble());
        });
      }
    } catch (e) {
      // ignore errors for now
    } finally {
      _isDetecting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Workout - Pose Tracking')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview filling entire screen
          Stack(
            fit: StackFit.expand,
            children: [
              // Camera preview
              CameraPreview(_controller!),
              // Pose landmarks overlay on top of camera
              if (_imageSize != null)
                CustomPaint(
                  painter: PosePainter(
                    poses: _poses,
                    imageSize: _imageSize!,
                    rotation: _controller!.description.sensorOrientation,
                    cameraLensDirection: _controller!.description.lensDirection,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final int rotation;
  final CameraLensDirection cameraLensDirection;

  PosePainter({
    required this.poses,
    required this.imageSize,
    required this.rotation,
    required this.cameraLensDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Red dots for all landmarks
    final landmarkPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    // Lines connecting joints
    final linePaint = Paint()
      ..color = Colors.red.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final pose in poses) {
      // Draw all 33 landmarks as red dots
      for (final landmark in pose.landmarks.values) {
        final x = _translateX(
          landmark.x,
          size,
          imageSize,
          rotation,
          cameraLensDirection,
        );
        final y = _translateY(
          landmark.y,
          size,
          imageSize,
          rotation,
          cameraLensDirection,
        );
        canvas.drawCircle(Offset(x, y), 5.0, landmarkPaint);
      }

      // Draw skeleton lines connecting key joints
      void drawLineIfExists(PoseLandmarkType a, PoseLandmarkType b) {
        final A = pose.landmarks[a];
        final B = pose.landmarks[b];
        if (A != null && B != null) {
          final startX = _translateX(
            A.x,
            size,
            imageSize,
            rotation,
            cameraLensDirection,
          );
          final startY = _translateY(
            A.y,
            size,
            imageSize,
            rotation,
            cameraLensDirection,
          );
          final endX = _translateX(
            B.x,
            size,
            imageSize,
            rotation,
            cameraLensDirection,
          );
          final endY = _translateY(
            B.y,
            size,
            imageSize,
            rotation,
            cameraLensDirection,
          );

          canvas.drawLine(
            Offset(startX, startY),
            Offset(endX, endY),
            linePaint,
          );
        }
      }

      // Arms
      drawLineIfExists(
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftElbow,
      );
      drawLineIfExists(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
      drawLineIfExists(
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightElbow,
      );
      drawLineIfExists(
        PoseLandmarkType.rightElbow,
        PoseLandmarkType.rightWrist,
      );
      // Torso
      drawLineIfExists(
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.rightShoulder,
      );
      drawLineIfExists(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
      drawLineIfExists(
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightHip,
      );
      drawLineIfExists(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
      // Legs
      drawLineIfExists(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
      drawLineIfExists(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
      drawLineIfExists(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
      drawLineIfExists(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
    }
  }

  double _translateX(
    double x,
    Size canvasSize,
    Size imageSize,
    int rotation,
    CameraLensDirection cameraLensDirection,
  ) {
    switch (rotation) {
      case 90:
        return x *
            canvasSize.width /
            (Platform.isIOS ? imageSize.width : imageSize.height);
      case 270:
        return canvasSize.width -
            x *
                canvasSize.width /
                (Platform.isIOS ? imageSize.width : imageSize.height);
      case 0:
      case 180:
        return x * canvasSize.width / imageSize.width;
      default:
        return x * canvasSize.width / imageSize.width;
    }
  }

  double _translateY(
    double y,
    Size canvasSize,
    Size imageSize,
    int rotation,
    CameraLensDirection cameraLensDirection,
  ) {
    switch (rotation) {
      case 90:
      case 270:
        return y *
            canvasSize.height /
            (Platform.isIOS ? imageSize.height : imageSize.width);
      case 0:
      case 180:
        return y * canvasSize.height / imageSize.height;
      default:
        return y * canvasSize.height / imageSize.height;
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.poses != poses ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.rotation != rotation ||
        oldDelegate.cameraLensDirection != cameraLensDirection;
  }
}
