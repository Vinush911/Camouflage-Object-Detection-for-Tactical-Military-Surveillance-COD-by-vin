import 'package:flutter_test/flutter_test.dart';
import 'package:android_app/core/errors/app_exceptions.dart';
import 'package:android_app/model/model_config.dart';

void main() {
  group('Tensor Validation and Incompatibility Tests', () {
    const config = ModelConfig(
      modelName: 'DGNet-MobileNetV3',
      task: 'segmentation',
      inputWidth: 384,
      inputHeight: 384,
      inputChannels: 3,
    );

    test('validates matching 4D tensor shape [1, 384, 384, 3]', () {
      final actualShape = [1, 384, 384, 3];

      final isValid = actualShape.length == 4 &&
          actualShape[1] == config.inputHeight &&
          actualShape[2] == config.inputWidth &&
          actualShape[3] == config.inputChannels;

      expect(isValid, isTrue);
    });

    test('detects incompatible input shape and formats ModelIncompatibleException', () {
      final incompatibleShape = [1, 640, 640, 3];

      final isMatch = incompatibleShape[1] == config.inputHeight &&
          incompatibleShape[2] == config.inputWidth;

      expect(isMatch, isFalse);

      final exception = ModelIncompatibleException(
        message: 'Input tensor shape mismatch for segmentation model.',
        expectedInput: [1, config.inputHeight, config.inputWidth, config.inputChannels],
        actualInput: incompatibleShape,
      );

      expect(exception.expectedInput, [1, 384, 384, 3]);
      expect(exception.actualInput, [1, 640, 640, 3]);
      expect(exception.message, contains('mismatch'));
    });
  });
}
