import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseDetectionService {
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );

  Future<List<Pose>> processCameraImage(
    CameraImage image,
    CameraDescription description,
  ) async {
    final inputImage = _inputImageFromCameraImage(image, description);
    if (inputImage == null) return [];
    return await _poseDetector.processImage(inputImage);
  }

  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraDescription description,
  ) {
    final sensorOrientation = description.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      // In a real app we might need to look at device orientation, but here we just use what we had
      // The original code calculated rotation based on sensorOrientation.
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    }

    // Fallback or better logic: use the helper we had in the original file
    // To match the original logic exactly:
    rotation = _rotationIntToImageRotation(sensorOrientation);

    final format =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;

    // The google_mlkit_commons version used here expects a single
    // InputImageMetadata (not a list of plane metadata). Use the first
    // plane's bytesPerRow as the row stride.
    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.isNotEmpty ? image.planes[0].bytesPerRow : 0,
    );

    final totalLength = image.planes.fold<int>(
      0,
      (sum, p) => sum + p.bytes.length,
    );
    final bytes = Uint8List(totalLength);
    int offset = 0;
    for (final plane in image.planes) {
      bytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }
    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  InputImageRotation _rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      case 0:
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Future<void> close() async {
    await _poseDetector.close();
  }
}
