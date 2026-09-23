import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_app/models/tracked_target.dart';
import 'package:android_app/services/tactical_alert_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TacticalAlertService Tests', () {
    test('Triggers haptic and acoustic alert when a high confidence target is first locked', () {
      int hapticCount = 0;
      int soundCount = 0;

      final service = TacticalAlertService(
        lockConfidenceThreshold: 0.70,
        onHapticAlert: () => hapticCount++,
        onSoundAlert: () => soundCount++,
      );

      final now = DateTime.now();
      final target = TrackedTarget(
        trackId: 1,
        boundingBox: const Rect.fromLTWH(50, 50, 60, 60),
        confidence: 0.85, // Above 70% threshold
        label: 'Camouflage Target',
        firstSeen: now,
        lastSeen: now,
        framesTracked: 1,
        isOccluded: false,
      );

      service.processTargets([target]);

      // Both haptics and sonar ping should have triggered once
      expect(hapticCount, 1);
      expect(soundCount, 1);
    });

    test('Does not buzz continuously on every frame for the same target (debouncing)', () {
      int hapticCount = 0;
      int soundCount = 0;

      final service = TacticalAlertService(
        lockConfidenceThreshold: 0.70,
        onHapticAlert: () => hapticCount++,
        onSoundAlert: () => soundCount++,
      );

      final now = DateTime.now();
      final target = TrackedTarget(
        trackId: 1,
        boundingBox: const Rect.fromLTWH(50, 50, 60, 60),
        confidence: 0.88,
        label: 'Camouflage Target',
        firstSeen: now,
        lastSeen: now,
        framesTracked: 1,
      );

      // Frame 1: Initial detection
      service.processTargets([target]);
      expect(hapticCount, 1);
      expect(soundCount, 1);

      // Frame 2: Same target remains in view
      service.processTargets([
        target.copyWith(framesTracked: 2, lastSeen: now.add(const Duration(milliseconds: 50))),
      ]);

      // Counts should not have increased
      expect(hapticCount, 1);
      expect(soundCount, 1);

      // Frame 3: Same target still in view
      service.processTargets([
        target.copyWith(framesTracked: 3, lastSeen: now.add(const Duration(milliseconds: 100))),
      ]);
      expect(hapticCount, 1);
      expect(soundCount, 1);
    });

    test('Does not alert for targets below confidence threshold or occluded targets', () {
      int hapticCount = 0;
      int soundCount = 0;

      final service = TacticalAlertService(
        lockConfidenceThreshold: 0.70,
        onHapticAlert: () => hapticCount++,
        onSoundAlert: () => soundCount++,
      );

      final now = DateTime.now();

      // Low confidence target (60%)
      final lowConfTarget = TrackedTarget(
        trackId: 1,
        boundingBox: const Rect.fromLTWH(10, 10, 30, 30),
        confidence: 0.60,
        label: 'Camouflage Target',
        firstSeen: now,
        lastSeen: now,
        framesTracked: 1,
      );

      service.processTargets([lowConfTarget]);
      expect(hapticCount, 0);
      expect(soundCount, 0);

      // Occluded target (high confidence but currently hidden)
      final occludedTarget = TrackedTarget(
        trackId: 2,
        boundingBox: const Rect.fromLTWH(50, 50, 30, 30),
        confidence: 0.95,
        label: 'Camouflage Target',
        firstSeen: now,
        lastSeen: now,
        framesTracked: 1,
        isOccluded: true,
      );

      service.processTargets([occludedTarget]);
      expect(hapticCount, 0);
      expect(soundCount, 0);
    });

    test('Allows re-alerting when an old target leaves the frame and returns later', () {
      int hapticCount = 0;
      int soundCount = 0;

      final service = TacticalAlertService(
        lockConfidenceThreshold: 0.70,
        onHapticAlert: () => hapticCount++,
        onSoundAlert: () => soundCount++,
      );

      final now = DateTime.now();
      final target = TrackedTarget(
        trackId: 1,
        boundingBox: const Rect.fromLTWH(50, 50, 60, 60),
        confidence: 0.85,
        label: 'Camouflage Target',
        firstSeen: now,
        lastSeen: now,
        framesTracked: 1,
      );

      // Frame 1: Target enters frame
      service.processTargets([target]);
      expect(hapticCount, 1);

      // Frame 2: Target leaves frame (empty list)
      service.processTargets([]);
      expect(hapticCount, 1);

      // Frame 3: Target re-enters frame later
      service.processTargets([target]);
      expect(hapticCount, 2);
    });

    test('Mute toggle suppresses acoustic sound but preserves haptic pulse', () {
      int hapticCount = 0;
      int soundCount = 0;

      final service = TacticalAlertService(
        lockConfidenceThreshold: 0.70,
        isAudioMuted: false,
        onHapticAlert: () => hapticCount++,
        onSoundAlert: () => soundCount++,
      );

      expect(service.isAudioMuted, false);

      // Toggle to muted
      service.toggleMute();
      expect(service.isAudioMuted, true);

      final now = DateTime.now();
      final target = TrackedTarget(
        trackId: 5,
        boundingBox: const Rect.fromLTWH(20, 20, 40, 40),
        confidence: 0.85,
        label: 'Camouflage Target',
        firstSeen: now,
        lastSeen: now,
        framesTracked: 1,
      );

      service.processTargets([target]);

      // Haptic should fire, sound should be muted
      expect(hapticCount, 1);
      expect(soundCount, 0);

      // Toggle back to unmuted
      service.toggleMute();
      expect(service.isAudioMuted, false);
    });
  });
}
