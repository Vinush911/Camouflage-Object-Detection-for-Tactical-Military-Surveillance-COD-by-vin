import 'package:image/image.dart' as img;

// Helper utilities for fixing camera photo orientation.
// When phones take photos, the camera sensor might save the image rotated,
// with an EXIF tag indicating the true upright angle.
// This utility rotates the image so it is upright before processing.

class ExifUtils {
  // Bakes the EXIF orientation into the image pixels so it faces upright.
  static img.Image fixOrientation(img.Image image) {
    // The image library provides bakeOrientation to correctly orient pixels
    return img.bakeOrientation(image);
  }
}
