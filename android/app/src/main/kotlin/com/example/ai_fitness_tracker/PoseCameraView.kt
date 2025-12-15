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

    private var poseLandmarker: PoseLandmarker? = null
    private val backgroundExecutor = Executors.newSingleThreadExecutor()
    private val methodChannel = MethodChannel(binaryMessenger, "com.workout/pose_camera_control")
    private var currentCameraSelector = CameraSelector.DEFAULT_FRONT_CAMERA

    init {
        methodChannel.setMethodCallHandler(this)
        setupMediaPipe()
        startCamera()
    }

    override fun getView(): View {
        return previewView
    }

    override fun dispose() {
        methodChannel.setMethodCallHandler(null)
        backgroundExecutor.shutdown()
        poseLandmarker?.close()
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

    private fun setupMediaPipe() {
        // Try initializing with GPU first
        try {
            val baseOptionsGpu = BaseOptions.builder()
                .setModelAssetPath("pose_landmarker_heavy.task")
                .setDelegate(com.google.mediapipe.tasks.core.Delegate.GPU)
                .build()
            
            val optionsGpu = PoseLandmarker.PoseLandmarkerOptions.builder()
                .setBaseOptions(baseOptionsGpu)
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setResultListener(this::returnLivestreamResult)
                .setErrorListener { error: RuntimeException ->
                    Log.e("PoseCameraView", "MediaPipe GPU Error: ${error.message}")
                }
                .build()

            poseLandmarker = PoseLandmarker.createFromOptions(context, optionsGpu)
            Log.d("PoseCameraView", "MediaPipe initialized with GPU delegate")
            return
        } catch (e: Exception) {
            Log.e("PoseCameraView", "GPU Initialization failed: ${e.message}. Falling back to CPU.")
        }

        // Fallback to CPU
        try {
            val baseOptionsCpu = BaseOptions.builder()
                .setModelAssetPath("pose_landmarker_heavy.task")
                .setDelegate(com.google.mediapipe.tasks.core.Delegate.CPU)
                .build()

            val optionsCpu = PoseLandmarker.PoseLandmarkerOptions.builder()
                .setBaseOptions(baseOptionsCpu)
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setResultListener(this::returnLivestreamResult)
                .setErrorListener { error: RuntimeException ->
                    Log.e("PoseCameraView", "MediaPipe CPU Error: ${error.message}")
                }
                .build()

            poseLandmarker = PoseLandmarker.createFromOptions(context, optionsCpu)
             Log.d("PoseCameraView", "MediaPipe initialized with CPU delegate")
        } catch (e: Exception) {
            Log.e("PoseCameraView", "Error creating PoseLandmarker (CPU): ${e.message}")
        }
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
        if (poseLandmarker == null) {
            imageProxy.close()
            return
        }

        val frameTime = System.currentTimeMillis()
        
        // Optimization: Use the lower resolution bitmap directly
        val bitmapBuffer = Bitmap.createBitmap(
            imageProxy.width,
            imageProxy.height,
            Bitmap.Config.ARGB_8888
        )
        bitmapBuffer.copyPixelsFromBuffer(imageProxy.planes[0].buffer)
        
        val matrix = Matrix()
        matrix.postRotate(imageProxy.imageInfo.rotationDegrees.toFloat())
        
        // REMOVED: Unconditional mirroring. MediaPipe should see the "Real" image (unflipped).
        // matrix.postScale(-1f, 1f, imageProxy.width / 2f, imageProxy.height / 2f)

        val rotatedBitmap = Bitmap.createBitmap(
            bitmapBuffer, 0, 0, bitmapBuffer.width, bitmapBuffer.height, matrix, true
        )

        val mpImage = BitmapImageBuilder(rotatedBitmap).build()

        poseLandmarker?.detectAsync(mpImage, frameTime)
        
        // Important: Close the imageProxy after processing is dispatched
        // Note: detectAsync copies data effectively so we can close proxy after building MPImage?
        // Actually MPImage might hold reference. Safe to close after detectAsync returns? 
        // MediaPipe docs say: "The app should close the imageProxy after the image is processed"
        // Since we created a Bitmap copy, we can close imageProxy immediately.
        imageProxy.close()
    }

    private fun returnLivestreamResult(
        result: PoseLandmarkerResult,
        input: MPImage
    ) {
        if (result.landmarks().isEmpty()) return

        // Extract first person detected
        val landmarks = result.landmarks()[0]
        // Log.d("PoseStream", "Native: Detected ${landmarks.size} landmarks")

        // Optimization: Send FLAT ARRAY of Doubles instead of Map
        // Format: [x0, y0, z0, v0, x1, y1, z1, v1, ...]
        val flatList = ArrayList<Double>(landmarks.size * 4)
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
            flatList.add(1.0) // Visibility fixed to 1.0 for now
        }

        // Send to Flutter on Main Thread
        ContextCompat.getMainExecutor(context).execute {
            eventSinkProvider()?.success(flatList)
        }
    }
}
