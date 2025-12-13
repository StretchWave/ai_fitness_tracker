import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:ai_fitness_tracker/utils/pose_painter.dart';
import 'package:ai_fitness_tracker/services/pose_detection_service.dart';
// commons types are exported by google_mlkit_pose_detection; no direct alias needed

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  // Use the service instead of local detector
  final PoseDetectionService _poseDetectionService = PoseDetectionService();
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
    // Dispose the service
    _poseDetectionService.close();
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

    // start image stream
    await _controller!.startImageStream(_processCameraImage);

    if (mounted) setState(() {});
  }

  Future<void> _stop() async {
    try {
      await _controller?.stopImageStream();
    } catch (_) {}
    await _controller?.dispose();
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;
    try {
      final poses = await _poseDetectionService.processCameraImage(
        image,
        _controller!.description,
      );

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
