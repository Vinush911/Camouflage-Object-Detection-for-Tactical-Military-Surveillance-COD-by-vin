import 'dart:typed_data';
import 'target_region.dart';

// Holds the complete result of running the detection and classification pipeline on an image.
// It stores the segmentation masks, all detected target regions, and isolated latency timings.

class DetectionResult {
  // Dimensions of the original input image in pixels
  final int originalWidth;
  final int originalHeight;

  // Dimensions of the segmentation mask produced by DGNet
  final int maskWidth;
  final int maskHeight;

  // Raw probability scores between 0.0 and 1.0 directly produced by DGNet
  final Float32List probabilityMask;

  // Binary mask where 255 represents detected target foreground and 0 is background
  final Uint8List binaryMask;

  // Disconnected target regions discovered by connected component analysis
  final List<TargetRegion> regions;

  // Time taken to resize and normalize the input image (in milliseconds)
  final double preprocessingMs;

  // Time taken by DGNet TFLite interpreter to produce the segmentation mask (in milliseconds)
  final double dgnetInferenceMs;

  // Time taken to threshold probabilities, find connected blobs, and compute boxes (in milliseconds)
  final double postprocessingMs;

  // Time taken by the classification model to classify all target crops (in milliseconds)
  final double classificationInferenceMs;

  // Total time taken across all pipeline stages (in milliseconds)
  final double totalMs;

  // Whether the DGNet segmentation model was available and executed
  final bool isDgnetAvailable;

  // Whether the classification model was available and executed
  final bool isClassifierAvailable;

  // Optional message explaining pipeline status or warnings
  final String? statusMessage;

  const DetectionResult({
    required this.originalWidth,
    required this.originalHeight,
    required this.maskWidth,
    required this.maskHeight,
    required this.probabilityMask,
    required this.binaryMask,
    required this.regions,
    required this.preprocessingMs,
    double? dgnetInferenceMs,
    double? inferenceMs,
    required this.postprocessingMs,
    this.classificationInferenceMs = 0.0,
    required this.totalMs,
    this.isDgnetAvailable = true,
    this.isClassifierAvailable = false,
    this.statusMessage,
  }) : dgnetInferenceMs = dgnetInferenceMs ?? inferenceMs ?? 0.0;

  // Alias for DGNet segmentation inference latency
  double get inferenceMs => dgnetInferenceMs;

  // Total number of detected targets
  int get targetCount => regions.length;

  // Returns an empty result when DGNet model is not available
  factory DetectionResult.empty({
    int width = 0,
    int height = 0,
    String? message,
    bool dgnetAvailable = false,
    bool classifierAvailable = false,
  }) {
    return DetectionResult(
      originalWidth: width,
      originalHeight: height,
      maskWidth: 0,
      maskHeight: 0,
      probabilityMask: Float32List(0),
      binaryMask: Uint8List(0),
      regions: const [],
      preprocessingMs: 0.0,
      dgnetInferenceMs: 0.0,
      postprocessingMs: 0.0,
      classificationInferenceMs: 0.0,
      totalMs: 0.0,
      isDgnetAvailable: dgnetAvailable,
      isClassifierAvailable: classifierAvailable,
      statusMessage: message,
    );
  }
}
