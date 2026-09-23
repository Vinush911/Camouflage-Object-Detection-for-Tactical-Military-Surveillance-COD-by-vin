import 'dart:typed_data';
import '../config/app_config.dart';
import '../data_models/detected_region.dart';
import '../utils/connected_components.dart';

// Converts raw model output tensors into useful target detections and masks.
// This applies the decision threshold, extracts distinct target regions,
// and computes confidence scores.

class PostprocessedData {
  final Float32List probabilityMask;
  final Uint8List binaryMask;
  final List<DetectedRegion> regions;
  final double elapsedMilliseconds;

  const PostprocessedData({
    required this.probabilityMask,
    required this.binaryMask,
    required this.regions,
    required this.elapsedMilliseconds,
  });
}

class MaskPostprocessor {
  final ConnectedComponentAnalyzer _analyzer = ConnectedComponentAnalyzer();

  // Processes the raw model output [1, 384, 384, 1] into a binary mask and target regions.
  PostprocessedData process({
    required List<List<List<List<double>>>> rawOutput,
    required int originalWidth,
    required int originalHeight,
    double threshold = AppConfig.defaultThreshold,
    int minRegionArea = AppConfig.defaultMinRegionAreaPixels,
  }) {
    final stopwatch = Stopwatch()..start();

    const maskHeight = AppConfig.inputHeight;
    const maskWidth = AppConfig.inputWidth;
    final totalPixels = maskHeight * maskWidth;

    final probMask = Float32List(totalPixels);
    final binMask = Uint8List(totalPixels);

    // Extract probabilities and apply threshold
    var idx = 0;
    final grid = rawOutput[0];
    for (var y = 0; y < maskHeight; y++) {
      final row = grid[y];
      for (var x = 0; x < maskWidth; x++) {
        // Output from DGNet is already passed through sigmoid, so values are in [0, 1]
        final prob = row[x][0];
        probMask[idx] = prob;
        binMask[idx] = (prob >= threshold) ? 255 : 0;
        idx++;
      }
    }

    // Separate multiple disconnected targets using connected component analysis
    final regions = _analyzer.analyze(
      binaryMask: binMask,
      probabilityMask: probMask,
      maskWidth: maskWidth,
      maskHeight: maskHeight,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      minArea: minRegionArea,
    );

    stopwatch.stop();
    final elapsedMs = stopwatch.elapsedMicroseconds / 1000.0;

    return PostprocessedData(
      probabilityMask: probMask,
      binaryMask: binMask,
      regions: regions,
      elapsedMilliseconds: elapsedMs,
    );
  }
}
