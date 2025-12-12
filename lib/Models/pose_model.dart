import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePoint {
  final double x;
  final double y;
  final double z;
  final double visibility;

  PosePoint({
    required this.x,
    required this.y,
    required this.z,
    required this.visibility,
  });

  factory PosePoint.fromLandmark(PoseLandmark lm) {
    return PosePoint(
      x: lm.x,
      y: lm.y,
      z: lm.z,
      visibility: lm.likelihood,
    );
  }
}
