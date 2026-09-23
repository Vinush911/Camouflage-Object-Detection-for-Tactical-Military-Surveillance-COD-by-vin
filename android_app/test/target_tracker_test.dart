import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_app/detection/target_tracker.dart';
import 'package:android_app/models/target_region.dart';

void main() {
  group('TargetTracker Tests', () {
    test('Assigns new track ID to first detected target', () {
      final tracker = TargetTracker();

      final detections = [
        const TargetRegion(
          id: 1,
          boundingBox: Rect.fromLTWH(100, 100, 50, 50),
          pixelArea: 2500,
          regionConfidence: 0.85,
          label: 'Camouflage Target',
        ),
      ];

      final tracks = tracker.update(detections);

      expect(tracks.length, 1);
      expect(tracks.first.trackId, 1);
      expect(tracks.first.isOccluded, false);
      expect(tracks.first.framesTracked, 1);
      expect(tracks.first.formattedTrackId, 'TARGET #01');
    });

    test('Preserves target ID across consecutive frames for moving target', () {
      final tracker = TargetTracker(smoothingFactor: 0.5);

      final startTime = DateTime(2026, 1, 1, 12, 0, 0);

      // Frame 1: target at (100, 100)
      final frame1 = [
        const TargetRegion(
          id: 1,
          boundingBox: Rect.fromLTWH(100, 100, 60, 60),
          pixelArea: 3600,
          regionConfidence: 0.80,
          label: 'Soldier',
        ),
      ];
      final tracks1 = tracker.update(frame1, timestamp: startTime);
      expect(tracks1.length, 1);
      expect(tracks1.first.trackId, 1);
      expect(tracks1.first.boundingBox.left, 100.0);

      // Frame 2: target moves slightly to (110, 105)
      final frame2 = [
        const TargetRegion(
          id: 1,
          boundingBox: Rect.fromLTWH(110, 105, 60, 60),
          pixelArea: 3600,
          regionConfidence: 0.90,
          label: 'Soldier',
        ),
      ];
      final tracks2 = tracker.update(
        frame2,
        timestamp: startTime.add(const Duration(milliseconds: 50)),
      );

      expect(tracks2.length, 1);
      // The track ID should stay exactly the same
      expect(tracks2.first.trackId, 1);
      expect(tracks2.first.framesTracked, 2);

      // Coordinates should be smoothed between 100 and 110 (105.0)
      expect(tracks2.first.boundingBox.left, 105.0);
      expect(tracks2.first.boundingBox.top, 102.5);
    });

    test('Smooths bounding box coordinates to reduce jitter', () {
      final tracker = TargetTracker(smoothingFactor: 0.4);
      final now = DateTime.now();

      // Initial detection
      tracker.update([
        const TargetRegion(
          id: 1,
          boundingBox: Rect.fromLTWH(50, 50, 40, 40),
          pixelArea: 1600,
          regionConfidence: 0.8,
        ),
      ], timestamp: now);

      // Jitter jump to 70
      final updated = tracker.update([
        const TargetRegion(
          id: 1,
          boundingBox: Rect.fromLTWH(70, 50, 40, 40),
          pixelArea: 1600,
          regionConfidence: 0.8,
        ),
      ], timestamp: now.add(const Duration(milliseconds: 30)));

      // 50 + (70 - 50) * 0.4 = 58.0
      expect(updated.first.boundingBox.left, closeTo(58.0, 0.01));
    });

    test('Keeps temporarily occluded targets active during grace period', () {
      final tracker = TargetTracker(maxMissingDurationMs: 400);
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      // Target detected in frame 1
      tracker.update([
        const TargetRegion(
          id: 1,
          boundingBox: Rect.fromLTWH(100, 100, 50, 50),
          pixelArea: 2500,
          regionConfidence: 0.9,
        ),
      ], timestamp: t0);

      // Frame 2: 200ms later, no detections (target briefly blocked or lost)
      final tracksAt200ms = tracker.update(
        [],
        timestamp: t0.add(const Duration(milliseconds: 200)),
      );

      // Target should still be retained but flagged as occluded
      expect(tracksAt200ms.length, 1);
      expect(tracksAt200ms.first.trackId, 1);
      expect(tracksAt200ms.first.isOccluded, true);

      // Frame 3: 500ms later (exceeding 400ms grace period)
      final tracksAt500ms = tracker.update(
        [],
        timestamp: t0.add(const Duration(milliseconds: 500)),
      );

      // Target should now be pruned away
      expect(tracksAt500ms.isEmpty, true);
    });

    test('Reset clears all active tracks and restarts ID counter', () {
      final tracker = TargetTracker();

      tracker.update([
        const TargetRegion(
          id: 1,
          boundingBox: Rect.fromLTWH(10, 10, 20, 20),
          pixelArea: 400,
          regionConfidence: 0.9,
        ),
      ]);

      expect(tracker.activeTracks.length, 1);
      expect(tracker.activeTracks.first.trackId, 1);

      tracker.reset();
      expect(tracker.activeTracks.isEmpty, true);

      // Next new target should start again at trackId 1
      final tracksAfterReset = tracker.update([
        const TargetRegion(
          id: 99,
          boundingBox: Rect.fromLTWH(80, 80, 20, 20),
          pixelArea: 400,
          regionConfidence: 0.9,
        ),
      ]);
      expect(tracksAfterReset.first.trackId, 1);
    });
  });
}
