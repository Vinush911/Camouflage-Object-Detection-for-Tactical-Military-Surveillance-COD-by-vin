import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:android_app/detection/region_extractor.dart';
import 'package:android_app/model/classifier/classifier_postprocessor.dart';
import 'package:android_app/model/classifier/classifier_preprocessor.dart';
import 'package:android_app/model/model_config.dart';
import 'package:android_app/models/target_region.dart';

void main() {
  group('Classifier Pipeline Tests', () {
    const config = ModelConfig(
      modelName: 'Target Classifier',
      task: 'classification',
      inputWidth: 224,
      inputHeight: 224,
      inputChannels: 3,
      classes: ['Soldier', 'Tank', 'Truck'],
    );

    test('ClassifierPostprocessor applies softmax and extracts highest probability class', () {
      final postprocessor = ClassifierPostprocessor();

      // Raw logits where index 1 (Tank) is highest
      final rawOutput = [
        [1.2, 4.8, 0.5],
      ];

      final prediction = postprocessor.process(rawOutput, config);

      expect(prediction.classIndex, 1);
      expect(prediction.className, 'Tank');
      expect(prediction.confidence, greaterThan(0.90));
    });

    test('ClassifierPostprocessor handles Soldier class at index 0 correctly', () {
      final postprocessor = ClassifierPostprocessor();

      // Raw logits where index 0 (Soldier) is highest
      final rawOutput = [
        [5.0, 1.0, 0.2],
      ];

      final prediction = postprocessor.process(rawOutput, config);

      expect(prediction.classIndex, 0);
      expect(prediction.className, 'Soldier');
      expect(prediction.confidence, greaterThan(0.95));
    });

    test('ClassifierPreprocessor normalizes cropped patch properly', () {
      final preprocessor = ClassifierPreprocessor();
      final patch = img.Image(width: 100, height: 100);
      img.fill(patch, color: img.ColorRgb8(255, 128, 0));

      final tensor = preprocessor.process(patch, config);

      expect(tensor.length, 1);
      expect(tensor[0].length, 224);
      expect(tensor[0][0].length, 224);
      expect(tensor[0][0][0].length, 3);

      // Red channel should normalize 255 / 255 = 1.0
      expect(tensor[0][0][0][0], closeTo(1.0, 0.01));
      // Green channel should normalize 128 / 255 ≈ 0.5
      expect(tensor[0][0][0][1], closeTo(0.5, 0.02));
      // Blue channel should normalize 0 / 255 = 0.0
      expect(tensor[0][0][0][2], closeTo(0.0, 0.01));
    });

    test('RegionExtractor crops region within image boundaries with padding', () {
      final original = img.Image(width: 500, height: 500);
      const region = TargetRegion(
        id: 1,
        boundingBox: Rect.fromLTWH(100, 100, 80, 80),
        pixelArea: 2500,
        regionConfidence: 0.92,
      );

      final cropped = RegionExtractor.cropRegion(
        originalImage: original,
        region: region,
        paddingFactor: 0.1,
      );

      expect(cropped, isNotNull);
      // Padded size: 80 + 2 * (80 * 0.1) = 80 + 16 = 96
      expect(cropped!.width, closeTo(96, 2));
      expect(cropped.height, closeTo(96, 2));
    });

    test('TargetRegion updates with classification and formats confidences distinctly', () {
      const region = TargetRegion(
        id: 1,
        boundingBox: Rect.fromLTWH(50, 50, 60, 60),
        pixelArea: 800,
        regionConfidence: 0.885,
      );

      expect(region.isClassified, isFalse);
      expect(region.displayLabel, 'Camouflaged Target');
      expect(region.formattedRegionConfidence, '88.5%');
      expect(region.formattedClassificationConfidence, 'Unavailable');

      final classified = region.copyWithClassification(
        className: 'Soldier',
        confidence: 0.942,
      );

      expect(classified.isClassified, isTrue);
      expect(classified.displayLabel, 'Soldier');
      expect(classified.formattedRegionConfidence, '88.5%');
      expect(classified.formattedClassificationConfidence, '94.2%');
    });
  });
}
