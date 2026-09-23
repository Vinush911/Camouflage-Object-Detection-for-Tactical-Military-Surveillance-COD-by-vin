import 'dart:ui';

// Represents one individual camouflaged target found in an image.
// When an image contains multiple objects (for example, two soldiers and one tank),
// each separate object is stored as its own TargetRegion.

class TargetRegion {
  // Identification number starting from 1 (for example: Target 1, Target 2)
  final int id;

  // The bounding box around the object in original image pixel coordinates
  final Rect boundingBox;

  // Count of foreground pixels belonging to this connected object
  final int pixelArea;

  // Average probability from the segmentation mask for this region (between 0.0 and 1.0).
  // This shows how confident DGNet is that this area is camouflaged foreground.
  // It is completely separate from the classification category confidence.
  final double regionConfidence;

  // Predicted category name from the classifier model (for example: "Soldier" or "Tank").
  // This is null if the classifier model is unavailable or has not been run yet.
  final String? classificationClass;

  // Prediction confidence from the classifier model (between 0.0 and 1.0).
  // This is null if the classifier model is unavailable.
  final double? classificationConfidence;

  const TargetRegion({
    required this.id,
    required this.boundingBox,
    required this.pixelArea,
    required this.regionConfidence,
    String? label,
    String? classificationClass,
    this.classificationConfidence,
  }) : classificationClass = classificationClass ?? (label != 'Camouflaged Target' ? label : null);

  // Returns true if this target has been classified by the classifier model
  bool get isClassified => classificationClass != null;

  // Display label: uses the classified name if available, otherwise a generic label
  String get displayLabel {
    if (classificationClass != null && classificationClass!.isNotEmpty) {
      return classificationClass!;
    }
    return 'Camouflaged Target';
  }

  // Alias for displayLabel for backwards compatibility
  String get label => displayLabel;

  // Overall confidence: uses the classification score if available, or the segmentation score
  double get confidence => classificationConfidence ?? regionConfidence;

  // Formatted string for the segmentation region confidence (for example: "91.4%")
  String get formattedRegionConfidence =>
      '${(regionConfidence * 100).toStringAsFixed(1)}%';

  // Formatted string for the classification confidence (for example: "94.2%")
  String get formattedClassificationConfidence {
    if (classificationConfidence != null) {
      return '${(classificationConfidence! * 100).toStringAsFixed(1)}%';
    }
    return 'Unavailable';
  }

  // Creates a copy of this region with updated classification results
  TargetRegion copyWithClassification({
    required String className,
    required double confidence,
  }) {
    return TargetRegion(
      id: id,
      boundingBox: boundingBox,
      pixelArea: pixelArea,
      regionConfidence: regionConfidence,
      classificationClass: className,
      classificationConfidence: confidence,
    );
  }
}
