import 'dart:math';
import 'dart:typed_data';
import '../model_config.dart';

// Converts the raw numbers produced by DGNet into probability maps and binary masks.

class PostprocessedSegmentation {
  final Float32List probabilityMask;
  final Uint8List binaryMask;
  final int maskWidth;
  final int maskHeight;
  final double elapsedMilliseconds;

  const PostprocessedSegmentation({
    required this.probabilityMask,
    required this.binaryMask,
    required this.maskWidth,
    required this.maskHeight,
    required this.elapsedMilliseconds,
  });
}

class DgnetPostprocessor {
  // Postprocesses the raw tensor output from DGNet into a probability mask and binary mask
  PostprocessedSegmentation process({
    required dynamic rawOutput,
    required ModelConfig config,
    required double threshold,
    Float32List? probabilityMaskBuffer,
    Uint8List? binaryMaskBuffer,
  }) {
    final stopwatch = Stopwatch()..start();

    final height = config.inputHeight;
    final width = config.inputWidth;
    final totalPixels = width * height;

    // Reuse provided buffers to avoid creating new lists every frame
    final probabilityMask = probabilityMaskBuffer ?? Float32List(totalPixels);
    final binaryMask = binaryMaskBuffer ?? Uint8List(totalPixels);

    var minVal = double.infinity;
    var maxVal = -double.infinity;

    // Fast path: if the output is already a flat list of numbers, read it directly
    if (rawOutput is Float32List || rawOutput is List<double>) {
      for (int i = 0; i < totalPixels; i++) {
        final double val = rawOutput[i];
        if (val < minVal) minVal = val;
        if (val > maxVal) maxVal = val;
        probabilityMask[i] = val;
      }
    } else {
      // Multi-dimensional list path for compatibility
      final isChannelFirst = rawOutput is List &&
          rawOutput.isNotEmpty &&
          rawOutput[0] is List &&
          rawOutput[0].length == 1 &&
          rawOutput[0][0] is List &&
          rawOutput[0][0].length == height;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          double val;
          if (isChannelFirst) {
            val = (rawOutput[0][0][y][x] as num).toDouble();
          } else {
            val = (rawOutput[0][y][x][0] as num).toDouble();
          }
          if (val < minVal) minVal = val;
          if (val > maxVal) maxVal = val;
          probabilityMask[y * width + x] = val;
        }
      }
    }

    // Determine if sigmoid needs to be applied:
    // If numbers are outside 0.0 to 1.0 or if config explicitly specifies sigmoid
    final needsSigmoid = config.outputActivation == 'sigmoid' ||
        minVal < -0.01 ||
        maxVal > 1.01;

    for (int i = 0; i < totalPixels; i++) {
      double prob = probabilityMask[i];
      if (needsSigmoid) {
        prob = 1.0 / (1.0 + exp(-prob));
        probabilityMask[i] = prob;
      }
      binaryMask[i] = prob >= threshold ? 255 : 0;
    }

    stopwatch.stop();

    return PostprocessedSegmentation(
      probabilityMask: probabilityMask,
      binaryMask: binaryMask,
      maskWidth: width,
      maskHeight: height,
      elapsedMilliseconds: stopwatch.elapsedMicroseconds / 1000.0,
    );
  }
}
