import 'package:image/image.dart' as img;
import '../models/target_region.dart';

// Extracts and crops individual target image patches from the original image
// based on the bounding boxes found during segmentation.

class RegionExtractor {
  // Crops the target region patch from the full-sized original image
  static img.Image? cropRegion({
    required img.Image originalImage,
    required TargetRegion region,
    double paddingFactor = 0.05,
  }) {
    final box = region.boundingBox;

    // Calculate optional padding around the target box for context
    final padX = box.width * paddingFactor;
    final padY = box.height * paddingFactor;

    final left = (box.left - padX).clamp(0.0, originalImage.width - 1.0).toInt();
    final top = (box.top - padY).clamp(0.0, originalImage.height - 1.0).toInt();
    final right = (box.right + padX).clamp(1.0, originalImage.width.toDouble()).toInt();
    final bottom = (box.bottom + padY).clamp(1.0, originalImage.height.toDouble()).toInt();

    final width = right - left;
    final height = bottom - top;

    if (width <= 0 || height <= 0) {
      return null;
    }

    return img.copyCrop(
      originalImage,
      x: left,
      y: top,
      width: width,
      height: height,
    );
  }
}
