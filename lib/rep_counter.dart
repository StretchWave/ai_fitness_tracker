import 'dart:math';

class RepCounter {
  int count = 0;
  bool _isUp = false;

  // MediaPipe Body Landmarks for PoseLandmarker (Full Body 33 Keypoints)
  // 11: Left Shoulder, 13: Left Elbow, 15: Left Wrist
  // 12: Right Shoulder, 14: Right Elbow, 16: Right Wrist

  // Logic: Measure angle at Elbow (Shoulder - Elbow - Wrist)
  // Extension (Down): ~160-180 degrees
  // Flexion (Up): ~30-50 degrees

  void processLandmarks(List<Map<String, double>> landmarks) {
    if (landmarks.length < 33) return;

    // Check visibility logic if needed, assuming first high viz person

    // We will check both arms and count if either does a curl, or stick to one.
    // For simplicity, let's track the RIGHT arm (12, 14, 16)

    final shoulder = landmarks[12];
    final elbow = landmarks[14];
    final wrist = landmarks[16];

    if (shoulder['visibility']! < 0.5 ||
        elbow['visibility']! < 0.5 ||
        wrist['visibility']! < 0.5) {
      return;
    }

    final angle = calculateAngle(shoulder, elbow, wrist);

    // State Machine
    if (angle > 160) {
      _isUp = false; // Arm is down
    }

    if (!_isUp && angle < 50) {
      _isUp = true;
      count++;
    }
  }

  double calculateAngle(
    Map<String, double> a,
    Map<String, double> b,
    Map<String, double> c,
  ) {
    // b is the center point (elbow)
    final radians =
        atan2(c['y']! - b['y']!, c['x']! - b['x']!) -
        atan2(a['y']! - b['y']!, a['x']! - b['x']!);

    var angle = (radians * 180.0 / pi).abs();

    if (angle > 180.0) {
      angle = 360 - angle;
    }

    return angle;
  }
}
