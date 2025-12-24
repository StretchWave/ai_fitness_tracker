import 'package:flutter/material.dart';
import 'package:ai_fitness_tracker/services/workout_service.dart';

class WorkoutSummaryScreen extends StatefulWidget {
  final List<String> exercises;
  final VoidCallback onFinish;

  const WorkoutSummaryScreen({
    super.key,
    required this.exercises,
    required this.onFinish,
  });

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  Map<String, dynamic> _progress = {};
  bool _isLoading = true;

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
        _isLoading = false;
      });
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  bool _isAllCompleted() {
    for (var exercise in widget.exercises) {
      if (_progress[exercise]?['isCompleted'] != true) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Workout Summary'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Prevent back button
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            )
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Text(
                    "Today's Progress",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Expanded(
                    child: ListView.separated(
                      itemCount: widget.exercises.length,
                      separatorBuilder: (context, index) =>
                          const Divider(color: Colors.white24),
                      itemBuilder: (context, index) {
                        final exercise = widget.exercises[index];
                        final data = _progress[exercise];
                        final isCompleted = data?['isCompleted'] == true;
                        final duration = data?['durationSeconds'] ?? 0;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          tileColor: Colors.grey[900],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? Colors.greenAccent.withOpacity(0.2)
                                  : Colors.redAccent.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isCompleted ? Icons.check : Icons.close,
                              color: isCompleted
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                          ),
                          title: Text(
                            exercise,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCompleted
                                    ? 'Time: ${_formatDuration(duration)}'
                                    : 'Not Completed',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                              ),
                              if (data?['feedback'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  data!['feedback'],
                                  style: const TextStyle(
                                    color: Colors.orangeAccent,
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: isCompleted
                              ? null
                              : ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(
                                      context,
                                      exercise,
                                    ); // Return the exercise to retry
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: const Text('Do It'),
                                ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isAllCompleted()
                          ? widget.onFinish
                          : null, // Only active if all done? Or allow exit anyway? User request said "if not completed go back to complete".
                      // Let's make it allow finish but maybe warn? Or strictly disabled.
                      // User said: "if not completed go back to complete".
                      // So disable Finish if not all done.
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        disabledBackgroundColor: Colors.grey[800],
                        disabledForegroundColor: Colors.white38,
                      ),
                      child: Text(
                        _isAllCompleted()
                            ? 'FINISH WORKOUT'
                            : 'COMPLETE ALL TO FINISH',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  if (!_isAllCompleted()) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: widget.onFinish,
                      child: const Text(
                        "Exit Anyway",
                        style: TextStyle(color: Colors.white38),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
