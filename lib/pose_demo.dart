import 'package:flutter/material.dart';
import 'package:ai_fitness_tracker/camera_view.dart';
import 'package:ai_fitness_tracker/pose_bridge.dart';
import 'package:ai_fitness_tracker/skeleton_painter.dart';
import 'package:ai_fitness_tracker/rep_counter.dart'; // Import RepCounter
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PoseDemoScreen extends StatefulWidget {
  const PoseDemoScreen({super.key});

  @override
  State<PoseDemoScreen> createState() => _PoseDemoScreenState();
}

class _PoseDemoScreenState extends State<PoseDemoScreen> {
  final PoseBridge _bridge = PoseBridge();
  final RepCounter _repCounter = RepCounter(); // Instantiate Counter
  static const MethodChannel _cameraControl = MethodChannel(
    'com.workout/pose_camera_control',
  );
  bool _permissionGranted = false;
  int _reps = 0; // Local state for UI

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _permissionGranted = status.isGranted;
    });
  }

  Future<void> _switchCamera() async {
    try {
      await _cameraControl.invokeMethod('switchCamera');
    } on PlatformException {
      // Handle camera switch error silently
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Push-Up Counter'), // Updated Title
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _reps = 0;
                _repCounter.reset();
              });
            },
            tooltip: "Reset Counter",
          ),
        ],
      ),
      floatingActionButton: _permissionGranted
          ? FloatingActionButton(
              onPressed: _switchCamera,
              child: const Icon(Icons.cameraswitch),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      body: Center(
        child: _permissionGranted
            ? AspectRatio(
                aspectRatio: 3 / 4,
                child: Stack(
                  children: [
                    // 1. Native Camera View (Background)
                    const Positioned.fill(child: PoseCameraPreview()),

                    // 2. Overlay Data & Skeleton
                    Positioned.fill(
                      child: StreamBuilder<List<Map<String, double>>>(
                        stream: _bridge.poseStream,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(
                              child: Text(
                                "Searching for body...",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  shadows: [BoxShadow(blurRadius: 2)],
                                ),
                              ),
                            );
                          }

                          // PROCESS LANDMARKS
                          _repCounter.processLandmarks(snapshot.data!);

                          // Optimization: Only setState if count changed
                          if (_reps != _repCounter.count) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted)
                                setState(() => _reps = _repCounter.count);
                            });
                          }

                          return Stack(
                            children: [
                              // Skeleton Overlay
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: SkeletonPainter(snapshot.data!),
                                ),
                              ),

                              // Rep Counter & Feedback UI
                              Positioned(
                                bottom: 20,
                                left: 0,
                                right: 0,
                                child: Column(
                                  children: [
                                    Text(
                                      "REPS: $_reps",
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 50,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          BoxShadow(
                                            blurRadius: 5,
                                            color: Colors.black,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _repCounter.feedback,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Camera Permission Required"),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _checkPermission,
                    child: const Text("Grant Permission"),
                  ),
                ],
              ),
      ),
    );
  }
}
