import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../detection/region_extractor.dart';
import '../../models/model_metadata.dart';
import '../../models/target_region.dart';
import '../model_registry.dart';
import 'classifier_postprocessor.dart';
import 'classifier_preprocessor.dart';

// Result of running the classification model on a list of target regions
class ClassificationBatchResult {
  final List<TargetRegion> regions;
  final double elapsedMilliseconds;
  final bool isExecuted;

  const ClassificationBatchResult({
    required this.regions,
    required this.elapsedMilliseconds,
    required this.isExecuted,
  });
}

// Service dedicated to classifying detected camouflaged regions (e.g. Non-Target vs Camouflaged Target).
// If the classifier model is unavailable, it leaves regions unclassified without fabricating fake predictions.
// When using an untrained prototype, it runs inference on the architecture while clearly marking prototype status.

class TargetClassificationService {
  final ModelRegistry _registry;
  final ClassifierPreprocessor _preprocessor = ClassifierPreprocessor();
  final ClassifierPostprocessor _postprocessor = ClassifierPostprocessor();

  // Flag to log model details once upon first inference
  bool _hasLoggedModelInfo = false;

  TargetClassificationService({ModelRegistry? registry})
      : _registry = registry ?? ModelRegistry();

  ModelMetadata get metadata => _registry.classifierMetadata;
  bool get isAvailable => _registry.isClassifierLoaded;

  // Classifies a list of target regions using mask-gated 224x224 patches
  Future<ClassificationBatchResult> classifyRegions(
    img.Image originalImage,
    List<TargetRegion> regions, {
    Uint8List? binaryMask,
    int? maskWidth,
    int? maskHeight,
  }) async {
    // If the classification model is not available or there are no regions, return as-is
    if (!_registry.isClassifierLoaded || _registry.classifierPackage == null || regions.isEmpty) {
      debugPrint('[ClassifierService] Classifier is not available or no regions to classify.');
      return ClassificationBatchResult(
        regions: regions,
        elapsedMilliseconds: 0.0,
        isExecuted: false,
      );
    }

    final package = _registry.classifierPackage!;
    final interpreter = package.interpreter;
    final config = package.config;

    // Print model status summary once
    if (!_hasLoggedModelInfo) {
      _hasLoggedModelInfo = true;
      final inTensor = interpreter.getInputTensors()[0];
      final outTensor = interpreter.getOutputTensors()[0];
      debugPrint('[Classifier] ========== Classifier Model Summary ==========');
      debugPrint('[Classifier] Model     : ${config.modelName}');
      debugPrint('[Classifier] Status    : ${config.isPrototype ? 'UNTRAINED PROTOTYPE' : 'TRAINED'}');
      debugPrint('[Classifier] Input     : shape=${inTensor.shape}, type=${inTensor.type}');
      debugPrint('[Classifier] Output    : shape=${outTensor.shape}, type=${outTensor.type}');
      debugPrint('[Classifier] Classes   : ${config.classes.join(', ')}');
      debugPrint('[Classifier] ===============================================');
    }

    final numClasses = interpreter.getOutputTensors().isNotEmpty
        ? interpreter.getOutputTensors()[0].shape.last
        : (config.classes.isNotEmpty ? config.classes.length : 2);

    final updatedRegions = <TargetRegion>[];
    final stopwatch = Stopwatch()..start();

    for (final region in regions) {
      // 1. Crop mask-gated 224x224 ROI patch with background suppressed
      final cropped = RegionExtractor.extractMaskGatedRoi(
        originalImage: originalImage,
        region: region,
        binaryMask: binaryMask,
        maskWidth: maskWidth ?? 384,
        maskHeight: maskHeight ?? 384,
        targetWidth: config.inputWidth,
        targetHeight: config.inputHeight,
      );

      if (cropped == null) {
        updatedRegions.add(region);
        continue;
      }

      // 2. Preprocess patch to classifier dimensions [1, 224, 224, 3]
      final inputTensor = _preprocessor.process(cropped, config);

      // 3. Prepare output buffer [1, numClasses]
      var rawOutput = List.generate(
        1,
        (_) => List<double>.filled(numClasses, 0.0),
      );

      // 4. Run inference
      try {
        interpreter.run(inputTensor, rawOutput);
        final prediction = _postprocessor.process(rawOutput, config);

        updatedRegions.add(
          region.copyWithClassification(
            className: prediction.className,
            confidence: prediction.confidence,
          ),
        );
      } catch (e) {
        debugPrint('[ClassifierService] Error classifying region #${region.id}: $e');
        updatedRegions.add(region);
      }
    }

    stopwatch.stop();
    final elapsedMs = stopwatch.elapsedMicroseconds / 1000.0;

    return ClassificationBatchResult(
      regions: updatedRegions,
      elapsedMilliseconds: elapsedMs,
      isExecuted: true,
    );
  }
}
