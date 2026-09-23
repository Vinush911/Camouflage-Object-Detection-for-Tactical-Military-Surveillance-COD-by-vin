import 'package:image/image.dart' as img;
import '../model_config.dart';

// Preprocesses a cropped target image patch for the classification model.
// Resizes the patch to the classifier's expected input dimensions and normalizes pixel values.

class ClassifierPreprocessor {
  // Prepares the cropped patch into a 4D tensor [1, height, width, 3]
  List<List<List<List<double>>>> process(
    img.Image croppedPatch,
    ModelConfig config,
  ) {
    final targetWidth = config.inputWidth;
    final targetHeight = config.inputHeight;

    // Resize patch to classifier dimensions
    final resized = img.copyResize(
      croppedPatch,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );

    // Build tensor
    return List.generate(
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
  }

  double _normalize(double value, String normalization) {
    switch (normalization) {
      case 'minus_one_to_one':
        return (value / 127.5) - 1.0;
      case 'none':
        return value;
      case 'zero_to_one':
      default:
        return value / 255.0;
    }
  }
}
