import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_app/utils/connected_components.dart';

void main() {
  group('Connected Component Analyzer Tests', () {
    test('detects multiple disconnected targets and filters out small noise', () {
      final analyzer = ConnectedComponentAnalyzer();

      const maskW = 100;
      const maskH = 100;
      const totalPixels = maskW * maskH;

      final binMask = Uint8List(totalPixels);
      final probMask = Float32List(totalPixels);

      // Target 1: Box from x=10..30, y=10..30 (Area = 21 * 21 = 441 pixels)
      // High confidence values (0.90)
      for (var y = 10; y <= 30; y++) {
        for (var x = 10; x <= 30; x++) {
          final idx = y * maskW + x;
          binMask[idx] = 255;
          probMask[idx] = 0.90;
        }
      }

      // Target 2: Box from x=60..80, y=60..80 (Area = 21 * 21 = 441 pixels)
      // Moderate confidence values (0.75)
      for (var y = 60; y <= 80; y++) {
        for (var x = 60; x <= 80; x++) {
          final idx = y * maskW + x;
          binMask[idx] = 255;
          probMask[idx] = 0.75;
        }
      }

      // Noise blob: Tiny 2x2 patch from x=45..46, y=45..46 (Area = 4 pixels)
      for (var y = 45; y <= 46; y++) {
        for (var x = 45; x <= 46; x++) {
          final idx = y * maskW + x;
          binMask[idx] = 255;
          probMask[idx] = 0.60;
        }
      }

      // Original photo is 1000x1000 (10x scaling factor)
      final regions = analyzer.analyze(
        binaryMask: binMask,
        probabilityMask: probMask,
        maskWidth: maskW,
        maskHeight: maskH,
        originalWidth: 1000,
        originalHeight: 1000,
        minArea: 20, // Min area of 20 will filter out the 4-pixel noise blob
      );

      // We expect exactly 2 distinct targets detected
      expect(regions.length, equals(2));

      // Check Target 1 details
      final target1 = regions[0];
      expect(target1.label, equals('Camouflaged Target'));
      expect(target1.pixelArea, equals(441));
      expect(target1.regionConfidence, closeTo(0.90, 0.01));

      // Bounding box should scale by 10x
      expect(target1.boundingBox.left, closeTo(100.0, 1.0));
      expect(target1.boundingBox.top, closeTo(100.0, 1.0));
      expect(target1.boundingBox.right, closeTo(310.0, 1.0));
      expect(target1.boundingBox.bottom, closeTo(310.0, 1.0));

      // Check Target 2 details
      final target2 = regions[1];
      expect(target2.pixelArea, equals(441));
      expect(target2.regionConfidence, closeTo(0.75, 0.01));
      expect(target2.boundingBox.left, closeTo(600.0, 1.0));
      expect(target2.boundingBox.top, closeTo(600.0, 1.0));
    });

    test('returns empty list when no foreground pixels exist', () {
      final analyzer = ConnectedComponentAnalyzer();

      final binMask = Uint8List(100 * 100); // all zeros
      final probMask = Float32List(100 * 100);

      final regions = analyzer.analyze(
        binaryMask: binMask,
        probabilityMask: probMask,
        maskWidth: 100,
        maskHeight: 100,
        originalWidth: 1000,
        originalHeight: 1000,
      );

      expect(regions, isEmpty);
    });
  });
}
