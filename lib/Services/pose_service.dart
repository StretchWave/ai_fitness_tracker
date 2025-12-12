import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseService {
  late PoseDetector _poseDetector;

  PoseService() {
    final options = PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.base,
    );
    _poseDetector = PoseDetector(options: options);
  }

  Future<List<Pose>> processFrame(InputImage image) async {
    return await _poseDetector.processImage(image);
  }

  void dispose() {
    _poseDetector.close();
  }
}
