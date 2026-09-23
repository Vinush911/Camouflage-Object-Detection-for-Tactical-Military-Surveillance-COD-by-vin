import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../detection/connected_components.dart';
import '../model/classifier/classifier_service.dart';
import '../model/dgnet/dgnet_service.dart';
import '../models/detection_result.dart';
import '../models/target_region.dart';

// Coordinates the end-to-end detection pipeline.
// 1. Passes input image to DGNet for camouflage segmentation.
// 2. Extracts connected target regions from the segmentation mask.
// 3. Passes cropped target regions to the classifier model (if available).
// 4. Bundles results and isolated timing measurements into DetectionResult.

class CodPipelineService {
  final DgnetSegmentationService dgnetService;
  final TargetClassificationService classifierService;

  CodPipelineService({
    DgnetSegmentationService? dgnet,
    TargetClassificationService? classifier,
  })  : dgnetService = dgnet ?? DgnetSegmentationService(),
        classifierService = classifier ?? TargetClassificationService();

  // Runs full pipeline: segmentation followed by classification
  Future<DetectionResult> processImage(
    img.Image inputImage, {
    double? threshold,
    int? minRegionArea,
  }) async {
    // 1. Run DGNet segmentation
    final segResult = await dgnetService.runSegmentation(
      inputImage,
      threshold: threshold,
      minRegionArea: minRegionArea,
    );

    // If DGNet failed or was unavailable, return its result immediately
    if (!segResult.isDgnetAvailable || segResult.regions.isEmpty) {
      return segResult;
    }

    // 2. Run target classification on each detected region
    final classResult = await classifierService.classifyRegions(
      inputImage,
      segResult.regions,
    );

    final combinedTotalMs = segResult.totalMs + classResult.elapsedMilliseconds;

    return DetectionResult(
      originalWidth: segResult.originalWidth,
      originalHeight: segResult.originalHeight,
      maskWidth: segResult.maskWidth,
      maskHeight: segResult.maskHeight,
      probabilityMask: segResult.probabilityMask,
      binaryMask: segResult.binaryMask,
      regions: classResult.regions,
      preprocessingMs: segResult.preprocessingMs,
      dgnetInferenceMs: segResult.dgnetInferenceMs,
      postprocessingMs: segResult.postprocessingMs,
      classificationInferenceMs: classResult.elapsedMilliseconds,
      totalMs: combinedTotalMs,
      isDgnetAvailable: segResult.isDgnetAvailable,
      isClassifierAvailable: classResult.isExecuted,
      statusMessage: classResult.isExecuted
          ? null
          : 'Classification model unavailable.',
    );
  }

  // Fast re-thresholding on an existing probability mask without running DGNet inference again
  Future<DetectionResult> rethreshold({
    required DetectionResult existingResult,
    required img.Image originalImage,
    required double newThreshold,
    required int minRegionArea,
  }) async {
    final totalPixels = existingResult.maskWidth * existingResult.maskHeight;
    final newBinaryMask = Uint8List(totalPixels);

    // Threshold probability mask
    for (int i = 0; i < totalPixels; i++) {
      newBinaryMask[i] =
          existingResult.probabilityMask[i] >= newThreshold ? 255 : 0;
    }

    // Extract new connected components
    final componentResult = ConnectedComponents.extractRegions(
      binaryMask: newBinaryMask,
      probabilityMask: existingResult.probabilityMask,
      maskWidth: existingResult.maskWidth,
      maskHeight: existingResult.maskHeight,
      originalWidth: existingResult.originalWidth,
      originalHeight: existingResult.originalHeight,
      minRegionArea: minRegionArea,
    );

    // Run classification on new regions if classifier is available
    List<TargetRegion> finalRegions = componentResult.regions;
    double classificationMs = 0.0;
    bool isClassified = false;

    if (classifierService.isAvailable && finalRegions.isNotEmpty) {
      final classResult = await classifierService.classifyRegions(
        originalImage,
        finalRegions,
      );
      finalRegions = classResult.regions;
      classificationMs = classResult.elapsedMilliseconds;
      isClassified = classResult.isExecuted;
    }

    return DetectionResult(
      originalWidth: existingResult.originalWidth,
      originalHeight: existingResult.originalHeight,
      maskWidth: existingResult.maskWidth,
      maskHeight: existingResult.maskHeight,
      probabilityMask: existingResult.probabilityMask,
      binaryMask: newBinaryMask,
      regions: finalRegions,
      preprocessingMs: existingResult.preprocessingMs,
      dgnetInferenceMs: existingResult.dgnetInferenceMs,
      postprocessingMs: componentResult.elapsedMilliseconds,
      classificationInferenceMs: classificationMs,
      totalMs: existingResult.preprocessingMs +
          existingResult.dgnetInferenceMs +
          componentResult.elapsedMilliseconds +
          classificationMs,
      isDgnetAvailable: true,
      isClassifierAvailable: isClassified,
    );
  }
}
