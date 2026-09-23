import 'package:image/image.dart' as img;
import '../config/app_config.dart';

// Prepares an image for input into the DGNet neural network.
// This handles resizing to the model's required 384x384 size
// and converting color numbers (0-255) into float numbers between 0.0 and 1.0.

class PreprocessedData {
  // Input tensor formatted as [1, height, width, 3] for TFLite
  final List<List<List<List<double>>>> tensorInput;

  // Time taken to resize and normalize, in milliseconds
  final double elapsedMilliseconds;

  const PreprocessedData({
    required this.tensorInput,
    required this.elapsedMilliseconds,
  });
}

class ImagePreprocessor {
  final int targetWidth;
  final int targetHeight;

  ImagePreprocessor({
    this.targetWidth = AppConfig.inputWidth,
    this.targetHeight = AppConfig.inputHeight,
  });

  // Preprocesses an image and returns the model-ready 4D input tensor
  PreprocessedData process(img.Image originalImage) {
    final stopwatch = Stopwatch()..start();

    // Resize image to 384x384 using bilinear interpolation
    final resized = img.copyResize(
      originalImage,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );

    // Build the 4-dimensional tensor [1, 384, 384, 3]
    // Values are normalized from [0, 255] to [0.0, 1.0]
    final batch = <List<List<List<double>>>>[];
    final heightRows = <List<List<double>>>[];

    for (var y = 0; y < targetHeight; y++) {
      final widthCols = <List<double>>[];
      for (var x = 0; x < targetWidth; x++) {
        final pixel = resized.getPixel(x, y);
        // Extract normalized RGB channels
        final r = pixel.r / AppConfig.pixelNormalizationScale;
        final g = pixel.g / AppConfig.pixelNormalizationScale;
        final b = pixel.b / AppConfig.pixelNormalizationScale;
        widthCols.add([r.toDouble(), g.toDouble(), b.toDouble()]);
      }
      heightRows.add(widthCols);
    }
    batch.add(heightRows);

    stopwatch.stop();
    final elapsedMs = stopwatch.elapsedMicroseconds / 1000.0;

    return PreprocessedData(
      tensorInput: batch,
      elapsedMilliseconds: elapsedMs,
    );
  }
}
