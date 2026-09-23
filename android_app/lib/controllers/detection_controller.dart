import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../core/constants/app_constants.dart';
import '../data_models/model_metadata.dart' as legacy_meta;
import '../models/detection_result.dart';
import '../services/cod_inference_service.dart';
import '../services/cod_pipeline_service.dart';
import '../utils/exif_utils.dart';

enum DetectionStatus {
  idle,
  loading,
  processing,
  success,
  error,
}

// Controller managing single-image detection state, gallery picking, camera capture,
// and dynamic sensitivity threshold adjustment.

class DetectionController extends ChangeNotifier {
  final CodPipelineService? _pipeline;
  final CodInferenceService? _legacyService;
  final ImagePicker _picker = ImagePicker();

  DetectionStatus _status = DetectionStatus.idle;
  String? _errorMessage;

  Uint8List? _originalImageBytes;
  img.Image? _decodedImage;
  DetectionResult? _result;

  double _threshold = AppConstants.defaultThreshold;
  int _minRegionArea = AppConstants.defaultMinRegionAreaPixels;

  DetectionController({
    CodPipelineService? pipeline,
    CodInferenceService? inferenceService,
  })  : _pipeline = pipeline ?? (inferenceService != null ? null : CodPipelineService()),
        _legacyService = inferenceService;

  CodPipelineService get pipeline => _pipeline ?? CodPipelineService();

  // Backwards compatibility accessor for inference service
  CodInferenceService get inferenceService =>
      _legacyService ?? _PipelineToInferenceServiceAdapter(pipeline);

  DetectionStatus get status => _status;
  String? get errorMessage => _errorMessage;

  Uint8List? get originalImageBytes => _originalImageBytes;
  DetectionResult? get result => _result;

  double get threshold => _threshold;
  int get minRegionArea => _minRegionArea;

  // Selects an image from the device photo gallery
  Future<void> pickFromGallery() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 95,
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        await processImageBytes(bytes);
      }
    } catch (e) {
      _status = DetectionStatus.error;
      _errorMessage = 'Failed to load image from gallery: $e';
      notifyListeners();
    }
  }

  // Takes a new photo using the device camera
  Future<void> captureFromCamera() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 95,
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        await processImageBytes(bytes);
      }
    } catch (e) {
      _status = DetectionStatus.error;
      _errorMessage = 'Failed to capture photo from camera: $e';
      notifyListeners();
    }
  }

  // Decodes image bytes, fixes camera rotation, and runs the detection pipeline
  Future<void> processImageBytes(Uint8List bytes) async {
    _status = DetectionStatus.processing;
    _errorMessage = null;
    _originalImageBytes = bytes;
    notifyListeners();

    try {
      // Decode image
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        _status = DetectionStatus.error;
        _errorMessage = 'Could not decode image file format.';
        notifyListeners();
        return;
      }

      // Rotate image upright based on EXIF tag
      final oriented = ExifUtils.fixOrientation(decoded);
      _decodedImage = oriented;

      // Run detection and classification pipeline
      DetectionResult detectionResult;
      if (_legacyService != null) {
        final legacyRes = await _legacyService.runInference(
          oriented,
          threshold: _threshold,
          minRegionArea: _minRegionArea,
        );
        detectionResult = detectionResultFromLegacy(legacyRes);
      } else {
        detectionResult = await pipeline.processImage(
          oriented,
          threshold: _threshold,
          minRegionArea: _minRegionArea,
        );
      }

      _result = detectionResult;
      _status = DetectionStatus.success;
      notifyListeners();
    } catch (e) {
      _status = DetectionStatus.error;
      _errorMessage = 'Detection error: $e';
      notifyListeners();
    }
  }

  // Interactively updates the segmentation threshold and updates targets immediately
  Future<void> updateThreshold(double newThreshold) async {
    _threshold = newThreshold;
    notifyListeners();

    if (_result != null && _decodedImage != null) {
      final rethresholded = await pipeline.rethreshold(
        existingResult: _result!,
        originalImage: _decodedImage!,
        newThreshold: _threshold,
        minRegionArea: _minRegionArea,
      );
      _result = rethresholded;
      notifyListeners();
    }
  }

  // Interactively updates the minimum connected component pixel area
  Future<void> updateMinRegionArea(int newArea) async {
    _minRegionArea = newArea;
    notifyListeners();

    if (_result != null && _decodedImage != null) {
      final rethresholded = await pipeline.rethreshold(
        existingResult: _result!,
        originalImage: _decodedImage!,
        newThreshold: _threshold,
        minRegionArea: _minRegionArea,
      );
      _result = rethresholded;
      notifyListeners();
    }
  }

  // Clears the current detection results
  void clearResult() {
    _result = null;
    _originalImageBytes = null;
    _decodedImage = null;
    _status = DetectionStatus.idle;
    notifyListeners();
  }
}

// Adapts CodPipelineService to the legacy CodInferenceService interface
class _PipelineToInferenceServiceAdapter implements CodInferenceService {
  final CodPipelineService pipeline;
  _PipelineToInferenceServiceAdapter(this.pipeline);

  @override
  Future<void> initialize() async {}

  @override
  legacy_meta.ModelMetadata get metadata => legacy_meta.ModelMetadata(
        modelName: pipeline.dgnetService.metadata.modelName,
        version: '1.0.0',
        backboneName: 'MobileNetV3',
        inputShape: pipeline.dgnetService.metadata.inputShape,
        inputDataType: pipeline.dgnetService.metadata.inputDataType,
        outputShape: pipeline.dgnetService.metadata.outputShape,
        outputDataType: pipeline.dgnetService.metadata.outputDataType,
        quantizationMode: pipeline.dgnetService.metadata.quantizationMode,
        delegateType: pipeline.dgnetService.metadata.delegateType,
        fileSizeMb: pipeline.dgnetService.metadata.fileSizeMb,
      );

  @override
  Future<DetectionResult> runInference(
    img.Image inputImage, {
    double threshold = AppConstants.defaultThreshold,
    int minRegionArea = AppConstants.defaultMinRegionAreaPixels,
  }) {
    return pipeline.processImage(
      inputImage,
      threshold: threshold,
      minRegionArea: minRegionArea,
    );
  }

  @override
  void dispose() {}
}

// Converts a legacy DetectionResult into the new DetectionResult if needed
DetectionResult detectionResultFromLegacy(dynamic legacy) {
  if (legacy is DetectionResult) return legacy;
  return DetectionResult(
    originalWidth: legacy.originalWidth as int,
    originalHeight: legacy.originalHeight as int,
    maskWidth: legacy.maskWidth as int,
    maskHeight: legacy.maskHeight as int,
    probabilityMask: legacy.probabilityMask,
    binaryMask: legacy.binaryMask,
    regions: const [],
    preprocessingMs: (legacy.preprocessingMs as num).toDouble(),
    dgnetInferenceMs: (legacy.inferenceMs as num).toDouble(),
    postprocessingMs: (legacy.postprocessingMs as num).toDouble(),
    classificationInferenceMs: 0.0,
    totalMs: (legacy.totalMs as num).toDouble(),
  );
}
