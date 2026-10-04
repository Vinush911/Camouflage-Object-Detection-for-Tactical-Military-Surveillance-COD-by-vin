import 'dart:typed_data';
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

    test('RegionExtractor extractMaskGatedRoi suppresses background outside mask and sizes to 224x224', () {
      // Create a 100x100 white image
      final original = img.Image(width: 100, height: 100);
      img.fill(original, color: img.ColorRgb8(255, 255, 255));

      // Define a target region covering roughly 30..70 in x and y
      const region = TargetRegion(
        id: 1,
        boundingBox: Rect.fromLTWH(30, 30, 40, 40),
        pixelArea: 1600,
        regionConfidence: 0.95,
      );

      // Create a 100x100 mask where only the center [45..55, 45..55] is foreground (255)
      final mask = Uint8List(100 * 100);
      for (int y = 45; y < 55; y++) {
        for (int x = 45; x < 55; x++) {
          mask[y * 100 + x] = 255;
        }
      }

      final gatedRoi = RegionExtractor.extractMaskGatedRoi(
        originalImage: original,
        region: region,
        binaryMask: mask,
        maskWidth: 100,
        maskHeight: 100,
        targetWidth: 224,
        targetHeight: 224,
        paddingFactor: 0.0,
      );

      expect(gatedRoi, isNotNull);
      // Confirms the cropped ROI is exactly 224 x 224 x 3
      expect(gatedRoi!.width, 224);
      expect(gatedRoi.height, 224);
      expect(gatedRoi.numChannels, 3);

      // Center pixel (corresponding to the foreground mask) should remain white (255, 255, 255)
      final centerPixel = gatedRoi.getPixel(112, 112);
      expect(centerPixel.r, greaterThan(200));
      expect(centerPixel.g, greaterThan(200));
      expect(centerPixel.b, greaterThan(200));

      // Corner pixel (outside the foreground mask) should be suppressed to black (0, 0, 0)
      final cornerPixel = gatedRoi.getPixel(5, 5);
      expect(cornerPixel.r, 0);
      expect(cornerPixel.g, 0);
      expect(cornerPixel.b, 0);
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
