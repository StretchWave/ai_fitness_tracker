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
    formIssues.clear();
  }

  final Set<String> formIssues = {};

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
    // User Request: Don't decrease accuracy for body NOT seeing (visibility).
    // Only decrease for bad form.
    // So we don't calculate based on visibility score anymore.
    // accuracy = (currentScore / 3.0) * 100;
    // if (accuracy > 100) accuracy = 100;

    // Safety Checks
    if (exercise == 'Push-Ups' || exercise == 'Box Push-Ups') {
      // Handle both types
      if (!_isSafe(shoulder) ||
          !_isSafe(elbow) ||
          !_isSafe(wrist) ||
          !_isSafe(hip)) {
        feedback = "Body Unclear";
        formIssues.add("Body Not Visible");
        isProperForm = false;
        // accuracy = 0; // Don't penalize visibility
        return;
      }
      _processPushUp(
        shoulder,
        elbow,
        wrist,
        hip,
        knee,
        ankle,
        strictLegs: exercise == 'Push-Ups', // Strict only for standard
      );
    } else if (exercise == 'Squats') {
      if (!_isSafe(hip) || !_isSafe(knee) || !_isSafe(ankle)) {
        feedback = "Legs Unclear";
        formIssues.add("Legs Not Visible");
        isProperForm = false;
        // accuracy = 0; // Don't penalize visibility
        return;
      }
      _processSquat(shoulder, hip, knee, ankle);
    } else if (exercise == 'Sit-Ups') {
      if (!_isSafe(shoulder) || !_isSafe(hip) || !_isSafe(knee)) {
        feedback = "Body Unclear";
        formIssues.add("Body Not Visible");
        isProperForm = false;
        // accuracy = 0; // Don't penalize visibility
        return;
      }
      _processSitUp(shoulder, hip, knee);
    } else if (exercise == 'Pike Push-Ups') {
      if (!_isSafe(shoulder) ||
          !_isSafe(elbow) ||
          !_isSafe(wrist) ||
          !_isSafe(hip) ||
          !_isSafe(knee) ||
          !_isSafe(ankle)) {
        feedback = "Body Unclear";
        formIssues.add("Body Not Visible");
        isProperForm = false;
        return;
      }
      _processPikePushUp(shoulder, elbow, wrist, hip, knee, ankle);
    } else if (exercise == 'Chair Dips') {
      if (!_isSafe(shoulder) || !_isSafe(elbow) || !_isSafe(wrist)) {
        feedback = "Arm Unclear";
        formIssues.add("Arm Not Visible");
        isProperForm = false;
        return;
      }
      _processChairDip(shoulder, elbow, wrist, hip, knee, ankle);
    } else if (exercise == 'Floor Dips') {
      if (!_isSafe(shoulder) || !_isSafe(elbow) || !_isSafe(wrist)) {
        feedback = "Arm Unclear";
        formIssues.add("Arm Not Visible");
        isProperForm = false;
        return;
      }
      _processFloorDip(shoulder, elbow, wrist);
    } else if (exercise == 'Bird Dog') {
      if (!_isSafe(shoulder) ||
          !_isSafe(elbow) ||
          !_isSafe(wrist) ||
          !_isSafe(hip) ||
          !_isSafe(knee) ||
          !_isSafe(ankle)) {
        feedback = "Body Unclear";
        formIssues.add("Body Not Visible");
        isProperForm = false;
        return;
      }
      _processBirdDog(shoulder, elbow, wrist, hip, knee, ankle);
    } else if (exercise == 'Leg Raises') {
      if (!_isSafe(shoulder) ||
          !_isSafe(hip) ||
          !_isSafe(knee) ||
          !_isSafe(ankle)) {
        feedback = "Legs Unclear";
        formIssues.add("Legs Not Visible");
        isProperForm = false;
        return;
      }
      _processLegRaises(shoulder, hip, knee, ankle);
    }
  }

  void _processPushUp(
    Map<String, double> shoulder,
    Map<String, double> elbow,
    Map<String, double> wrist,
    Map<String, double> hip,
    Map<String, double> knee,
    Map<String, double> ankle, {
    bool strictLegs = true,
  }) {
    accuracy = 100; // Start with perfect form assumption

    // 0. Knee Check (prevent box push-ups)
    // Legs should be straight: Angle Hip-Knee-Ankle ~180
    final kneeAngle = calculateAngle(hip, knee, ankle);
    if (strictLegs) {
      if (kneeAngle < 150) {
        feedback = "Straighten Knees";
        isProperForm = false;
        accuracy = 10;
        return;
      }
    } else {
      // Box Push-Up Verification: Knees MUST be bent/on floor
      // If legs are too straight (> 160), they are likely doing a standard push-up or plank
      if (kneeAngle > 160) {
        feedback = "Bend Knees";
        // User request: verification like pushups. If wrong form, don't count.
        isProperForm = false;
        accuracy = 10;
        return;
      }
    }

    // 1. Hip Bend Check (Body Alignment)
    // Shoulder-Hip-Knee should be straight (~180)
    // Only check for strict forms (Standard Push-Up)
    if (strictLegs) {
      final hipAngle = calculateAngle(shoulder, hip, knee);
      if (hipAngle < 160) {
        // Allow slight pike/sag but not too much
        feedback = "Align Hips";
        formIssues.add("Hips Too Bent");
        accuracy = min(accuracy, 60); // Penalty
        // We don't return here, we allow counting but with penalty/feedback
      }
    }

    if (!_isHorizontal(shoulder, hip)) {
      feedback = "Assume Push-Up Position";
      formIssues.add("Incorrect Position");
      isProperForm = false;
      accuracy = 10;
      return;
    }
    if (shoulder['y']! >= wrist['y']!) {
      feedback = "Hands Above Shoulders";
      formIssues.add("Hands Misaligned");
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
    accuracy = 100; // Start with perfect form assumption

    // 1. Vertical Check (Standing)
    // Shoulder should be roughly above Hip (similar X)
    // Unlike pushups, we want X distance to be small relative to Y distance
    double dx = (shoulder['x']! - hip['x']!).abs();
    double dy = (shoulder['y']! - hip['y']!).abs();

    // If dx > dy, they are likely lying down
    if (dx > dy) {
      feedback = "Stand Up";
      formIssues.add("Improper Squat Form");
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
    accuracy = 100; // Start with perfect form assumption

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

  void _processPikePushUp(
    Map<String, double> shoulder,
    Map<String, double> elbow,
    Map<String, double> wrist,
    Map<String, double> hip,
    Map<String, double> knee,
    Map<String, double> ankle,
  ) {
    accuracy = 100;

    // 1. Knee Check (Legs should be straight)
    final kneeAngle = calculateAngle(hip, knee, ankle);
    if (kneeAngle < 150) {
      feedback = "Straighten Knees";
      formIssues.add("Bent Knees");
      isProperForm = false;
      accuracy = 10;
      return;
    }

    // 2. Hip Angle Check (Inverted V)
    // Shoulder-Hip-Knee angle should be SHARP (bent significantly)
    // Flat plank is ~180. Pike is < 120 approx.
    final hipAngle = calculateAngle(shoulder, hip, knee);
    if (hipAngle > 130) {
      feedback = "Raise Hips";
      formIssues.add("Hips Too Low");
      isProperForm = false;
      accuracy = 30;
      return;
    }

    isProperForm = true;

    // 3. Count Reps (Elbow Angle)
    final armAngle = calculateAngle(shoulder, elbow, wrist);
    if (armAngle > 140) {
      if (_isDown) {
        count++;
        _isDown = false;
      }
      feedback = "UP";
    } else if (armAngle < 100) {
      // Pike might need deeper bend, but 100 is safe start
      _isDown = true;
      feedback = "DOWN";
    } else {
      feedback = "GO LOWER";
    }
  }

  void _processChairDip(
    Map<String, double> shoulder,
    Map<String, double> elbow,
    Map<String, double> wrist,
    Map<String, double> hip,
    Map<String, double> knee,
    Map<String, double> ankle,
  ) {
    accuracy = 100;

    // 1. Elevation Check (Hands Higher Than Feet)
    // Wrist Y should be SMALLER (higher up) than Ankle Y.
    // If Wrist Y > Ankle Y, hands are below feet.
    // We add a conservative margin used before, maybe tweak it?
    // User asked to "try again" with this check. Let's make it simple.
    // Wrist must be higher (smaller Y) than Ankle - 0.05.
    if (wrist['y']! > ankle['y']! - 0.05) {
      feedback = "Use a Chair";
      formIssues.add("Not Elevated");
      isProperForm = false;
      accuracy = 10;
      return;
    }

    isProperForm = true;

    final angle = calculateAngle(shoulder, elbow, wrist);

    // Dips:
    // UP: Arms straight (> 160)
    // DOWN: Arms bent (< 100)

    if (angle > 160) {
      if (_isDown) {
        count++;
        _isDown = false;
      }
      feedback = "UP";
    } else if (angle < 100) {
      _isDown = true;
      feedback = "DOWN";
    } else {
      feedback = "GO LOWER";
    }
  }

  void _processFloorDip(
    Map<String, double> shoulder,
    Map<String, double> elbow,
    Map<String, double> wrist,
  ) {
    // Floor Dip: No elevation check needed.
    accuracy = 100;
    isProperForm = true;

    final angle = calculateAngle(shoulder, elbow, wrist);

    if (angle > 160) {
      if (_isDown) {
        count++;
        _isDown = false;
      }
      feedback = "UP";
    } else if (angle < 110) {
      // Floor dips might have less range
      _isDown = true;
      feedback = "DOWN";
    } else {
      feedback = "GO LOWER";
    }
  }

  void _processBirdDog(
    Map<String, double> shoulder,
    Map<String, double> elbow,
    Map<String, double> wrist,
    Map<String, double> hip,
    Map<String, double> knee,
    Map<String, double> ankle,
  ) {
    accuracy = 100;
    isProperForm = true;

    // Angles
    final legAngle = calculateAngle(hip, knee, ankle);
    final armAngle = calculateAngle(shoulder, elbow, wrist);

    // Height Checks (Y coordinate: 0 is top, 1 is bottom)
    // Lifted means Y should be SMALLER (higher up).
    // Leg Lifted: Ankle Y should be close to Hip Y or higher.
    // Arm Lifted: Wrist Y should be close to Shoulder Y or higher.
    // We add a buffer (0.15 represents ~15% of screen height) to be forgiving.
    bool isLegLifted = ankle['y']! < hip['y']! + 0.15;
    bool isLegStraight = legAngle > 150;

    bool isArmLifted = wrist['y']! < shoulder['y']! + 0.15;
    bool isArmStraight = armAngle > 150;

    // Check for "Extended" state
    if (isLegStraight && isLegLifted && isArmStraight && isArmLifted) {
      if (_isDown) {
        count++;
        _isDown = false;
      }
      feedback = "HOLD";
    }
    // Check for "Start" state (All fours / Reset)
    // Knee bent (< 120) is a good proxy for returning to start.
    // Or if limbs drop significantly.
    else if (legAngle < 120 || !isLegLifted) {
      _isDown = true;
      feedback = "EXTEND";
    } else {
      feedback = "EXTEND";
    }
  }

  void _processLegRaises(
    Map<String, double> shoulder,
    Map<String, double> hip,
    Map<String, double> knee,
    Map<String, double> ankle,
  ) {
    accuracy = 100;

    // 1. Straight Legs Check
    final kneeAngle = calculateAngle(hip, knee, ankle);
    if (kneeAngle < 140) {
      feedback = "Straighten Legs";
      formIssues.add("Bent Knees");
      isProperForm = false;
      return;
    }

    isProperForm = true;

    // 2. Hip Angle (Shoulder - Hip - Knee)
    // Lying flat: ~180 degrees
    // Legs Up: < 90 degrees (vertical)
    final hipAngle = calculateAngle(shoulder, hip, knee);

    // Thresholds
    // UP: < 110 (Legs raised high enough)
    // DOWN: > 150 (Legs lowered)

    if (hipAngle < 110) {
      if (_isDown) {
        count++;
        _isDown = false;
      }
      feedback = "LOWER";
    } else if (hipAngle > 150) {
      _isDown = true;
      feedback = "LIFT";
    } else {
      feedback = _isDown ? "LIFT" : "LOWER";
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
