import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../models/target_region.dart';

// Extracts and crops individual target image patches from the original image.
// Supports mask-gated cropping where pixels outside the DGNet segmentation mask
// are suppressed to black, producing a clean 224x224 RGB image for the classifier.

class RegionExtractor {
  // Legacy crop method that cuts a rectangular bounding box from the original image
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

  // Extracts a mask-gated target region:
  // 1. Calculates the bounding box around the target region with padding.
  // 2. Uses the DGNet binary mask to suppress background pixels outside the mask to black.
  // 3. Resizes the extracted region to 224 x 224 RGB for the classifier.
  static img.Image? extractMaskGatedRoi({
    required img.Image originalImage,
    required TargetRegion region,
    Uint8List? binaryMask,
    int maskWidth = 384,
    int maskHeight = 384,
    int targetWidth = 224,
    int targetHeight = 224,
    double paddingFactor = 0.05,
    bool suppressBackground = true,
  }) {
    final box = region.boundingBox;

    // Calculate padding around the target box for context
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

    // Create a new image to hold the cropped target
    final cropped = img.Image(width: width, height: height, numChannels: 3);

    // Check if we have a valid segmentation mask to suppress background
    final hasMask = binaryMask != null && binaryMask.isNotEmpty && suppressBackground;

    for (int y = 0; y < height; y++) {
      final origY = top + y;
      final maskY = hasMask
          ? ((origY * maskHeight) ~/ originalImage.height).clamp(0, maskHeight - 1)
          : 0;

      for (int x = 0; x < width; x++) {
        final origX = left + x;

        bool keepPixel = true;
        if (hasMask) {
          final maskX = ((origX * maskWidth) ~/ originalImage.width).clamp(0, maskWidth - 1);
          final maskIndex = maskY * maskWidth + maskX;
          if (maskIndex < binaryMask.length) {
            // Keep pixel only if DGNet marked it as foreground target (value > 0)
            keepPixel = binaryMask[maskIndex] > 0;
          }
        }

        if (keepPixel) {
          final pixel = originalImage.getPixel(origX, origY);
          cropped.setPixelRgb(x, y, pixel.r, pixel.g, pixel.b);
        } else {
          // Zero out background pixels outside the mask
          cropped.setPixelRgb(x, y, 0, 0, 0);
        }
      }
    }

    // Resize to target dimensions (224 x 224) if needed
    if (width == targetWidth && height == targetHeight) {
      return cropped;
    }

    return img.copyResize(
      cropped,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );
  }
}
