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

  void processLandmarks(List<Map<String, double>> landmarks, String exercise) {
    if (landmarks.length < 33) return;

    // Detect Best Side
    double leftScore =
        landmarks[11]['visibility']! +
        landmarks[13]['visibility']! +
        landmarks[15]['visibility']!;
    double rightScore =
        landmarks[12]['visibility']! +
        landmarks[14]['visibility']! +
        landmarks[16]['visibility']!;

    // For Squats, we care about legs: Hip(23/24), Knee(25/26), Ankle(27/28)
    if (exercise == 'Squats') {
      leftScore =
          landmarks[23]['visibility']! +
          landmarks[25]['visibility']! +
          landmarks[27]['visibility']!;
      rightScore =
          landmarks[24]['visibility']! +
          landmarks[26]['visibility']! +
          landmarks[28]['visibility']!;
    }

    String side = leftScore > rightScore ? "Left" : "Right";

    // Common Points
    // Map<String, double> nose = landmarks[0];

    // Push-Up Points
    Map<String, double> shoulder = side == "Left"
        ? landmarks[11]
        : landmarks[12];
    Map<String, double> elbow = side == "Left" ? landmarks[13] : landmarks[14];
    Map<String, double> wrist = side == "Left" ? landmarks[15] : landmarks[16];

    // Squat Points
    Map<String, double> hip = side == "Left" ? landmarks[23] : landmarks[24];
    Map<String, double> knee = side == "Left" ? landmarks[25] : landmarks[26];
    Map<String, double> ankle = side == "Left" ? landmarks[27] : landmarks[28];

    // Calculate Accuracy based on relevant points
    double currentScore = (side == "Left") ? leftScore : rightScore;
    accuracy = (currentScore / 3.0) * 100;
    if (accuracy > 100) accuracy = 100;

    // Safety Checks
    if (exercise == 'Push-Ups') {
      if (!_isSafe(shoulder) ||
          !_isSafe(elbow) ||
          !_isSafe(wrist) ||
          !_isSafe(hip)) {
        feedback = "Body Unclear";
        isProperForm = false;
        accuracy = 0;
        return;
      }
      _processPushUp(shoulder, elbow, wrist, hip);
    } else if (exercise == 'Squats') {
      if (!_isSafe(hip) || !_isSafe(knee) || !_isSafe(ankle)) {
        feedback = "Legs Unclear";
        isProperForm = false;
        accuracy = 0;
        return;
      }
      _processSquat(shoulder, hip, knee, ankle);
    } else if (exercise == 'Sit-Ups') {
      if (!_isSafe(shoulder) || !_isSafe(hip) || !_isSafe(knee)) {
        feedback = "Body Unclear";
        isProperForm = false;
        accuracy = 0;
        return;
      }
      _processSitUp(shoulder, hip, knee);
    }
  }

  void _processPushUp(
    Map<String, double> shoulder,
    Map<String, double> elbow,
    Map<String, double> wrist,
    Map<String, double> hip,
  ) {
    if (!_isHorizontal(shoulder, hip)) {
      feedback = "Assume Push-Up Position";
      isProperForm = false;
      accuracy = 10;
      return;
    }
    if (shoulder['y']! >= wrist['y']!) {
      feedback = "Hands Above Shoulders";
      isProperForm = false;
      accuracy = 30;
      return;
    }

    isProperForm = true;
    final angle = calculateAngle(shoulder, elbow, wrist);

    if (angle > 140) {
      if (_isDown) {
        count++;
        _isDown = false;
      }
      feedback = "UP";
    } else if (angle < 110) {
      _isDown = true;
      feedback = "DOWN";
    } else {
      feedback = "GO LOWER";
    }
  }

  void _processSquat(
    Map<String, double> shoulder,
    Map<String, double> hip,
    Map<String, double> knee,
    Map<String, double> ankle,
  ) {
    // 1. Vertical Check (Standing)
    // Shoulder should be roughly above Hip (similar X)
    // Unlike pushups, we want X distance to be small relative to Y distance
    double dx = (shoulder['x']! - hip['x']!).abs();
    double dy = (shoulder['y']! - hip['y']!).abs();

    // If dx > dy, they are likely lying down
    if (dx > dy) {
      feedback = "Stand Up";
      isProperForm = false;
      accuracy = 10;
      return;
    }

    isProperForm = true;

    // 2. Calculate Knee Angle (Hip-Knee-Ankle)
    final angle = calculateAngle(hip, knee, ankle);

    // 3. State Machine
    // Standing (Up): ~170-180
    // Squat (Down): < 90 (or < 100 for beginner)

    if (angle > 160) {
      if (_isDown) {
        count++;
        _isDown = false;
      }
      feedback = "STAND";
    } else if (angle < 100) {
      _isDown = true;
      feedback = "HOLD";
    } else {
      feedback = "GO LOWER";
    }
  }

  void _processSitUp(
    Map<String, double> shoulder,
    Map<String, double> hip,
    Map<String, double> knee,
  ) {
    // 1. Horizontal Check (Lying Down Context)
    // Unlike squats, we expect significant horizontal displacement when down, but less when up.
    // But mainly we track the angle at the Hip (Shoulder - Hip - Knee)

    // Safety: Ensure we aren't standing (Hip Y should be close to Knee Y or below)
    // Actually in situp, Hip Y and Knee Y are close (on floor). Shoulder Y changes.

    isProperForm = true;

    // 2. Calculate Hip Angle (Shoulder-Hip-Knee)
    // Lying down: ~180 degrees
    // Sitting up: ~45-90 degrees
    final angle = calculateAngle(shoulder, hip, knee);

    // 3. State Machine
    // Down (Lying): > 125
    // Up (Sitting): < 50

    // Relaxed Thresholds for "User Friendly" sit-up
    // Down (Lying): > 110 (Easier to register start)
    // Up (Sitting): < 80 (Don't need to bend fully forward)

    if (angle > 110) {
      _isDown = true; // Ready at bottom
      feedback = "UP";
    } else if (angle < 80) {
      if (_isDown) {
        count++;
        _isDown = false;
      }
      feedback = "DOWN";
    } else {
      feedback = "KEEP GOING";
    }
  }

  bool _isSafe(Map<String, double> point) {
    if (point['visibility']! < 0.5) return false;
    double x = point['x']!;
    double y = point['y']!;
    if (x < 0.05 || x > 0.95) return false;
    if (y < 0.05 || y > 0.95) return false;
    return true;
  }

  bool _isHorizontal(Map<String, double> shoulder, Map<String, double> hip) {
    if (shoulder['visibility']! < 0.5 || hip['visibility']! < 0.5) return true;
    double dx = (shoulder['x']! - hip['x']!).abs();
    double dy = (shoulder['y']! - hip['y']!).abs();
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
