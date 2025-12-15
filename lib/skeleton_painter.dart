import 'package:flutter/material.dart';

class SkeletonPainter extends CustomPainter {
  final List<Map<String, double>> landmarks;
  final Size sourceSize; // Not used yet, assuming normalized coordinates (0-1)

  SkeletonPainter(this.landmarks, {this.sourceSize = Size.zero});

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    final pointPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill
      ..strokeWidth = 8.0;

    final linePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Helper to get point from landmark index
    Offset? getPoint(int index) {
      if (index >= landmarks.length) return null;
      final lm = landmarks[index];
      // MediaPipe coords are usually normalized [0, 1]
      // x, y, z.
      return Offset(lm['x']! * size.width, lm['y']! * size.height);
    }

    // Draw Lines
    // Connections:
    // 11-12 (Shoulders)
    // 11-13 (Left Arm), 13-15 (Left Forearm)
    // 12-14 (Right Arm), 14-16 (Right Forearm)
    // 11-23 (Left Torso), 12-24 (Right Torso)
    // 23-24 (Hips)
    // 23-25 (Left Thigh), 25-27 (Left Shin)
    // 24-26 (Right Thigh), 26-28 (Right Shin)

    final connections = [
      [11, 12],
      [11, 13],
      [13, 15],
      [12, 14],
      [14, 16],
      [11, 23],
      [12, 24],
      [23, 24],
      [23, 25],
      [25, 27],
      [24, 26],
      [26, 28],
    ];

    for (var pair in connections) {
      final p1 = getPoint(pair[0]);
      final p2 = getPoint(pair[1]);
      if (p1 != null && p2 != null) {
        // Simple visibility check handled upstream or here
        if (p1.dx >= 0 && p1.dy >= 0 && p2.dx >= 0 && p2.dy >= 0) {
          canvas.drawLine(p1, p2, linePaint);
        }
      }
    }

    // Draw Points
    for (var i = 0; i < landmarks.length; i++) {
      // Using only critical points for cleaner look or all?
      // Let's draw 0-32
      final p = getPoint(i);
      if (p != null) {
        canvas.drawCircle(p, 5, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
