import 'dart:math';

class RepCounter {
  int count = 0;
  bool _isDown = false;
  String feedback = "";
  double accuracy = 0.0;
  bool isProperForm = true;

  void reset() {
    count = 0;
    _isDown = false;
    feedback = "";
    accuracy = 0.0;
    isProperForm = true;
  }

  void processLandmarks(List<Map<String, double>> landmarks) {
    if (landmarks.length < 33) return;

    // 1. Detect Best Side (Left vs Right)
    // Left: 11 (Shoulder), 13 (Elbow), 15 (Wrist)
    // Right: 12 (Shoulder), 14 (Elbow), 16 (Wrist)

    double leftScore =
        landmarks[11]['visibility']! +
        landmarks[13]['visibility']! +
        landmarks[15]['visibility']!;

    double rightScore =
        landmarks[12]['visibility']! +
        landmarks[14]['visibility']! +
        landmarks[16]['visibility']!;

    Map<String, double> shoulder;
    Map<String, double> elbow;
    Map<String, double> wrist;
    Map<String, double> hip;
    String side = "";

    if (leftScore > rightScore) {
      shoulder = landmarks[11];
      elbow = landmarks[13];
      wrist = landmarks[15];
      hip = landmarks[23]; // Left Hip
      side = "Left";
    } else {
      shoulder = landmarks[12];
      elbow = landmarks[14];
      wrist = landmarks[16];
      hip = landmarks[24]; // Right Hip
      side = "Right";
    }

    // Calculate Base Accuracy from Visibility Scores (Max 3.0)
    // We max this at 100% if visibility is good.
    // Average visibility of 3 key points.
    double currentScore = (side == "Left") ? leftScore : rightScore;
    accuracy = (currentScore / 3.0) * 100;
    if (accuracy > 100) accuracy = 100;

    // Safety Check: Border & Accuracy
    if (!_isSafe(shoulder) ||
        !_isSafe(elbow) ||
        !_isSafe(wrist) ||
        !_isSafe(hip)) {
      feedback = "Step Inside Frame / Body Unclear";
      isProperForm = false;
      accuracy = 0; // Penalize heavy for bad tracking
      return;
    }

    // Orientation Check: Must be Horizontal (Push-Up Position)
    // Vertical (Standing) is disallowed.
    if (!_isHorizontal(shoulder, hip)) {
      feedback = "Assume Push-Up Position";
      isProperForm = false;
      accuracy = 10; // Low score for wrong position
      return;
    }

    // Direction Check: Shoulders must be ABOVE Wrists (lower Y value)
    // Ensures user is pushing "down" (gravity) not pulling "down" or pushing "up"
    if (shoulder['y']! >= wrist['y']!) {
      feedback = "Hands Above Shoulders";
      isProperForm = false;
      accuracy = 30; // Medium penalty
      return;
    }

    // If we passed all checks, form is generally correct
    isProperForm = true;

    // 2. Calculate Elbow Angle
    final angle = calculateAngle(shoulder, elbow, wrist);

    // 3. State Machine (Push-Up)
    // Relaxed Thresholds: Down < 110, Up > 140

    if (angle > 140) {
      if (_isDown) {
        count++;
        _isDown = false; // Reset state
      }
      feedback = "UP";
    } else if (angle < 110) {
      _isDown = true;
      feedback = "DOWN";
    } else {
      feedback = "GO LOWER";
    }
  }

  bool _isSafe(Map<String, double> point) {
    // 1. Accuracy Check (> 50%)
    if (point['visibility']! < 0.5) return false;

    // 2. Border Check (5% Margin)
    // Coords are normalized 0.0 - 1.0
    double x = point['x']!;
    double y = point['y']!;

    if (x < 0.05 || x > 0.95) return false;
    if (y < 0.05 || y > 0.95) return false;

    return true;
  }

  bool _isHorizontal(Map<String, double> shoulder, Map<String, double> hip) {
    if (shoulder['visibility']! < 0.5 || hip['visibility']! < 0.5)
      return true; // Loose check if hidden

    double dx = (shoulder['x']! - hip['x']!).abs();
    double dy = (shoulder['y']! - hip['y']!).abs();

    // Horizontal if X-distance is greater than Y-distance
    return dx > dy;
  }

  double calculateAngle(
    Map<String, double> a,
    Map<String, double> b,
    Map<String, double> c,
  ) {
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
