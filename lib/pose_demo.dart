import 'package:flutter/material.dart';
import 'package:ai_fitness_tracker/camera_view.dart';
import 'package:ai_fitness_tracker/pose_bridge.dart';
import 'package:ai_fitness_tracker/rep_counter.dart';
import 'package:ai_fitness_tracker/skeleton_painter.dart';
import 'package:flutter/services.dart';

class PoseDemoScreen extends StatefulWidget {
  const PoseDemoScreen({super.key});

  @override
  State<PoseDemoScreen> createState() => _PoseDemoScreenState();
}

class _PoseDemoScreenState extends State<PoseDemoScreen> {
  final PoseBridge _bridge = PoseBridge();
  final RepCounter _repCounter = RepCounter();
  static const MethodChannel _cameraControl = MethodChannel(
    'com.workout/pose_camera_control',
  );
  int _reps = 0;

  Future<void> _switchCamera() async {
    try {
      await _cameraControl.invokeMethod('switchCamera');
    } on PlatformException catch (e) {
      debugPrint("Failed to switch camera: '${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Native Pose Counter')),
      floatingActionButton: FloatingActionButton(
        onPressed: _switchCamera,
        child: const Icon(Icons.cameraswitch),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      body: Stack(
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
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  );
                }

                // Process every frame
                _repCounter.processLandmarks(snapshot.data!);

                // Update UI only if count changes (optimization)
                if (_reps != _repCounter.count) {
                  // Schedule build to update reps
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _reps = _repCounter.count);
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

                    // Rep Counter UI
                    Positioned(
                      bottom: 50,
                      left: 0,
                      right: 0,
                      child: Column(
                        children: [
                          Text(
                            "Reps: $_reps",
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                BoxShadow(blurRadius: 10, color: Colors.black),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Data Points: ${snapshot.data!.length}",
                            style: const TextStyle(color: Colors.white),
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
    );
  }
}
