import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_app/models/target_region.dart';
import 'package:android_app/models/tracked_target.dart';
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

    testWidgets('Renders LiveCameraOverlay with TrackedTargets across threat color levels', (tester) async {
      final now = DateTime.now();
      final tracked = [
        // 1. Amber Anomaly (55% confidence)
        TrackedTarget(
          trackId: 1,
          boundingBox: const Rect.fromLTWH(20, 20, 60, 60),
          confidence: 0.55,
          label: 'Camouflage Target',
          firstSeen: now,
          lastSeen: now,
          framesTracked: 2,
        ),
        // 2. Tactical Green Lock (70% confidence)
        TrackedTarget(
          trackId: 2,
          boundingBox: const Rect.fromLTWH(120, 50, 80, 80),
          confidence: 0.70,
          label: 'Camouflage Target',
          firstSeen: now,
          lastSeen: now,
          framesTracked: 5,
        ),
        // 3. Red Flashing High Threat (92% confidence)
        TrackedTarget(
          trackId: 3,
          boundingBox: const Rect.fromLTWH(250, 80, 100, 100),
          confidence: 0.92,
          label: 'Camouflage Target',
          firstSeen: now,
          lastSeen: now,
          framesTracked: 10,
        ),
        // 4. Amber Occluded / Searching Target
        TrackedTarget(
          trackId: 4,
          boundingBox: const Rect.fromLTWH(100, 200, 50, 50),
          confidence: 0.85,
          label: 'Camouflage Target',
          firstSeen: now,
          lastSeen: now,
          framesTracked: 3,
          isOccluded: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveCameraOverlay(
              trackedTargets: tracked,
              frameWidth: 640,
              frameHeight: 480,
              pulseValue: 0.85,
            ),
          ),
        ),
      );

      expect(find.byType(LiveCameraOverlay), findsOneWidget);
    });
  });
}
