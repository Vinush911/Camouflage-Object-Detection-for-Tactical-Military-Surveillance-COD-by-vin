import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../model_config.dart';

// Prepares raw input images for the DGNet segmentation model.
// Resizes images to the dimensions expected by the model and normalizes pixel values.

class PreprocessedInput {
  final dynamic tensorInput;
  final double elapsedMilliseconds;

  const PreprocessedInput({
    required this.tensorInput,
    required this.elapsedMilliseconds,
  });
}

class DgnetPreprocessor {
  // Preprocesses an image according to the model configuration
  PreprocessedInput process(img.Image originalImage, ModelConfig config) {
    final stopwatch = Stopwatch()..start();

    final targetWidth = config.inputWidth;
    final targetHeight = config.inputHeight;

    // Resize image to model input dimensions
    final resized = img.copyResize(
      originalImage,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );

    // Build 4D list: [1, height, width, 3]
    var tensor = List.generate(
      1,
      (_) => List.generate(
        targetHeight,
        (y) => List.generate(
          targetWidth,
          (x) {
            final pixel = resized.getPixel(x, y);
            final r = pixel.r.toDouble();
            final g = pixel.g.toDouble();
            final b = pixel.b.toDouble();

            return [
              _normalize(r, config.normalization),
              _normalize(g, config.normalization),
              _normalize(b, config.normalization),
            ];
          },
        ),
      ),
    );

    stopwatch.stop();

    return PreprocessedInput(
      tensorInput: tensor,
      elapsedMilliseconds: stopwatch.elapsedMicroseconds / 1000.0,
    );
  }

  // Preprocesses an image directly into a flat Float32List buffer to avoid creating thousands of objects
  PreprocessedInput processToBuffer(
    img.Image originalImage,
    ModelConfig config, {
    Float32List? destinationBuffer,
  }) {
    final stopwatch = Stopwatch()..start();

    final targetWidth = config.inputWidth;
    final targetHeight = config.inputHeight;
    final totalFloats = targetWidth * targetHeight * 3;

    final buffer = destinationBuffer ?? Float32List(totalFloats);

    final resized = img.copyResize(
      originalImage,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );

    int index = 0;
    for (int y = 0; y < targetHeight; y++) {
      for (int x = 0; x < targetWidth; x++) {
        final pixel = resized.getPixel(x, y);
        buffer[index++] = _normalize(pixel.r.toDouble(), config.normalization);
        buffer[index++] = _normalize(pixel.g.toDouble(), config.normalization);
        buffer[index++] = _normalize(pixel.b.toDouble(), config.normalization);
      }
    }

    stopwatch.stop();

    return PreprocessedInput(
      tensorInput: buffer,
      elapsedMilliseconds: stopwatch.elapsedMicroseconds / 1000.0,
    );
  }

  // Helper function to scale pixel numbers from 0-255 into the range expected by the model
  double _normalize(double value, String normalization) {
    switch (normalization) {
      case 'minus_one_to_one':
        // Converts 0..255 to -1.0..1.0
        return (value / 127.5) - 1.0;
      case 'none':
        return value;
      case 'zero_to_one':
      default:
        // Converts 0..255 to 0.0..1.0
        return value / 255.0;
    }
  }
}
