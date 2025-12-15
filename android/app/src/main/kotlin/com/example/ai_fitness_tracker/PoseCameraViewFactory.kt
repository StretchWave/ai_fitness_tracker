package com.example.ai_fitness_tracker

import android.content.Context
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

import io.flutter.plugin.common.BinaryMessenger

class PoseCameraViewFactory(
    private val binaryMessenger: BinaryMessenger,
    private val lifecycleOwner: LifecycleOwner,
    private val eventSinkReceiver: () -> EventChannel.EventSink?
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return PoseCameraView(context, binaryMessenger, eventSinkReceiver, lifecycleOwner)
    }
}
