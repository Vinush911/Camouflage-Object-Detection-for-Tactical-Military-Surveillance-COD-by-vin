import 'dart:typed_data';
import 'dart:ui';
import '../config/app_config.dart';
import '../data_models/detected_region.dart';

// Finds disconnected groups of foreground pixels in a binary image.
// When soldiers or vehicles are hidden in different parts of a scene,
// this algorithm separates each group into its own target region.

class ConnectedComponentAnalyzer {
  // Disjoint-set data structure (Union-Find) to merge adjacent pixels that touch each other
  final List<int> _parent = [];

  int _find(int i) {
    var root = i;
    while (root != _parent[root]) {
      root = _parent[root];
    }
    // Path compression to make future lookups fast
    var curr = i;
    while (curr != root) {
      final next = _parent[curr];
      _parent[curr] = root;
      curr = next;
    }
    return root;
  }

  void _union(int i, int j) {
    final rootI = _find(i);
    final rootJ = _find(j);
    if (rootI != rootJ) {
      _parent[rootI] = rootJ;
    }
  }

  // Analyzes a binary mask and returns a list of detected target regions.
  List<DetectedRegion> analyze({
    required Uint8List binaryMask,
    required Float32List probabilityMask,
    required int maskWidth,
    required int maskHeight,
    required int originalWidth,
    required int originalHeight,
    int minArea = AppConfig.defaultMinRegionAreaPixels,
  }) {
    final totalPixels = maskWidth * maskHeight;
    final labels = Int32List(totalPixels);
    _parent.clear();
    // Label 0 is reserved for background
    _parent.add(0);

    var nextLabel = 1;

    // First Pass: Scan the image row by row and assign labels to foreground pixels
    for (var y = 0; y < maskHeight; y++) {
      for (var x = 0; x < maskWidth; x++) {
        final index = y * maskWidth + x;

        // Skip background pixels
        if (binaryMask[index] == 0) continue;

        // Check top and left neighbors (4-connectivity)
        var topLabel = 0;
        if (y > 0 && binaryMask[(y - 1) * maskWidth + x] > 0) {
          topLabel = labels[(y - 1) * maskWidth + x];
        }

        var leftLabel = 0;
        if (x > 0 && binaryMask[y * maskWidth + (x - 1)] > 0) {
          leftLabel = labels[y * maskWidth + (x - 1)];
        }

        if (topLabel == 0 && leftLabel == 0) {
          // New separate component started
          labels[index] = nextLabel;
          _parent.add(nextLabel);
          nextLabel++;
        } else if (topLabel != 0 && leftLabel == 0) {
          // Matches top neighbor
          labels[index] = topLabel;
        } else if (topLabel == 0 && leftLabel != 0) {
          // Matches left neighbor
          labels[index] = leftLabel;
        } else {
          // Touches both top and left neighbors: merge their groups
          labels[index] = topLabel;
          _union(topLabel, leftLabel);
        }
      }
    }

    // Accumulators for each component
    final minX = <int, int>{};
    final maxX = <int, int>{};
    final minY = <int, int>{};
    final maxY = <int, int>{};
    final areaCount = <int, int>{};
    final probSum = <int, double>{};

    // Second Pass: Resolve each pixel's root label and collect statistics
    for (var y = 0; y < maskHeight; y++) {
      for (var x = 0; x < maskWidth; x++) {
        final index = y * maskWidth + x;
        final rawLabel = labels[index];
        if (rawLabel == 0) continue;

        final rootLabel = _find(rawLabel);

        if (!areaCount.containsKey(rootLabel)) {
          minX[rootLabel] = x;
          maxX[rootLabel] = x;
          minY[rootLabel] = y;
          maxY[rootLabel] = y;
          areaCount[rootLabel] = 1;
          probSum[rootLabel] = probabilityMask[index].toDouble();
        } else {
          if (x < minX[rootLabel]!) minX[rootLabel] = x;
          if (x > maxX[rootLabel]!) maxX[rootLabel] = x;
          if (y < minY[rootLabel]!) minY[rootLabel] = y;
          if (y > maxY[rootLabel]!) maxY[rootLabel] = y;
          areaCount[rootLabel] = areaCount[rootLabel]! + 1;
          probSum[rootLabel] = probSum[rootLabel]! + probabilityMask[index].toDouble();
        }
      }
    }

    // Scale factors to map coordinates from 384x384 back to original photo size
    final scaleX = originalWidth / maskWidth;
    final scaleY = originalHeight / maskHeight;

    // Filter out small noisy spots and create the final list of targets
    final regions = <DetectedRegion>[];

    // Sort root labels by area (largest target first)
    final sortedRoots = areaCount.keys.toList()
      ..sort((a, b) => areaCount[b]!.compareTo(areaCount[a]!));

    var regionId = 1;
    for (final root in sortedRoots) {
      final area = areaCount[root]!;
      if (area < minArea) {
        // Ignore tiny noisy patches
        continue;
      }

      // Calculate mean probability within this region
      final avgConfidence = (probSum[root]! / area).clamp(0.0, 1.0);

      // Convert mask coordinates to original image coordinates
      final left = (minX[root]! * scaleX).clamp(0.0, originalWidth.toDouble());
      final top = (minY[root]! * scaleY).clamp(0.0, originalHeight.toDouble());
      final right = ((maxX[root]! + 1) * scaleX).clamp(0.0, originalWidth.toDouble());
      final bottom = ((maxY[root]! + 1) * scaleY).clamp(0.0, originalHeight.toDouble());

      regions.add(
        DetectedRegion(
          id: regionId,
          label: AppConfig.defaultTargetLabel,
          boundingBox: Rect.fromLTRB(left, top, right, bottom),
          pixelArea: area,
          regionConfidence: avgConfidence,
        ),
      );
      regionId++;
    }

    return regions;
  }
}
