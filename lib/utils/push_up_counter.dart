import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PushUpCounter {
  int counter = 0;
  bool _isDown = false;
  String status = "Start";
  String lastRepAccuracy = "0%";

  // Track deepest point of current rep
  double _minElbowAngle = 180.0;
  // Track body alignment (Shoulder-Hip-Ankle) at the deepest point
  double _alignmentAtDeepestPoint = 0.0;

  int checkPushUp(Pose pose) {
    // We need at least one arm to be visible (Shoulder, Elbow, Wrist)
    // We'll check both and use the one with higher visibility or just the first one found.

    // Left landmarks
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    // Right landmarks
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    if (_isLandmarkVisible(leftShoulder) &&
        _isLandmarkVisible(leftElbow) &&
        _isLandmarkVisible(leftWrist)) {
      _processPose(
        shoulder: leftShoulder!,
        elbow: leftElbow!,
        wrist: leftWrist!,
        hip: leftHip,
        ankle: leftAnkle,
      );
    } else if (_isLandmarkVisible(rightShoulder) &&
        _isLandmarkVisible(rightElbow) &&
        _isLandmarkVisible(rightWrist)) {
      _processPose(
        shoulder: rightShoulder!,
        elbow: rightElbow!,
        wrist: rightWrist!,
        hip: rightHip,
        ankle: rightAnkle,
      );
    } else {
      status = "No Pose";
    }

    return counter;
  }

  bool _isLandmarkVisible(PoseLandmark? landmark) {
    return landmark != null && landmark.likelihood > 0.5;
  }

  void _processPose({
    required PoseLandmark shoulder,
    required PoseLandmark elbow,
    required PoseLandmark wrist,
    PoseLandmark? hip,
    PoseLandmark? ankle,
  }) {
    final elbowAngle = _calculateAngle(shoulder, elbow, wrist);

    // Push-up logic
    // Down phase: Angle < 135 (relaxed from 90 to catch shallow reps)
    // Up phase: Angle > 160 (approx)

    if (elbowAngle < 135) {
      if (!_isDown) {
        // Only update status if we weren't already down
        status = "Down";
        // Reset min angle when starting a new rep descent
        _minElbowAngle = 180.0;
        _alignmentAtDeepestPoint = 0.0;
      }
      _isDown = true;
    }

    // Track minimum angle while in or approaching down position
    if (_isDown) {
      if (elbowAngle < _minElbowAngle) {
        _minElbowAngle = elbowAngle;

        // Capture alignment at this deepest point
        // Only calculate if needed
        if (_isLandmarkVisible(hip) && _isLandmarkVisible(ankle)) {
          _alignmentAtDeepestPoint = _calculateAngle(shoulder, hip!, ankle!);
        }
      }
    }

    if (elbowAngle > 160 && _isDown) {
      counter++;
      status = "Up";
      _isDown = false;

      // --- Calculate Accuracy ---

      // 1. Depth Score (50% weight)
      // Ideal <= 90.
      double depthScore = 0;
      if (_minElbowAngle <= 90) {
        depthScore = 100.0;
      } else {
        // Deviation from 90 (e.g. 150 -> 0)
        double deviation = _minElbowAngle - 90;
        depthScore = (1.0 - (deviation / 60.0)) * 100;
      }
      depthScore = depthScore.clamp(0.0, 100.0);

      // 2. Form Score (Body Alignment) (50% weight)
      // Ideal ~180. Accept > 160 as "good".
      // If landmarks weren't found, we might ignore this or default to 100?
      // Let's ignore it if 0.0 (not found).
      double formScore = 0;
      if (_alignmentAtDeepestPoint > 0) {
        if (_alignmentAtDeepestPoint >= 150) {
          // 150-180 is acceptable range
          formScore = 100.0;
        } else {
          // < 150 is sagging or piking
          // 100 -> 0 score. Range 50 degrees (150 - 100)
          double deviation = 150 - _alignmentAtDeepestPoint;
          formScore = (1.0 - (deviation / 50.0)) * 100;
        }
      } else {
        // If we can't see hips/legs, assume 100 or give same as depth?
        // Let's assume matches depthScore to not penalize visibility issues blindly
        formScore = depthScore;
      }
      formScore = formScore.clamp(0.0, 100.0);

      // Composite
      double totalScore = (depthScore + formScore) / 2;

      lastRepAccuracy = "${totalScore.toInt()}%";
    }
  }

  double _calculateAngle(
    PoseLandmark first,
    PoseLandmark middle,
    PoseLandmark last,
  ) {
    final result =
        atan2(last.y - middle.y, last.x - middle.x) -
        atan2(first.y - middle.y, first.x - middle.x);
    var angle = result * 180 / pi;
    angle = angle.abs();

    if (angle > 180) {
      angle = 360 - angle;
    }

    return angle;
  }

  void reset() {
    counter = 0;
    _isDown = false;
    status = "Start";
    lastRepAccuracy = "0%";
    _minElbowAngle = 180.0;
    _alignmentAtDeepestPoint = 0.0;
  }
}
