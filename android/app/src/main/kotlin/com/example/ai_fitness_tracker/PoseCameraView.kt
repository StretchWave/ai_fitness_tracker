package com.example.ai_fitness_tracker

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.util.Log
import android.view.View
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.platform.PlatformView
import java.util.concurrent.Executors

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger

class PoseCameraView(
    private val context: Context,
    binaryMessenger: BinaryMessenger,
    private val eventSinkProvider: () -> EventChannel.EventSink?,
    private val lifecycleOwner: LifecycleOwner
) : PlatformView, MethodChannel.MethodCallHandler {

    private val previewView: PreviewView = PreviewView(context).apply {
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
    }

    private val backgroundExecutor = Executors.newSingleThreadExecutor()
    private val methodChannel = MethodChannel(binaryMessenger, "com.workout/pose_camera_control")
    private var currentCameraSelector = CameraSelector.DEFAULT_FRONT_CAMERA
    
    // Optimization: Reuse Bitmap to avoid GC churn
    private var bitmapBuffer: Bitmap? = null

    init {
        methodChannel.setMethodCallHandler(this)
        
        // 1. Attach to Shared Manager
        MediaPipeManager.attachListener(this::returnLivestreamResult)
        
        // 2. Ensure loaded (Double check)
        MediaPipeManager.preload(context)

        // 3. Start Camera
        startCamera()
    }

    override fun getView(): View {
        return previewView
    }

    override fun dispose() {
        methodChannel.setMethodCallHandler(null)
        backgroundExecutor.shutdown()
        
        // Detach, but DO NOT close the singleton model
        MediaPipeManager.detachListener()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "switchCamera") {
            toggleCamera()
            result.success(null)
        } else {
            result.notImplemented()
        }
    }

    private fun toggleCamera() {
        currentCameraSelector = if (currentCameraSelector == CameraSelector.DEFAULT_FRONT_CAMERA) {
            CameraSelector.DEFAULT_BACK_CAMERA
        } else {
            CameraSelector.DEFAULT_FRONT_CAMERA
        }
        startCamera()
    }


    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)

        cameraProviderFuture.addListener({
            val cameraProvider: ProcessCameraProvider = cameraProviderFuture.get()

            val preview = Preview.Builder().build().also {
                it.setSurfaceProvider(previewView.surfaceProvider)
            }

            val imageAnalysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setTargetResolution(android.util.Size(480, 640)) // Lower resolution for higher FPS
                .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                .build()

            imageAnalysis.setAnalyzer(backgroundExecutor) { imageProxy ->
                processImageProxy(imageProxy)
            }

            try {
                cameraProvider.unbindAll()
                cameraProvider.bindToLifecycle(
                    lifecycleOwner,
                    currentCameraSelector,
                    preview,
                    imageAnalysis
                )
            } catch (exc: Exception) {
                Log.e("PoseCameraView", "Use case binding failed", exc)
            }

        }, ContextCompat.getMainExecutor(context))
    }

    private fun processImageProxy(imageProxy: ImageProxy) {
        val landmarker = MediaPipeManager.poseLandmarker
        if (landmarker == null) {
            imageProxy.close()
            return
        }

        val frameTime = System.currentTimeMillis()
        
        // Optimization: Use the lower resolution bitmap directly & Reuse Buffer
        // Rotate bitmap
        
        if (bitmapBuffer == null || bitmapBuffer?.width != imageProxy.width || bitmapBuffer?.height != imageProxy.height) {
            bitmapBuffer = Bitmap.createBitmap(
                imageProxy.width,
                imageProxy.height,
                Bitmap.Config.ARGB_8888
            )
        }
        
        bitmapBuffer?.copyPixelsFromBuffer(imageProxy.planes[0].buffer)
        
        val matrix = Matrix()
        matrix.postRotate(imageProxy.imageInfo.rotationDegrees.toFloat())
        
        // We still need a new bitmap for rotation unfortunately unless we handle rotation in MediaPipe options
        // or use a different Image object type. For now, let's keep the rotation bitmap as is but we saved one allocation above.
        // Actually, we can try to improve this further later.
        
        val rotatedBitmap = Bitmap.createBitmap(
            bitmapBuffer!!, 0, 0, bitmapBuffer!!.width, bitmapBuffer!!.height, matrix, true
        )

        val mpImage = BitmapImageBuilder(rotatedBitmap).build()

        landmarker.detectAsync(mpImage, frameTime)
        
        imageProxy.close()
    }

    private fun returnLivestreamResult(
        result: PoseLandmarkerResult,
        input: MPImage
    ) {
        // Optimization: Send FLAT ARRAY of Doubles instead of Map
        val flatList = ArrayList<Double>()

        if (result.landmarks().isNotEmpty()) {
            // Extract first person detected
            val landmarks = result.landmarks()[0]
            val isFrontCamera = currentCameraSelector == CameraSelector.DEFAULT_FRONT_CAMERA

            for (landmark in landmarks) {
                // Conditional Mirroring
                if (isFrontCamera) {
                    flatList.add(1.0 - landmark.x().toDouble())
                } else {
                    flatList.add(landmark.x().toDouble())
                }
                flatList.add(landmark.y().toDouble())
                flatList.add(landmark.z().toDouble())
                flatList.add(landmark.visibility().orElse(0.0f).toDouble())
            }
        }

        // Send to Flutter on Main Thread (Even if empty)
        ContextCompat.getMainExecutor(context).execute {
            eventSinkProvider()?.success(flatList)
        }
    }
}
