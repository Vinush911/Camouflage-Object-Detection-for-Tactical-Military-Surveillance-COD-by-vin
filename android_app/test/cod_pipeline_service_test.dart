import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:android_app/model/classifier/classifier_service.dart';
import 'package:android_app/model/dgnet/dgnet_service.dart';
import 'package:android_app/models/detection_result.dart';
import 'package:android_app/models/model_metadata.dart';
import 'package:android_app/models/target_region.dart';
import 'package:android_app/services/cod_pipeline_service.dart';

// Test mock for DGNet segmentation service
class MockDgnetService extends DgnetSegmentationService {
  final DetectionResult stubResult;
  MockDgnetService(this.stubResult);

  @override
  bool get isAvailable => stubResult.isDgnetAvailable;

  @override
  Future<DetectionResult> runSegmentation(
    img.Image inputImage, {
    double? threshold,
    int? minRegionArea,
  }) async {
    return stubResult;
  }
}

// Test mock for secondary target classifier service
class MockClassifierService extends TargetClassificationService {
  final bool available;
  final bool isProto;
  bool classifyCalled = false;
  Uint8List? passedMask;

  MockClassifierService({this.available = true, this.isProto = true});

  @override
  bool get isAvailable => available;

  @override
  ModelMetadata get metadata => ModelMetadata(
        modelName: 'EfficientNet-B0 (Untrained Prototype)',
        task: 'classification',
        assetPath: 'assets/models/classifier/model.tflite',
        status: available ? ModelStatus.loaded : ModelStatus.unavailable,
        inputShape: const [1, 224, 224, 3],
        inputDataType: 'float32',
        outputShape: const [1, 2],
        outputDataType: 'float32',
        isPrototype: isProto,
      );

  @override
  Future<ClassificationBatchResult> classifyRegions(
    img.Image originalImage,
    List<TargetRegion> regions, {
    Uint8List? binaryMask,
    int? maskWidth,
    int? maskHeight,
  }) async {
    classifyCalled = true;
    passedMask = binaryMask;

    final updated = regions
        .map((r) => r.copyWithClassification(
              className: 'Camouflaged Target',
              confidence: 0.88,
            ))
        .toList();

    return ClassificationBatchResult(
      regions: updated,
      elapsedMilliseconds: 12.0,
      isExecuted: available,
    );
  }
}

void main() {
  group('CodPipelineService Integration Tests', () {
    final testImage = img.Image(width: 384, height: 384);

    test('returns "No target detected" and skips classifier when DGNet finds no regions', () async {
      final emptyDgnetResult = DetectionResult.empty(
        width: 384,
        height: 384,
        dgnetAvailable: true,
      );

      final dgnetMock = MockDgnetService(emptyDgnetResult);
      final classifierMock = MockClassifierService();

      final pipeline = CodPipelineService(
        dgnet: dgnetMock,
        classifier: classifierMock,
      );

      final result = await pipeline.processImage(testImage);

      // Verifies that the classifier was NOT called when DGNet found no target
      expect(classifierMock.classifyCalled, isFalse);
      expect(result.regions, isEmpty);
      expect(result.statusMessage, 'No target detected');
    });

    test('runs classifier on mask-gated ROIs when DGNet finds valid target', () async {
      final binaryMask = Uint8List(384 * 384);
      binaryMask[100] = 255;

      const region = TargetRegion(
        id: 1,
        boundingBox: Rect.fromLTWH(50, 50, 80, 80),
        pixelArea: 6400,
        regionConfidence: 0.92,
      );

      final dgnetResultWithTarget = DetectionResult(
        originalWidth: 384,
        originalHeight: 384,
        maskWidth: 384,
        maskHeight: 384,
        probabilityMask: Float32List(384 * 384),
        binaryMask: binaryMask,
        regions: [region],
        preprocessingMs: 5.0,
        dgnetInferenceMs: 25.0,
        postprocessingMs: 8.0,
        classificationInferenceMs: 0.0,
        totalMs: 38.0,
        isDgnetAvailable: true,
        isClassifierAvailable: true,
      );

      final dgnetMock = MockDgnetService(dgnetResultWithTarget);
      final classifierMock = MockClassifierService(isProto: true);

      final pipeline = CodPipelineService(
        dgnet: dgnetMock,
        classifier: classifierMock,
      );

      final result = await pipeline.processImage(testImage);

      // Verifies classifier ran with mask passed
      expect(classifierMock.classifyCalled, isTrue);
      expect(classifierMock.passedMask, isNotNull);
      expect(result.regions.length, 1);
      expect(result.regions[0].isClassified, isTrue);
      expect(result.regions[0].classificationClass, 'Camouflaged Target');
      // Verifies status notes the prototype classifier
      expect(result.statusMessage, contains('UNTRAINED PROTOTYPE'));
    });
  });
}
