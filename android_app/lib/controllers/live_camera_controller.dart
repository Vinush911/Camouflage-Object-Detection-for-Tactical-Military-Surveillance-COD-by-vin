import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

import '../config/app_config.dart';
import '../data_models/detection_result.dart';
import '../services/cod_inference_service.dart';

enum LiveCameraStatus {
  uninitialized,
  permissionDenied,
  ready,
  streaming,
  error,
}

// Controller for live camera surveillance mode.
// Handles camera permissions, streaming camera frames,
// and throttling inferences so frames are not processed faster than the device can handle.
class LiveCameraController extends ChangeNotifier {
  final CodInferenceService inferenceService;

  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  LiveCameraStatus _status = LiveCameraStatus.uninitialized;
  String? _errorMessage;

  bool _isProcessingFrame = false;
  DateTime _lastInferenceTime = DateTime.now();
  DetectionResult? _currentResult;

  // Real-time metrics
  double _fps = 0.0;
  double _lastInferenceMs = 0.0;
  int _framesProcessed = 0;
  DateTime _fpsWindowStart = DateTime.now();

  LiveCameraController({required this.inferenceService});

  LiveCameraStatus get status => _status;
  CameraController? get cameraController => _cameraController;
  String? get errorMessage => _errorMessage;
  DetectionResult? get currentResult => _currentResult;
  double get fps => _fps;
  double get lastInferenceMs => _lastInferenceMs;
  bool get isStreaming => _status == LiveCameraStatus.streaming;

  // Initializes the camera after checking permissions
  Future<void> initializeCamera() async {
    _status = LiveCameraStatus.uninitialized;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Check Camera Permission
      final permissionStatus = await Permission.camera.request();
      if (permissionStatus.isDenied || permissionStatus.isPermanentlyDenied) {
        _status = LiveCameraStatus.permissionDenied;
        _errorMessage = 'Camera permission was denied. Please enable camera access in settings.';
        notifyListeners();
        return;
      }

      // 2. Discover available cameras on device
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        _status = LiveCameraStatus.error;
        _errorMessage = 'No available camera found on this device.';
        notifyListeners();
        return;
      }

      // Select back camera if available
      final backCamera = _availableCameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _availableCameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium, // Medium resolution (e.g. 720p) is optimal for mobile real-time
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      await inferenceService.initialize();

      _status = LiveCameraStatus.ready;
      notifyListeners();
    } catch (e) {
      _status = LiveCameraStatus.error;
      _errorMessage = 'Camera initialization failed: $e';
      notifyListeners();
    }
  }

  // Starts the real-time live detection loop
  Future<void> startStreaming() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (_status == LiveCameraStatus.streaming) return;

    _status = LiveCameraStatus.streaming;
    _fpsWindowStart = DateTime.now();
    _framesProcessed = 0;
    notifyListeners();

    // Minimum milliseconds between inferences to throttle FPS
    final throttleIntervalMs = (1000.0 / AppConfig.liveMaxInferenceFps).round();

    await _cameraController!.startImageStream((CameraImage cameraImage) async {
      final now = DateTime.now();

      // Rule: Do NOT process a new frame while another inference is still running.
      // Also obey throttle interval to save device battery and prevent lag.
      if (_isProcessingFrame) return;
      if (now.difference(_lastInferenceTime).inMilliseconds < throttleIntervalMs) {
        return;
      }

      _isProcessingFrame = true;
      _lastInferenceTime = now;

      try {
        // Convert YUV camera frame to RGB image
        final rgbImage = _convertYuv420ToImage(cameraImage);

        // Run inference
        final res = await inferenceService.runInference(rgbImage);
        _currentResult = res;
        _lastInferenceMs = res.inferenceMs;

        // Update FPS counter
        _framesProcessed++;
        final elapsedSec = DateTime.now().difference(_fpsWindowStart).inMilliseconds / 1000.0;
        if (elapsedSec >= 1.0) {
          _fps = _framesProcessed / elapsedSec;
          _framesProcessed = 0;
          _fpsWindowStart = DateTime.now();
        }

        notifyListeners();
      } catch (e) {
        debugPrint('[Live Camera] Frame inference error: $e');
      } finally {
        _isProcessingFrame = false;
      }
    });
  }

  // Stops the camera stream
  Future<void> stopStreaming() async {
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
    }
    _status = LiveCameraStatus.ready;
    notifyListeners();
  }

  // Helper method to convert Android YUV420 camera image into a standard Image object
  img.Image _convertYuv420ToImage(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final rgb = img.Image(width: width, height: height);

    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;

    final yRowStride = image.planes[0].bytesPerRow;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    for (var y = 0; y < height; y++) {
      final yOffset = y * yRowStride;
      final uvRow = (y >> 1) * uvRowStride;

      for (var x = 0; x < width; x++) {
        final uvCol = (x >> 1) * uvPixelStride;
        final yVal = yPlane[yOffset + x];
        final uVal = uPlane[uvRow + uvCol];
        final vVal = vPlane[uvRow + uvCol];

        // Standard YUV to RGB conversion formula
        var r = (yVal + 1.402 * (vVal - 128)).round().clamp(0, 255);
        var g = (yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128)).round().clamp(0, 255);
        var b = (yVal + 1.772 * (uVal - 128)).round().clamp(0, 255);

        rgb.setPixelRgb(x, y, r, g, b);
      }
    }

    return rgb;
  }

  @override
  void dispose() {
    stopStreaming();
    _cameraController?.dispose();
    super.dispose();
  }
}
