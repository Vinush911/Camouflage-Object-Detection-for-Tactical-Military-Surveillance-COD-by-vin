// Central application constants and model file locations.
// All asset paths are kept in this single location to make swapping models easy.

class AppConstants {
  // DGNet segmentation model folder and file paths
  static const String dgnetModelDir = 'assets/models/dgnet';
  static const String dgnetModelPath = 'assets/models/dgnet/model.tflite';
  static const String dgnetConfigPath = 'assets/models/dgnet/model_config.json';

  // Target classifier model folder and file paths
  static const String classifierModelDir = 'assets/models/classifier';
  static const String classifierModelPath = 'assets/models/classifier/model.tflite';
  static const String classifierConfigPath = 'assets/models/classifier/model_config.json';

  // Default segmentation threshold for turning probabilities into foreground
  static const double defaultThreshold = 0.30;

  // Minimum connected pixel area to count as a detected target
  static const int defaultMinRegionAreaPixels = 120;

  // Fallback label when classifier is not available
  static const String defaultTargetLabel = 'Camouflaged Target';

  // Default number of warm-up runs before taking benchmark measurements
  static const int defaultWarmupRuns = 3;

  // Default number of timed runs for calculating latency averages
  static const int defaultBenchmarkRuns = 10;

  // Live camera target frames per second to prevent phone overheating
  static const int defaultLiveFps = 8;
}
