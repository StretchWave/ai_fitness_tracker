package com.example.ai_fitness_tracker

import android.content.Context
import android.util.Log
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import java.util.concurrent.Executors

object MediaPipeManager {
    var poseLandmarker: PoseLandmarker? = null
        private set

    private var activeListener: ((PoseLandmarkerResult, MPImage) -> Unit)? = null
    private val backgroundExecutor = Executors.newSingleThreadExecutor()
    private var isInitializing = false
    private val pendingCallbacks = mutableListOf<(Boolean) -> Unit>()

    fun preload(context: Context, callback: ((Boolean) -> Unit)? = null) {
        if (poseLandmarker != null) {
            callback?.invoke(true)
            return
        }

        synchronized(this) {
            if (callback != null) {
                pendingCallbacks.add(callback)
            }
            if (isInitializing) return
            isInitializing = true
        }

        backgroundExecutor.execute {
            setupMediaPipe(context.applicationContext)
            
            synchronized(this) {
                isInitializing = false
                val success = poseLandmarker != null
                pendingCallbacks.forEach { it.invoke(success) }
                pendingCallbacks.clear()
            }
        }
    }

    fun attachListener(listener: (PoseLandmarkerResult, MPImage) -> Unit) {
        activeListener = listener
    }

    fun detachListener() {
        activeListener = null
    }

    private fun setupMediaPipe(context: Context) {
        try {
            val baseOptionsGpu = BaseOptions.builder()
                .setModelAssetPath("pose_landmarker_heavy.task")
                .setDelegate(com.google.mediapipe.tasks.core.Delegate.GPU)
                .build()

            val optionsGpu = PoseLandmarker.PoseLandmarkerOptions.builder()
                .setBaseOptions(baseOptionsGpu)
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setResultListener { result, input ->
                    activeListener?.invoke(result, input)
                }
                .setErrorListener { error: RuntimeException ->
                    Log.e("MediaPipeManager", "GPU Error: ${error.message}")
                }
                .build()

            poseLandmarker = PoseLandmarker.createFromOptions(context, optionsGpu)
            Log.d("MediaPipeManager", "MediaPipe initialized (GPU)")
            return
        } catch (e: Exception) {
             Log.e("MediaPipeManager", "GPU Initialization failed. Falling back to CPU.", e)
        }

        // CPU Fallback
        try {
            val baseOptionsCpu = BaseOptions.builder()
                .setModelAssetPath("pose_landmarker_heavy.task")
                .setDelegate(com.google.mediapipe.tasks.core.Delegate.CPU)
                .build()

            val optionsCpu = PoseLandmarker.PoseLandmarkerOptions.builder()
                .setBaseOptions(baseOptionsCpu)
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setResultListener { result, input ->
                    activeListener?.invoke(result, input)
                }
                .setErrorListener { error: RuntimeException ->
                    Log.e("MediaPipeManager", "CPU Error: ${error.message}")
                }
                .build()

            poseLandmarker = PoseLandmarker.createFromOptions(context, optionsCpu)
            Log.d("MediaPipeManager", "MediaPipe initialized (CPU)")
        } catch (e: Exception) {
            Log.e("MediaPipeManager", "Error initializing MediaPipe (CPU): ${e.message}")
        }
    }
}
