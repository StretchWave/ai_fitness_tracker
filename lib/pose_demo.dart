import 'package:flutter/material.dart';
import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:ai_fitness_tracker/camera_view.dart';
import 'package:ai_fitness_tracker/pose_bridge.dart';
import 'package:ai_fitness_tracker/skeleton_painter.dart';
import 'package:ai_fitness_tracker/rep_counter.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

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

  // CRITICAL: GlobalKey to keep camera alive across layout changes
  final GlobalKey _cameraKey = GlobalKey();

  bool _permissionGranted = false;
  int _reps = 0;

  // Pedometer Vars
  Stream<StepCount>? _stepCountStream;
  int _steps = 0;
  int _initialSteps = -1;
  int _targetSteps = 1000;

  // Workout Sequence Data
  final List<String> _exercises = ['Push-Ups', 'Sit-Ups', 'Squats', 'Jogging'];
  int _currentExerciseIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _updateOrientation();
  }

  void _updateOrientation() {
    if (_exercises[_currentExerciseIndex] == 'Jogging') {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  @override
  void dispose() {
    // Reset to Portrait only when leaving
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _initPedometer() {
    _initialSteps = -1; // Reset baseline
    _steps = 0;

    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream!.listen(_onStepCount).onError(_onStepCountError);
  }

  void _onStepCount(StepCount event) {
    if (!mounted) return;
    if (_exercises[_currentExerciseIndex] != 'Jogging') return;

    if (_initialSteps == -1) {
      _initialSteps = event.steps;
    }

    setState(() {
      _steps = event.steps - _initialSteps;
      if (_steps < 0) _steps = 0; // Integrity check
    });
  }

  void _onStepCountError(error) {
    debugPrint("Pedometer Error: $error");
    setState(() {
      _steps = -1; // Indicate error in UI
    });
  }

  Future<void> _checkPermission() async {
    try {
      // Request Camera AND Activity Recognition (for Pedometer)
      final statuses = await [
        Permission.camera,
        Permission.activityRecognition,
      ].request();

      setState(() {
        _permissionGranted = statuses[Permission.camera]!.isGranted;
      });

      if (statuses[Permission.activityRecognition]!.isDenied) {
        debugPrint("Activity Recognition Denied");
        // We could show a snackbar here
      }
    } catch (e) {
      setState(() {
        _permissionGranted = true;
      });
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _cameraControl.invokeMethod('switchCamera');
      // If model needs reload on camera switch, we might need a delay or signal
      // But typically switch is internal.
    } on PlatformException {
      // Handle camera switch error silently
    }
  }

  void _resetCounter() {
    setState(() {
      _reps = 0;
      _repCounter.reset();
    });
  }

  void _nextExercise() {
    if (_currentExerciseIndex < _exercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
        _reps = 0;
        _repCounter.reset();
      });

      _updateOrientation();

      if (_exercises[_currentExerciseIndex] == 'Jogging') {
        _initPedometer();
      }
    } else {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Workout Complete!"),
        content: const Text(
          "Great job! You've finished the full body routine.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text("Finish"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String currentExercise = _exercises[_currentExerciseIndex];
    int targetReps = 10;

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: isLandscape
          ? null
          : AppBar(
              title: Text(currentExercise),
              centerTitle: true,
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.cameraswitch),
                  onPressed: _switchCamera,
                  tooltip: "Switch Camera",
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _resetCounter,
                  tooltip: "Reset Counter",
                ),
              ],
            ),
      body: isLandscape
          ? _buildLandscapeLayout(currentExercise, targetReps)
          : _buildPortraitLayout(currentExercise, targetReps),
    );
  }

  Widget _buildPortraitLayout(String currentExercise, int targetReps) {
    return Column(
      children: [
        if (_permissionGranted)
          AspectRatio(
            aspectRatio: 3 / 4,
            child: _buildCameraArea(currentExercise),
          )
        else
          Expanded(child: _buildPermissionRequest()),

        Expanded(child: _buildStatsPanel(currentExercise, targetReps)),
      ],
    );
  }

  Widget _buildLandscapeLayout(String currentExercise, int targetReps) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _permissionGranted
              ? _buildCameraArea(currentExercise)
              : _buildPermissionRequest(),
        ),

        Container(
          width: 150,
          color: Colors.black,
          child: _buildStatsPanel(
            currentExercise,
            targetReps,
            isLandscape: true,
          ),
        ),
      ],
    );
  }

  Widget _buildCameraArea(String currentExercise) {
    if (currentExercise == 'Jogging') {
      return _buildJoggingUI();
    }

    return Stack(
      children: [
        // 1. Native Camera View with GlobalKey to persist across rotation
        Positioned.fill(child: PoseCameraPreview(key: _cameraKey)),

        // 2. Overlay Data & Skeleton
        Positioned.fill(
          child: NativeDeviceOrientationReader(
            builder: (context) {
              final orientation = NativeDeviceOrientationReader.orientation(
                context,
              );
              int turns = 0;
              if (orientation == NativeDeviceOrientation.landscapeLeft) {
                turns = 3; // 270 degrees
              } else if (orientation ==
                  NativeDeviceOrientation.landscapeRight) {
                turns = 1; // 90 degrees (Flip of Left)
              }

              return StreamBuilder<List<Map<String, double>>>(
                stream: _bridge.poseStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.greenAccent,
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const SizedBox();
                  }

                  if (currentExercise == 'Push-Ups' ||
                      currentExercise == 'Squats' ||
                      currentExercise == 'Sit-Ups') {
                    _repCounter.processLandmarks(
                      snapshot.data!,
                      currentExercise,
                    );
                  }

                  if (_reps != _repCounter.count) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _reps = _repCounter.count);
                    });
                  }

                  return RotatedBox(
                    quarterTurns: turns,
                    child: CustomPaint(
                      painter: SkeletonPainter(snapshot.data!),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Back Button Overlay for Landscape
        if (MediaQuery.of(context).orientation == Orientation.landscape)
          Positioned(
            top: 20,
            left: 20,
            child: FloatingActionButton.small(
              heroTag: "back_btn", // Unique tag
              backgroundColor: Colors.black54,
              child: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
      ],
    );
  }

  Widget _buildJoggingUI() {
    if (_steps == -1) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Text(
            "Step Sensor Not Available\n(Try walking to wake it up)",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 18),
          ),
        ),
      );
    }

    double progress = _steps / _targetSteps;
    if (progress > 1.0) progress = 1.0;

    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.directions_run,
              size: 80,
              color: Colors.greenAccent,
            ),
            const SizedBox(height: 30),
            const Text(
              "Jog in Place",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Goal: $_targetSteps Steps",
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[800],
                color: Colors.greenAccent,
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "$_steps / $_targetSteps",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: ElevatedButton(
        onPressed: _checkPermission,
        child: const Text("Refrest Permission"),
      ),
    );
  }

  Widget _buildStatsPanel(
    String currentExercise,
    int targetReps, {
    bool isLandscape = false,
  }) {
    // Buttons for Landscape Control
    Widget landscapeControls = Column(
      children: [
        const Divider(color: Colors.white24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.cameraswitch, color: Colors.white),
              onPressed: _switchCamera,
              tooltip: "Switch Camera",
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _resetCounter,
              tooltip: "Reset Counter",
            ),
          ],
        ),
      ],
    );

    List<Widget> children = [
      if (currentExercise == 'Push-Ups' ||
          currentExercise == 'Squats' ||
          currentExercise == 'Sit-Ups') ...[
        // Reps
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: isLandscape
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            const Text(
              "Reps",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
            ),
            Text(
              "$_reps/$targetReps",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        // Accuracy
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: isLandscape
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            const Text(
              "Accuracy",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
            ),
            Text(
              "${_repCounter.accuracy.toStringAsFixed(0)}%",
              style: TextStyle(
                color: _repCounter.isProperForm
                    ? Colors.greenAccent
                    : Colors.redAccent,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ] else ...[
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fitness_center, color: Colors.white54),
            const SizedBox(height: 5),
            Text(
              currentExercise,
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ],

      // Next Button
      Material(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _nextExercise,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),

      if (isLandscape) landscapeControls,
    ];

    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: isLandscape
          ? Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: children,
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: children,
            ),
    );
  }
}
