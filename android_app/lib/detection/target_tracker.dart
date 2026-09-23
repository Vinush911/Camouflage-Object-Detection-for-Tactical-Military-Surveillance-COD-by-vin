import 'dart:math';
import 'dart:ui';
import '../models/target_region.dart';
import '../models/tracked_target.dart';

// Smooths bounding boxes and tracks targets from one frame to the next.
// It assigns stable IDs to objects, removes jitter, and keeps track of targets
// even if they are briefly blocked or missed for a few milliseconds.

class TargetTracker {
  // Smoothing factor between 0.0 and 1.0.
  // Lower values give smoother motion, while higher values react faster.
  final double smoothingFactor;

  // Minimum overlap required to match a new detection to an existing target
  final double iouThreshold;

  // How many milliseconds to remember a target after it disappears from view
  final int maxMissingDurationMs;

  int _nextTrackId = 1;
  final List<TrackedTarget> _activeTracks = [];

  TargetTracker({
    this.smoothingFactor = 0.45,
    this.iouThreshold = 0.25,
    this.maxMissingDurationMs = 400,
  });

  // Read-only list of current active tracked targets
  List<TrackedTarget> get activeTracks => List.unmodifiable(_activeTracks);

  // Updates active tracks with the newest detections from the current camera frame
  List<TrackedTarget> update(List<TargetRegion> rawDetections, {DateTime? timestamp}) {
    final now = timestamp ?? DateTime.now();

    if (rawDetections.isEmpty) {
      // If no detections in this frame, mark existing tracks as temporarily hidden
      final remaining = <TrackedTarget>[];
      for (final track in _activeTracks) {
        final age = now.difference(track.lastSeen).inMilliseconds;
        if (age <= maxMissingDurationMs) {
          remaining.add(track.copyWith(isOccluded: true));
        }
      }
      _activeTracks
        ..clear()
        ..addAll(remaining);
      return List.unmodifiable(_activeTracks);
    }

    final matchedTrackIndices = <int>{};
    final matchedDetectionIndices = <int>{};
    final updatedTracks = <TrackedTarget>[];

    // 1. Try to match incoming detections to existing tracked targets
    for (int d = 0; d < rawDetections.length; d++) {
      final det = rawDetections[d];
      int bestTrackIdx = -1;
      double bestScore = 0.0;

      for (int t = 0; t < _activeTracks.length; t++) {
        if (matchedTrackIndices.contains(t)) continue;

        final track = _activeTracks[t];
        final overlap = _calculateIoU(track.boundingBox, det.boundingBox);
        final proximity = _calculateCenterProximity(track.boundingBox, det.boundingBox);

        // Combined score prioritizing overlap, with distance as fallback for moving targets
        final score = overlap * 0.7 + proximity * 0.3;

        if (overlap >= iouThreshold || proximity >= 0.65) {
          if (score > bestScore) {
            bestScore = score;
            bestTrackIdx = t;
          }
        }
      }

      if (bestTrackIdx != -1) {
        matchedTrackIndices.add(bestTrackIdx);
        matchedDetectionIndices.add(d);

        final oldTrack = _activeTracks[bestTrackIdx];

        // Apply smooth transition between old and new box positions
        final smoothBox = _smoothRect(
          oldBox: oldTrack.boundingBox,
          newBox: det.boundingBox,
          factor: smoothingFactor,
        );

        final smoothConfidence =
            (oldTrack.confidence * (1.0 - smoothingFactor)) + (det.confidence * smoothingFactor);

        updatedTracks.add(
          TrackedTarget(
            trackId: oldTrack.trackId,
            boundingBox: smoothBox,
            confidence: smoothConfidence,
            label: det.label,
            firstSeen: oldTrack.firstSeen,
            lastSeen: now,
            framesTracked: oldTrack.framesTracked + 1,
            isOccluded: false,
          ),
        );
      }
    }

    // 2. Keep unmatched existing tracks if they were seen recently (within grace period)
    for (int t = 0; t < _activeTracks.length; t++) {
      if (!matchedTrackIndices.contains(t)) {
        final oldTrack = _activeTracks[t];
        final age = now.difference(oldTrack.lastSeen).inMilliseconds;
        if (age <= maxMissingDurationMs) {
          updatedTracks.add(oldTrack.copyWith(isOccluded: true));
        }
      }
    }

    // 3. Create new tracks for detections that did not match any previous target
    for (int d = 0; d < rawDetections.length; d++) {
      if (!matchedDetectionIndices.contains(d)) {
        final det = rawDetections[d];
        updatedTracks.add(
          TrackedTarget(
            trackId: _nextTrackId++,
            boundingBox: det.boundingBox,
            confidence: det.confidence,
            label: det.label,
            firstSeen: now,
            lastSeen: now,
            framesTracked: 1,
            isOccluded: false,
          ),
        );
      }
    }

    _activeTracks
      ..clear()
      ..addAll(updatedTracks);

    return List.unmodifiable(_activeTracks);
  }

  // Resets the tracking state and track ID counter
  void reset() {
    _activeTracks.clear();
    _nextTrackId = 1;
  }

  // Calculates the overlap percentage between two boxes (Intersection over Union)
  double _calculateIoU(Rect a, Rect b) {
    final intersection = a.intersect(b);
    if (intersection.width <= 0 || intersection.height <= 0) {
      return 0.0;
    }

    final areaA = a.width * a.height;
    final areaB = b.width * b.height;
    final areaIntersection = intersection.width * intersection.height;
    final areaUnion = areaA + areaB - areaIntersection;

    if (areaUnion <= 0) return 0.0;
    return areaIntersection / areaUnion;
  }

  // Measures how close the center points of two boxes are to each other (1.0 = identical center)
  double _calculateCenterProximity(Rect a, Rect b) {
    final dx = a.center.dx - b.center.dx;
    final dy = a.center.dy - b.center.dy;
    final distance = sqrt(dx * dx + dy * dy);

    final avgDimension = (a.width + a.height + b.width + b.height) / 4.0;
    if (avgDimension <= 0) return 0.0;

    return max(0.0, 1.0 - (distance / (avgDimension * 1.5)));
  }

  // Blends old and new box coordinates to prevent sudden jumping
  Rect _smoothRect({
    required Rect oldBox,
    required Rect newBox,
    required double factor,
  }) {
    final left = oldBox.left + (newBox.left - oldBox.left) * factor;
    final top = oldBox.top + (newBox.top - oldBox.top) * factor;
    final right = oldBox.right + (newBox.right - oldBox.right) * factor;
    final bottom = oldBox.bottom + (newBox.bottom - oldBox.bottom) * factor;

    return Rect.fromLTRB(left, top, right, bottom);
  }
}
