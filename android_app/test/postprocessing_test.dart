import 'package:flutter_test/flutter_test.dart';
import 'package:android_app/config/app_config.dart';
import 'package:android_app/services/mask_postprocessor.dart';

void main() {
  group('Mask Postprocessor Tests', () {
    test('thresholds raw sigmoid probabilities into binary mask correctly', () {
      final postprocessor = MaskPostprocessor();

      // Create a 4D output tensor [1, 384, 384, 1]
      final rawOutput = List.generate(
        1,
        (_) => List.generate(
          AppConfig.inputHeight,
          (y) => List.generate(
            AppConfig.inputWidth,
            (x) {
              // Create a high-probability region in the center
              if (x >= 150 && x <= 200 && y >= 150 && y <= 200) {
                return [0.85];
              }
              return [0.15];
            },
          ),
        ),
      );

      final result = postprocessor.process(
        rawOutput: rawOutput,
        originalWidth: 768,
        originalHeight: 768,
        threshold: 0.5,
        minRegionArea: 50,
      );

      // Verify probability mask size
      expect(result.probabilityMask.length, equals(AppConfig.inputWidth * AppConfig.inputHeight));

      // Verify binary mask thresholding
      final centerIdx = 175 * AppConfig.inputWidth + 175;
      final cornerIdx = 10 * AppConfig.inputWidth + 10;
      expect(result.binaryMask[centerIdx], equals(255));
      expect(result.binaryMask[cornerIdx], equals(0));

      // Verify target detection
      expect(result.regions.length, equals(1));
      final detected = result.regions.first;
      expect(detected.label, equals('Camouflaged Target'));
      expect(detected.regionConfidence, closeTo(0.85, 0.01));
      expect(result.elapsedMilliseconds, greaterThan(0.0));
    });
  });
}
