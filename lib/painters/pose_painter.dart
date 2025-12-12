import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final Map<PoseLandmarkType, PoseLandmark> landmarks;

  PosePainter(this.landmarks);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 6
      ..style = PaintingStyle.fill;

    for (var lm in landmarks.values) {
      canvas.drawCircle(
        Offset(lm.x * size.width, lm.y * size.height),
        5,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) => true;
}
