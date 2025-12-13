import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

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
