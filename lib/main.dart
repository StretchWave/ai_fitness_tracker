import 'package:ai_fitness_tracker/screens/home_screen.dart'; // Import Home
import 'package:ai_fitness_tracker/widgets/ai_status_overlay.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

List<CameraDescription> cameras = [];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Using Native Camera

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return GlobalAiOverlay(child: child!);
      },
      home: const HomeScreen(), // Set Home
    );
  }
}
