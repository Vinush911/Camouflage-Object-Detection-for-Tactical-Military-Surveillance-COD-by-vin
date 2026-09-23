import 'dart:ui';
import 'target_region.dart';

// Represents a target tracked smoothly across multiple video frames.
// It keeps a continuous ID, smoothly updates the box position, and tracks how long the target has been watched.

class TrackedTarget {
  // Unique identification number for this target (for example: 1, 2, 3)
  final int trackId;

  // The smoothly positioned box around the target
  final Rect boundingBox;

  // The confidence score of the target (from 0.0 to 1.0)
  final double confidence;

  // The detected class name (such as 'Camouflaged Target' or 'Soldier')
  final String label;

  // Time when this target was first spotted
  final DateTime firstSeen;

  // Time when this target was last confirmed in a frame
  final DateTime lastSeen;

  // Total number of consecutive frames this target has been seen
  final int framesTracked;

  // True if the target was temporarily hidden or missed in the latest frame
  final bool isOccluded;

  const TrackedTarget({
    required this.trackId,
    required this.boundingBox,
    required this.confidence,
    required this.label,
    required this.firstSeen,
    required this.lastSeen,
    required this.framesTracked,
    this.isOccluded = false,
  });

  // Returns formatted target identifier text like "TARGET #01"
  String get formattedTrackId {
    final padded = trackId.toString().padLeft(2, '0');
    return 'TARGET #$padded';
  }

  // Returns how long this target has been continuously tracked in seconds
  String get timeOnTarget {
    final duration = DateTime.now().difference(firstSeen);
    final seconds = duration.inMilliseconds / 1000.0;
    return '${seconds.toStringAsFixed(1)}s';
  }

  // Helper method to create an updated copy of this tracked target
  TrackedTarget copyWith({
    Rect? boundingBox,
    double? confidence,
    String? label,
    DateTime? lastSeen,
    int? framesTracked,
    bool? isOccluded,
  }) {
    return TrackedTarget(
      trackId: trackId,
      boundingBox: boundingBox ?? this.boundingBox,
      confidence: confidence ?? this.confidence,
      label: label ?? this.label,
      firstSeen: firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      framesTracked: framesTracked ?? this.framesTracked,
      isOccluded: isOccluded ?? this.isOccluded,
    );
  }

  // Converts this tracked target back into a standard TargetRegion for compatibility
  TargetRegion toTargetRegion() {
    return TargetRegion(
      id: trackId,
      boundingBox: boundingBox,
      regionConfidence: confidence,
      classificationConfidence: confidence,
      label: label,
      pixelArea: (boundingBox.width * boundingBox.height).round(),
    );
  }
}
