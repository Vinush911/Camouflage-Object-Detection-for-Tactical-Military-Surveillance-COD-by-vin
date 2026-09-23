import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/constants/app_constants.dart';
import '../detection/target_tracker.dart';
import '../model/model_registry.dart';
import '../models/detection_result.dart';
import '../models/tracked_target.dart';
import '../services/cod_pipeline_service.dart';
import '../services/tactical_alert_service.dart';
import '../utils/app_memory_utils.dart';

enum LiveCameraStatus {
  uninitialized,
  initializing,
  ready,
  permissionDenied,
  error,
}

// Controller managing the camera feed, real-time camouflage detection,
// frame dropping so the screen doesn't lag, and tracking speed (FPS) and memory (RAM).

class LiveInferenceController extends ChangeNotifier {
  final CodPipelineService _pipeline;
  final ModelRegistry _registry = ModelRegistry();
  final TargetTracker _tracker = TargetTracker();
  final TacticalAlertService _alertService = TacticalAlertService();

  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];

  LiveCameraStatus _status = LiveCameraStatus.uninitialized;
  String? _errorMessage;

  bool _isStreaming = false;
  bool _isProcessingFrame = false;

  // Real-time Detection Outputs
  DetectionResult? _currentResult;
  List<TrackedTarget> _trackedTargets = [];
  int _frameWidth = 0;
  int _frameHeight = 0;

  // Real-time Performance Metrics
  double _lastInferenceMs = 0.0;
  double _fps = 0.0;
  int _ramUsageMb = 0;

  // Frame counter to calculate frames per second (FPS)
  int _frameCount = 0;
  DateTime _lastFpsTimestamp = DateTime.now();

  // Interactive Live Controls
  double _confidenceThreshold = AppConstants.defaultThreshold;
  int _cpuThreads = 4;

  // Model input dimensions
  int _targetWidth = 384;
  int _targetHeight = 384;

  // Pre-allocated memory buffers to reuse on every frame.
  // Reusing these buffers prevents the app from creating new objects constantly,
  // which stops lag and keeps memory usage low.
  late Float32List _inputTensorBuffer;
  late Float32List _outputTensorBuffer;
  late Uint8List _binaryMaskBuffer;
  late Float32List _probabilityMaskBuffer;
  late Uint8List _visitedBuffer;
  late Int32List _scratchQueue;

  // Quick lookup tables for fast coordinate mapping between camera and model
  late Int32List _camXTable;
  late Int32List _camYTable;
  int _cachedCameraWidth = 0;
  int _cachedCameraHeight = 0;

  LiveInferenceController({CodPipelineService? pipeline})
      : _pipeline = pipeline ?? CodPipelineService() {
    // Read model input size from configuration if loaded, or use 384x384 default
    final dgnetWidth = _registry.dgnetPackage?.config.inputWidth ?? 384;
    final dgnetHeight = _registry.dgnetPackage?.config.inputHeight ?? 384;
    _initializeMemoryBuffers(dgnetWidth, dgnetHeight);
    _ramUsageMb = AppMemoryUtils.getCurrentRssMb();
  }

  CameraController? get cameraController => _cameraController;
  LiveCameraStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isStreaming => _isStreaming;
  DetectionResult? get currentResult => _currentResult;
  List<TrackedTarget> get trackedTargets => _trackedTargets;
  int get frameWidth => _frameWidth;
  int get frameHeight => _frameHeight;

  double get lastInferenceMs => _lastInferenceMs;
  double get fps => _fps;
  int get ramUsageMb => _ramUsageMb;
  bool get isAudioMuted => _alertService.isAudioMuted;

  double get confidenceThreshold => _confidenceThreshold;
  int get cpuThreads => _cpuThreads;

  // Sets up reusable memory buffers once so we never re-allocate them while running
  void _initializeMemoryBuffers(int width, int height) {
    _targetWidth = width;
    _targetHeight = height;
    final totalPixels = width * height;

    _inputTensorBuffer = Float32List(totalPixels * 3);
    _outputTensorBuffer = Float32List(totalPixels);
    _binaryMaskBuffer = Uint8List(totalPixels);
    _probabilityMaskBuffer = Float32List(totalPixels);
    _visitedBuffer = Uint8List(totalPixels);
    _scratchQueue = Int32List(totalPixels);

    _camXTable = Int32List(height);
    _camYTable = Int32List(width);
    _cachedCameraWidth = 0;
    _cachedCameraHeight = 0;
  }

  // Initializes the camera sensor and asks for camera permission
  Future<void> initializeCamera() async {
    _status = LiveCameraStatus.initializing;
    _errorMessage = null;
    notifyListeners();

    final permissionStatus = await Permission.camera.request();
    if (!permissionStatus.isGranted) {
      _status = LiveCameraStatus.permissionDenied;
      _errorMessage =
          'Camera permission was denied. Please grant camera access in settings.';
      notifyListeners();
      return;
    }

    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        _status = LiveCameraStatus.error;
        _errorMessage = 'No camera sensors were found on this device.';
        notifyListeners();
        return;
      }

      // Default to the back-facing camera
      final backCamera = _availableCameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _availableCameras.first,
      );

      // Using ResolutionPreset.low for live video makes frame processing fast,
      // matches model input resolution closely, and saves battery and memory.
      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      _status = LiveCameraStatus.ready;
      _ramUsageMb = AppMemoryUtils.getCurrentRssMb();
      notifyListeners();

      // Automatically start live surveillance stream once camera is ready
      await startStreaming();
    } catch (e) {
      _status = LiveCameraStatus.error;
      _errorMessage = 'Failed to initialize camera: $e';
      notifyListeners();
    }
  }

  // Starts the camera stream
  Future<void> startStreaming() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _isStreaming = true;
    _frameCount = 0;
    _lastFpsTimestamp = DateTime.now();
    notifyListeners();

    try {
      await _cameraController!.startImageStream((CameraImage image) {
        _handleCameraFrame(image);
      });
    } catch (e) {
      debugPrint('[LiveInference] Error starting camera stream: $e');
    }
  }

  // Stops the camera stream
  Future<void> stopStreaming() async {
    _isStreaming = false;
    _tracker.reset();
    _alertService.reset();
    _trackedTargets = [];
    if (_cameraController != null &&
        _cameraController!.value.isStreamingImages) {
      try {
        await _cameraController!.stopImageStream();
      } catch (e) {
        debugPrint('[LiveInference] Error stopping camera stream: $e');
      }
    }
    notifyListeners();
  }

  // Processes each incoming frame using the "keep only latest" pattern.
  // If the model is busy processing a frame, new frames are dropped immediately so the feed stays live.
  void _handleCameraFrame(CameraImage cameraImage) async {
    if (!_isStreaming || _isProcessingFrame) {
      return;
    }

    _isProcessingFrame = true;

    try {
      final preprocessWatch = Stopwatch()..start();

      // On Android phones in portrait mode, the camera sensor is turned 90 degrees.
      // So the screen width is the camera height, and the screen height is the camera width.
      _frameWidth = cameraImage.height;
      _frameHeight = cameraImage.width;

      // Ensure our memory buffers match the active model's input size
      final expectedWidth = _registry.dgnetPackage?.config.inputWidth ?? 384;
      final expectedHeight = _registry.dgnetPackage?.config.inputHeight ?? 384;
      if (_targetWidth != expectedWidth || _targetHeight != expectedHeight) {
        _initializeMemoryBuffers(expectedWidth, expectedHeight);
      }

      // Convert and resize camera pixels directly into our reusable model input buffer in a single pass.
      // This avoids allocating any temporary image objects in memory.
      _sampleCameraPlanesToInputBuffer(cameraImage);
      preprocessWatch.stop();

      // Run DGNet segmentation directly using native memory buffers
      final result = await _pipeline.dgnetService.runSegmentationWithBuffers(
        inputTensor: _inputTensorBuffer,
        outputBuffer: _outputTensorBuffer,
        binaryMaskBuffer: _binaryMaskBuffer,
        probabilityMaskBuffer: _probabilityMaskBuffer,
        visitedBuffer: _visitedBuffer,
        scratchQueue: _scratchQueue,
        originalWidth: _frameWidth,
        originalHeight: _frameHeight,
        threshold: _confidenceThreshold,
        preprocessingMs: preprocessWatch.elapsedMicroseconds / 1000.0,
      );

      // Run target tracker to smooth box coordinates and assign stable IDs
      _trackedTargets = _tracker.update(result.regions);

      // Trigger tactical audio ping and haptic pulse for newly confirmed targets
      _alertService.processTargets(_trackedTargets);

      _currentResult = result;
      _lastInferenceMs = result.totalMs;

      // Count processed frames over 1-second intervals to calculate real-time FPS
      _frameCount++;
      final now = DateTime.now();
      if (now.difference(_lastFpsTimestamp).inMilliseconds >= 1000) {
        _fps = _frameCount.toDouble();
        _frameCount = 0;
        _lastFpsTimestamp = now;

        // Measure actual app memory usage in Megabytes (MB)
        _ramUsageMb = AppMemoryUtils.getCurrentRssMb();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[LiveInference] Frame processing error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  // Samples camera planes directly into our model input buffer with 90-degree portrait rotation.
  // Uses integer arithmetic to convert YUV colors to RGB values between 0.0 and 1.0.
  void _sampleCameraPlanesToInputBuffer(CameraImage cameraImage) {
    final cameraWidth = cameraImage.width;
    final cameraHeight = cameraImage.height;

    // Update coordinate lookup tables if camera dimensions change
    if (_cachedCameraWidth != cameraWidth ||
        _cachedCameraHeight != cameraHeight) {
      _cachedCameraWidth = cameraWidth;
      _cachedCameraHeight = cameraHeight;

      // For 90-degree clockwise rotation:
      // Portrait X maps to camera Y (from bottom to top)
      // Portrait Y maps to camera X (from left to right)
      for (int y = 0; y < _targetHeight; y++) {
        _camXTable[y] = (y * cameraWidth) ~/ _targetHeight;
      }
      for (int x = 0; x < _targetWidth; x++) {
        _camYTable[x] =
            cameraHeight - 1 - ((x * cameraHeight) ~/ _targetWidth);
      }
    }

    final planeY = cameraImage.planes[0].bytes;
    final planeU = cameraImage.planes[1].bytes;
    final planeV = cameraImage.planes[2].bytes;

    final rowStrideY = cameraImage.planes[0].bytesPerRow;
    final rowStrideUV = cameraImage.planes[1].bytesPerRow;
    final pixelStrideUV = cameraImage.planes[1].bytesPerPixel ?? 1;

    int destIndex = 0;
    const inv255 = 1.0 / 255.0;

    for (int y = 0; y < _targetHeight; y++) {
      final camX = _camXTable[y];
      final uvX = (camX >> 1) * pixelStrideUV;

      for (int x = 0; x < _targetWidth; x++) {
        final camY = _camYTable[x];
        final yIndex = camY * rowStrideY + camX;
        final uvIndex = (camY >> 1) * rowStrideUV + uvX;

        final yp = planeY[yIndex];
        final up = planeU[uvIndex] - 128;
        final vp = planeV[uvIndex] - 128;

        // Fast integer math for YUV to RGB color conversion
        int r = yp + ((1436 * vp) >> 10);
        int g = yp - ((352 * up + 731 * vp) >> 10);
        int b = yp + ((1814 * up) >> 10);

        if (r < 0) {
          r = 0;
        } else if (r > 255) {
          r = 255;
        }

        if (g < 0) {
          g = 0;
        } else if (g > 255) {
          g = 255;
        }

        if (b < 0) {
          b = 0;
        } else if (b > 255) {
          b = 255;
        }

        // Store normalized RGB values (0.0 to 1.0) directly into the input tensor buffer
        _inputTensorBuffer[destIndex++] = r * inv255;
        _inputTensorBuffer[destIndex++] = g * inv255;
        _inputTensorBuffer[destIndex++] = b * inv255;
      }
    }
  }

  // Updates the live detection sensitivity threshold on the fly
  void setConfidenceThreshold(double threshold) {
    _confidenceThreshold = threshold;
    notifyListeners();
  }

  // Increases CPU threads used for model inference
  Future<void> incrementThreads() async {
    if (_cpuThreads < 8) {
      _cpuThreads++;
      notifyListeners();
      await _registry.updateHardwareDelegate(
          delegate: 'CPU', threads: _cpuThreads);
    }
  }

  // Decreases CPU threads used for model inference
  Future<void> decrementThreads() async {
    if (_cpuThreads > 1) {
      _cpuThreads--;
      notifyListeners();
      await _registry.updateHardwareDelegate(
          delegate: 'CPU', threads: _cpuThreads);
    }
  }

  // Toggles acoustic radar ping sound on or off
  void toggleAudioMute() {
    _alertService.toggleMute();
    notifyListeners();
  }

  @override
  void dispose() {
    stopStreaming();
    _alertService.dispose();
    _cameraController?.dispose();
    super.dispose();
  }
}
