// Central configuration file for the COD Vision application.
// All model settings, thresholds, and tunable numbers are kept in this one place.

class AppConfig {
  // Path to the TFLite model inside the app assets folder
  static const String modelAssetPath =
      'assets/models/dgnet_mobilenet_v3_384.tflite';

  // Model input dimensions expected by DGNet
  static const int inputWidth = 384;
  static const int inputHeight = 384;
  static const int inputChannels = 3;

  // Normalization value: we divide pixel values (0 to 255) by 255.0
  // to get numbers between 0.0 and 1.0, which the model expects.
  static const double pixelNormalizationScale = 255.0;

  // Default cutoff score for deciding if a pixel is a target.
  // The model outputs probabilities between 0.0 and 1.0.
  // Pixels with a score greater than or equal to this cutoff are marked as foreground.
  static const double defaultThreshold = 0.30;

  // Minimum number of connected pixels required to count as a real target.
  // Any tiny group of pixels smaller than this is treated as background noise and removed.
  static const int defaultMinRegionAreaPixels = 120;

  // Label to show for detected targets.
  // Note: The current model performs binary detection only (target vs background).
  // We use this neutral label because the model does not classify soldiers vs tanks.
  static const String defaultTargetLabel = 'Camouflaged Target';

  // Number of dummy runs before measuring benchmark times, to let the model warm up
  static const int benchmarkWarmupRuns = 3;

  // Number of timed runs to calculate average performance
  static const int benchmarkMeasuredRuns = 10;

  // Maximum number of inferences per second in live camera mode to prevent lag
  static const int liveMaxInferenceFps = 8;
}
