import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:android_app/config/app_config.dart';
import 'package:android_app/model/dgnet/dgnet_preprocessor.dart';
import 'package:android_app/model/model_config.dart';
import 'package:android_app/services/image_preprocessor.dart';

void main() {
  group('Image Preprocessor Tests', () {
    test('resizes arbitrary image to exact model dimensions [384, 384, 3]', () {
      final preprocessor = ImagePreprocessor();

      // Create a test image with different dimensions (e.g. 1920x1080)
      final testImage = img.Image(width: 1920, height: 1080);
      // Fill with sample color
      for (var y = 0; y < testImage.height; y++) {
        for (var x = 0; x < testImage.width; x++) {
          testImage.setPixelRgb(x, y, 128, 64, 200);
        }
      }

      final processed = preprocessor.process(testImage);
      final tensor = processed.tensorInput;

      // Check tensor shape: [1, 384, 384, 3]
      expect(tensor.length, equals(1));
      expect(tensor[0].length, equals(AppConfig.inputHeight));
      expect(tensor[0][0].length, equals(AppConfig.inputWidth));
      expect(tensor[0][0][0].length, equals(AppConfig.inputChannels));
    });

    test('normalizes pixel color values from 0-255 into 0.0-1.0 range', () {
      final preprocessor = ImagePreprocessor();

      // Create an image with known color values: 0, 128, 255
      final testImage = img.Image(width: 100, height: 100);
      testImage.setPixelRgb(0, 0, 0, 128, 255);

      final processed = preprocessor.process(testImage);
      final pixel = processed.tensorInput[0][0][0];

      // Red: 0 / 255.0 = 0.0
      expect(pixel[0], closeTo(0.0, 0.001));
      // Green: 128 / 255.0 ~ 0.5019
      expect(pixel[1], closeTo(128.0 / 255.0, 0.01));
      // Blue: 255 / 255.0 = 1.0
      expect(pixel[2], closeTo(1.0, 0.001));
    });

    test('measures elapsed preprocessing time accurately', () {
      final preprocessor = ImagePreprocessor();
      final testImage = img.Image(width: 500, height: 500);

      final processed = preprocessor.process(testImage);
      // Preprocessing time should be greater than zero milliseconds
      expect(processed.elapsedMilliseconds, greaterThan(0.0));
    });

    test('processToBuffer writes directly to flat Float32List buffer', () {
      final dgnetPreprocessor = DgnetPreprocessor();
      const config = ModelConfig(
        modelName: 'DGNet-Test',
        task: 'segmentation',
        inputWidth: 64,
        inputHeight: 64,
        inputChannels: 3,
      );

      final testImage = img.Image(width: 100, height: 100);
      testImage.setPixelRgb(0, 0, 255, 0, 0);

      final processed = dgnetPreprocessor.processToBuffer(testImage, config);
      expect(processed.tensorInput, isA<Float32List>());
      final buffer = processed.tensorInput as Float32List;
      expect(buffer.length, equals(64 * 64 * 3));
      expect(processed.elapsedMilliseconds, greaterThan(0.0));
    });
  });
}
