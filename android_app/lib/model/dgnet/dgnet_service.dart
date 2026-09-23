import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../detection/connected_components.dart';
import '../../models/detection_result.dart';
import '../../models/model_metadata.dart';
import '../model_registry.dart';
import 'dgnet_postprocessor.dart';
import 'dgnet_preprocessor.dart';

// Service dedicated to running the DGNet camouflage segmentation model.
// Produces binary segmentation masks and extracts disconnected target regions.
// If the model is not loaded or missing, it cleanly reports unavailability without fake data.

class DgnetSegmentationService {
  final ModelRegistry _registry;
  final DgnetPreprocessor _preprocessor = DgnetPreprocessor();
  final DgnetPostprocessor _postprocessor = DgnetPostprocessor();

  // Used to print the model summary only once on the first inference call
  bool _hasLoggedModelInfo = false;

  DgnetSegmentationService({ModelRegistry? registry})
      : _registry = registry ?? ModelRegistry();

  ModelMetadata get metadata => _registry.dgnetMetadata;
  bool get isAvailable => _registry.isDgnetLoaded;

  // Runs the segmentation pipeline on an input image
  Future<DetectionResult> runSegmentation(
    img.Image inputImage, {
    double? threshold,
    int? minRegionArea,
  }) async {
    // If DGNet model is not loaded, return empty result and report unavailable
    if (!_registry.isDgnetLoaded || _registry.dgnetPackage == null) {
      debugPrint('[DgnetService] DGNet model is not available.');
      return DetectionResult.empty(
        width: inputImage.width,
        height: inputImage.height,
        dgnetAvailable: false,
        classifierAvailable: _registry.isClassifierLoaded,
        message: 'DGNet model unavailable.',
      );
    }

    final package = _registry.dgnetPackage!;
    final interpreter = package.interpreter;
    final config = package.config;

    final originalWidth = inputImage.width;
    final originalHeight = inputImage.height;

    // 1. Preprocessing: resize to model dimensions and normalize
    final preprocessed = _preprocessor.process(inputImage, config);

    // 2. Prepare flat output buffer matching model dimensions [1, H, W, 1]
    final height = config.inputHeight;
    final width = config.inputWidth;
    final rawOutput = Float32List(height * width);

    // 3. Inference: execute neural network and measure pure model runtime
    final stopwatch = Stopwatch()..start();
    try {
      interpreter.run(preprocessed.tensorInput, rawOutput.buffer);
    } catch (e) {
      debugPrint('[DgnetService] Inference error: $e');
      return DetectionResult.empty(
        width: originalWidth,
        height: originalHeight,
        dgnetAvailable: false,
        message: 'Inference failed: $e',
      );
    }
    stopwatch.stop();
    final inferenceMs = stopwatch.elapsedMicroseconds / 1000.0;

    // 4. Postprocessing: convert to probability mask and binary threshold
    final postprocessed = _postprocessor.process(
      rawOutput: rawOutput,
      config: config,
      threshold: threshold ?? config.threshold,
    );

    // 5. Connected Component Analysis: extract separate target regions
    final componentResult = ConnectedComponents.extractRegions(
      binaryMask: postprocessed.binaryMask,
      probabilityMask: postprocessed.probabilityMask,
      maskWidth: postprocessed.maskWidth,
      maskHeight: postprocessed.maskHeight,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      minRegionArea: minRegionArea ?? config.minRegionArea,
    );

    final totalPostprocessingMs =
        postprocessed.elapsedMilliseconds + componentResult.elapsedMilliseconds;
    final totalMs =
        preprocessed.elapsedMilliseconds + inferenceMs + totalPostprocessingMs;

    // Print a one-time summary on the very first successful inference.
    // This confirms the active model file, its tensor specs, and quantization params.
    // The flag prevents this from spamming the log on every camera frame.
    if (!_hasLoggedModelInfo) {
      _hasLoggedModelInfo = true;
      final inTensor = package.interpreter.getInputTensors()[0];
      final outTensor = package.interpreter.getOutputTensors()[0];
      debugPrint('[DGNet] ========== Model Initialization Summary ==========');
      debugPrint('[DGNet] Model     : ${config.modelName} (dgnet_s_int8.tflite)');
      debugPrint('[DGNet] Input     : shape=${inTensor.shape}, type=${inTensor.type}');
      debugPrint('[DGNet] In  quant : scale=${inTensor.params.scale}, zero_point=${inTensor.params.zeroPoint}');
      debugPrint('[DGNet] Output    : shape=${outTensor.shape}, type=${outTensor.type}');
      debugPrint('[DGNet] Out quant : scale=${outTensor.params.scale}, zero_point=${outTensor.params.zeroPoint}');
      debugPrint('[DGNet] Normalize : ${config.normalization}, activation: ${config.outputActivation}');
      debugPrint('[DGNet] =====================================================');
    }

    return DetectionResult(
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      maskWidth: postprocessed.maskWidth,
      maskHeight: postprocessed.maskHeight,
      probabilityMask: postprocessed.probabilityMask,
      binaryMask: postprocessed.binaryMask,
      regions: componentResult.regions,
      preprocessingMs: preprocessed.elapsedMilliseconds,
      dgnetInferenceMs: inferenceMs,
      postprocessingMs: totalPostprocessingMs,
      classificationInferenceMs: 0.0,
      totalMs: totalMs,
      isDgnetAvailable: true,
      isClassifierAvailable: _registry.isClassifierLoaded,
      statusMessage: null,
    );
  }

  // Runs segmentation using pre-allocated memory buffers for fast live camera processing.
  // This avoids creating thousands of temporary objects on every camera frame.
  Future<DetectionResult> runSegmentationWithBuffers({
    required Float32List inputTensor,
    required Float32List outputBuffer,
    required Uint8List binaryMaskBuffer,
    required Float32List probabilityMaskBuffer,
    Uint8List? visitedBuffer,
    Int32List? scratchQueue,
    required int originalWidth,
    required int originalHeight,
    double? threshold,
    int? minRegionArea,
    double preprocessingMs = 0.0,
  }) async {
    // If DGNet model is not loaded, return an empty result
    if (!_registry.isDgnetLoaded || _registry.dgnetPackage == null) {
      return DetectionResult.empty(
        width: originalWidth,
        height: originalHeight,
        dgnetAvailable: false,
        classifierAvailable: _registry.isClassifierLoaded,
        message: 'DGNet model unavailable.',
      );
    }

    final package = _registry.dgnetPackage!;
    final interpreter = package.interpreter;
    final config = package.config;

    // 1. Inference: run the neural network directly using native buffers
    final stopwatch = Stopwatch()..start();
    try {
      interpreter.run(inputTensor.buffer, outputBuffer.buffer);
    } catch (e) {
      debugPrint('[DgnetService] Buffer inference error: $e');
      return DetectionResult.empty(
        width: originalWidth,
        height: originalHeight,
        dgnetAvailable: false,
        message: 'Buffer inference failed: $e',
      );
    }
    stopwatch.stop();
    final inferenceMs = stopwatch.elapsedMicroseconds / 1000.0;

    // 2. Postprocessing: convert model output into probability and binary masks
    final postprocessed = _postprocessor.process(
      rawOutput: outputBuffer,
      config: config,
      threshold: threshold ?? config.threshold,
      probabilityMaskBuffer: probabilityMaskBuffer,
      binaryMaskBuffer: binaryMaskBuffer,
    );

    // 3. Find connected groups of pixels (target areas)
    final componentResult = ConnectedComponents.extractRegions(
      binaryMask: postprocessed.binaryMask,
      probabilityMask: postprocessed.probabilityMask,
      maskWidth: postprocessed.maskWidth,
      maskHeight: postprocessed.maskHeight,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      minRegionArea: minRegionArea ?? config.minRegionArea,
      visitedBuffer: visitedBuffer,
      scratchQueue: scratchQueue,
    );

    final totalPostprocessingMs =
        postprocessed.elapsedMilliseconds + componentResult.elapsedMilliseconds;
    final totalMs = preprocessingMs + inferenceMs + totalPostprocessingMs;

    return DetectionResult(
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      maskWidth: postprocessed.maskWidth,
      maskHeight: postprocessed.maskHeight,
      probabilityMask: postprocessed.probabilityMask,
      binaryMask: postprocessed.binaryMask,
      regions: componentResult.regions,
      preprocessingMs: preprocessingMs,
      dgnetInferenceMs: inferenceMs,
      postprocessingMs: totalPostprocessingMs,
      classificationInferenceMs: 0.0,
      totalMs: totalMs,
      isDgnetAvailable: true,
      isClassifierAvailable: _registry.isClassifierLoaded,
      statusMessage: null,
    );
  }
}
