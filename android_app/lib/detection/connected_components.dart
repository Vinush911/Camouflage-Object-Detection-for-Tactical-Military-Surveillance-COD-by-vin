import 'dart:typed_data';
import 'dart:ui';
import '../models/target_region.dart';

// Finds disconnected camouflaged objects in a binary segmentation mask.
// When an image contains multiple targets (for example, two soldiers and one tank),
// this analyzer locates each group of connected pixels, calculates its boundary,
// and filters out tiny pixel noise.

class ConnectedComponentResult {
  final List<TargetRegion> regions;
  final double elapsedMilliseconds;

  const ConnectedComponentResult({
    required this.regions,
    required this.elapsedMilliseconds,
  });
}

class ConnectedComponents {
  // Analyzes the binary mask to find and extract separate target regions
  static ConnectedComponentResult extractRegions({
    required Uint8List binaryMask,
    required Float32List probabilityMask,
    required int maskWidth,
    required int maskHeight,
    required int originalWidth,
    required int originalHeight,
    required int minRegionArea,
    Uint8List? visitedBuffer,
    Int32List? scratchQueue,
  }) {
    final stopwatch = Stopwatch()..start();

    final totalPixels = maskWidth * maskHeight;
    // Reuse the provided visited memory buffer or create a new one
    final visited = visitedBuffer ?? Uint8List(totalPixels);
    if (visitedBuffer != null) {
      visited.fillRange(0, totalPixels, 0);
    }

    final queue = scratchQueue ?? Int32List(totalPixels);
    final regions = <TargetRegion>[];
    int currentId = 1;

    // Scaling factors to convert mask coordinates back to original image coordinates
    final scaleX = originalWidth / maskWidth.toDouble();
    final scaleY = originalHeight / maskHeight.toDouble();

    // 8-direction neighbor offsets (horizontal, vertical, and diagonal)
    const dx = [0, 0, 1, -1, 1, -1, 1, -1];
    const dy = [1, -1, 0, 0, 1, 1, -1, -1];

    for (int y = 0; y < maskHeight; y++) {
      for (int x = 0; x < maskWidth; x++) {
        final startIndex = y * maskWidth + x;

        // Skip background pixels or pixels we already visited
        if (binaryMask[startIndex] == 0 || visited[startIndex] == 1) {
          continue;
        }

        // Start flood-fill exploration for this new connected group
        int pixelCount = 0;
        double sumProbability = 0.0;
        int minX = x;
        int maxX = x;
        int minY = y;
        int maxY = y;

        int queueHead = 0;
        int queueTail = 0;
        queue[queueTail++] = startIndex;
        visited[startIndex] = 1;

        while (queueHead < queueTail) {
          final index = queue[queueHead++];
          final curX = index % maskWidth;
          final curY = index ~/ maskWidth;

          pixelCount++;
          sumProbability += probabilityMask[index];

          if (curX < minX) minX = curX;
          if (curX > maxX) maxX = curX;
          if (curY < minY) minY = curY;
          if (curY > maxY) maxY = curY;

          // Check all 8 neighbors
          for (int dir = 0; dir < 8; dir++) {
            final nx = curX + dx[dir];
            final ny = curY + dy[dir];

            if (nx >= 0 && nx < maskWidth && ny >= 0 && ny < maskHeight) {
              final neighborIndex = ny * maskWidth + nx;
              if (binaryMask[neighborIndex] > 0 && visited[neighborIndex] == 0) {
                visited[neighborIndex] = 1;
                queue[queueTail++] = neighborIndex;
              }
            }
          }
        }

        // Ignore small speckles and tiny noise blobs
        if (pixelCount < minRegionArea) {
          continue;
        }

        // Calculate the mean probability score across this target region
        final meanScore = sumProbability / pixelCount;

        // Scale bounding box coordinates to match original full-size image
        final left = (minX * scaleX).clamp(0.0, originalWidth.toDouble());
        final top = (minY * scaleY).clamp(0.0, originalHeight.toDouble());
        final right = ((maxX + 1) * scaleX).clamp(0.0, originalWidth.toDouble());
        final bottom = ((maxY + 1) * scaleY).clamp(0.0, originalHeight.toDouble());

        regions.add(
          TargetRegion(
            id: currentId++,
            boundingBox: Rect.fromLTRB(left, top, right, bottom),
            pixelArea: pixelCount,
            regionConfidence: meanScore,
          ),
        );
      }
    }

    stopwatch.stop();

    return ConnectedComponentResult(
      regions: regions,
      elapsedMilliseconds: stopwatch.elapsedMicroseconds / 1000.0,
    );
  }
}
