import 'dart:async';
import 'package:flutter/services.dart';

class PoseBridge {
  static const EventChannel _channel = EventChannel('com.workout/pose_stream');

  Stream<List<Map<String, double>>> get poseStream {
    return _channel.receiveBroadcastStream().map((event) {
      try {
        final List<dynamic> flatList = event;
        final int pointCount = flatList.length ~/ 4;
        final List<Map<String, double>> mapped = [];

        for (int i = 0; i < pointCount; i++) {
          mapped.add({
            'x': (flatList[i * 4] as num).toDouble(),
            'y': (flatList[i * 4 + 1] as num).toDouble(),
            'z': (flatList[i * 4 + 2] as num).toDouble(),
            'visibility': (flatList[i * 4 + 3] as num).toDouble(),
          });
        }

        return mapped;
      } catch (e) {
        return [];
      }
    });
  }
}
