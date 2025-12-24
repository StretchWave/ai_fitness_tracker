import 'package:flutter/material.dart';
import 'package:ai_fitness_tracker/screens/pose_demo.dart';
import 'package:ai_fitness_tracker/services/workout_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic> _progress = {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final progress = await WorkoutService().getTodayProgress();
    if (mounted) {
      setState(() {
        _progress = progress;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 20.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Full Body Routine',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_forever,
                            color: Colors.redAccent,
                          ),
                          onPressed: () async {
                            await WorkoutService().clearTodayProgress();
                            _loadProgress();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Dev: Progress Reset"),
                                ),
                              );
                            }
                          },
                          tooltip: "Dev: Reset Progress",
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '4 Exercises • 15 Mins',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                    const SizedBox(height: 30),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                        childAspectRatio: 0.85,
                        children: [
                          _buildWorkoutCard(
                            context,
                            title: '1. Box Push-Ups',
                            lookupName: 'Box Push-Ups',
                            icon:
                                Icons.accessibility, // Or another relevant icon
                            color: Colors.tealAccent,
                          ),
                          _buildWorkoutCard(
                            context,
                            title: '2. Push-Ups',
                            lookupName: 'Push-Ups',
                            icon: Icons.fitness_center,
                            color: Colors.blueAccent,
                          ),
                          _buildWorkoutCard(
                            context,
                            title: '3. Sit-Ups',
                            lookupName: 'Sit-Ups',
                            icon: Icons.accessibility_new,
                            color: Colors.orangeAccent,
                          ),
                          _buildWorkoutCard(
                            context,
                            title: '4. Squats',
                            lookupName: 'Squats',
                            icon: Icons.directions_walk,
                            color: Colors.purpleAccent,
                          ),
                          _buildWorkoutCard(
                            context,
                            title: '5. Jogging',
                            lookupName: 'Jogging',
                            icon: Icons.directions_run,
                            color: Colors.greenAccent,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action Button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: const Border(top: BorderSide(color: Colors.white10)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PoseDemoScreen(),
                      ),
                    );
                    _loadProgress(); // Reload when returning
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text(
                    'START CAMERA',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.greenAccent,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutCard(
    BuildContext context, {
    required String title,
    required String lookupName,
    required IconData icon,
    required Color color,
  }) {
    final isCompleted = _progress[lookupName]?['isCompleted'] == true;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey[900]!, Colors.grey[850]!],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check : icon,
              size: 40,
              color: isCompleted ? Colors.white : color,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCompleted ? 'Completed' : '10 Reps',
            style: TextStyle(
              color: isCompleted ? Colors.greenAccent : Colors.white38,
              fontSize: 12,
              fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
