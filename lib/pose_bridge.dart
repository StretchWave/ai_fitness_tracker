import 'dart:async';
import 'package:flutter/services.dart';

class PoseBridge {
  static const EventChannel _channel = EventChannel('com.workout/pose_stream');

  Stream<List<Map<String, double>>> get poseStream {
    return _channel.receiveBroadcastStream().map((event) {
      try {
        final List<dynamic> list = event;
        // ignore: avoid_print
        print("Flutter Bridge: Received ${list.length} landmarks");

        final mapped = list.map((e) {
          final Map<dynamic, dynamic> map = e;
          return map.map(
            (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
          );
        }).toList();

        return mapped;
      } catch (e) {
        // debugPrint requires 'package:flutter/foundation.dart';
        // Adding it here to avoid compilation errors if not already imported.
        // If you don't want this import, please remove it and ensure debugPrint is available.
        // ignore: avoid_print
        print(
          "Flutter Bridge Error: $e",
        ); // Using print as a fallback for debugPrint
        return [];
      }
    });
  }
}
