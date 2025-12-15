package com.example.ai_fitness_tracker

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL_NAME = "com.workout/pose_stream"
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Setup EventChannel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    android.util.Log.d("PoseStream", "EventChannel onListen called")
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    android.util.Log.d("PoseStream", "EventChannel onCancel called")
                    eventSink = null
                }
            }
        )

        // 2. Register PlatformView
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "pose-camera-view",
                PoseCameraViewFactory(flutterEngine.dartExecutor.binaryMessenger, this) { eventSink }
            )
    }
}
