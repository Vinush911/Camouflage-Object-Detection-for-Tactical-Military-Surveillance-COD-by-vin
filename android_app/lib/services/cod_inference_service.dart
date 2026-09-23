import 'package:image/image.dart' as img;
import '../data_models/detection_result.dart';
import '../data_models/model_metadata.dart';

// Abstract interface for Camouflaged Object Detection models.
// By defining an interface, other models (like ResNet or EfficientNet versions)
// can easily be plugged in later without changing the UI code.

abstract class CodInferenceService {
  // Loads the neural network into device memory
  Future<void> initialize();

  // Runs the camouflage detection pipeline on an input image
  Future<DetectionResult> runInference(
    img.Image inputImage, {
    double threshold,
    int minRegionArea,
  });

  // Returns technical metadata about the model currently loaded
  ModelMetadata get metadata;

  // Releases interpreter and allocated resources
  void dispose();
}
