import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_app/models/target_region.dart';
import 'package:android_app/widgets/live_camera_overlay.dart';

void main() {
  group('Live Camera Overlay Tests', () {
    testWidgets('Renders LiveCameraOverlay without crashing for empty regions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiveCameraOverlay(
              regions: [],
              frameWidth: 640,
              frameHeight: 480,
            ),
          ),
        ),
      );

      expect(find.byType(LiveCameraOverlay), findsOneWidget);
    });

    testWidgets('Renders LiveCameraOverlay with classified target regions', (tester) async {
      final regions = [
        const TargetRegion(
          id: 1,
          boundingBox: Rect.fromLTWH(50, 50, 100, 100),
          pixelArea: 10000,
          regionConfidence: 0.91,
          classificationClass: 'Soldier',
          classificationConfidence: 0.94,
        ),
        const TargetRegion(
          id: 2,
          boundingBox: Rect.fromLTWH(200, 150, 120, 120),
          pixelArea: 14400,
          regionConfidence: 0.88,
          classificationClass: 'Tank',
          classificationConfidence: 0.96,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveCameraOverlay(
              regions: regions,
              frameWidth: 640,
              frameHeight: 480,
            ),
          ),
        ),
      );

      expect(find.byType(LiveCameraOverlay), findsOneWidget);
    });
  });
}
