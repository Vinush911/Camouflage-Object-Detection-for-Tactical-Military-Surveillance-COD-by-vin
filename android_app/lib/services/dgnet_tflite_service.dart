import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import '../config/app_config.dart';
import '../data_models/detection_result.dart';
import '../data_models/model_metadata.dart';
import 'cod_inference_service.dart';
import 'image_preprocessor.dart';
import 'mask_postprocessor.dart';

// Custom error when model tensor shapes do not match expected dimensions
class UnsupportedTensorException implements Exception {
  final String message;
  UnsupportedTensorException(this.message);

  @override
  String toString() => 'UnsupportedTensorException: $message';
}

// Implements the COD inference service using TensorFlow Lite on Android.
// This loads the TFLite model, validates input and output tensors,
// runs inference on the neural network, and measures timings.

class DgnetTfliteService implements CodInferenceService {
  tfl.Interpreter? _interpreter;
  final ImagePreprocessor _preprocessor = ImagePreprocessor();
  final MaskPostprocessor _postprocessor = MaskPostprocessor();
  ModelMetadata _metadata = ModelMetadata.dgnetMobileNetV3();

  bool _isInitialized = false;

  @override
  ModelMetadata get metadata => _metadata;

  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('[COD] Loading TFLite model from ${AppConfig.modelAssetPath}...');

    try {
      // Configure TFLite options (e.g. 4 CPU threads)
      final options = tfl.InterpreterOptions()..threads = 4;

      _interpreter = await tfl.Interpreter.fromAsset(
        AppConfig.modelAssetPath,
        options: options,
      );

      // Verify tensor shapes against our known architecture
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();

      if (inputTensors.isEmpty || outputTensors.isEmpty) {
        throw UnsupportedTensorException(
          'Model has no input or output tensors.',
        );
      }

      final inTensor = inputTensors[0];
      final outTensor = outputTensors[0];

      debugPrint('[COD] Input Tensor: name=${inTensor.name}, shape=${inTensor.shape}, type=${inTensor.type}');
      debugPrint('[COD] Output Tensor: name=${outTensor.name}, shape=${outTensor.shape}, type=${outTensor.type}');

      // Validate input shape: expected [1, 384, 384, 3]
      if (inTensor.shape.length != 4 ||
          inTensor.shape[1] != AppConfig.inputHeight ||
          inTensor.shape[2] != AppConfig.inputWidth ||
          inTensor.shape[3] != AppConfig.inputChannels) {
        throw UnsupportedTensorException(
          'Unexpected input tensor shape: ${inTensor.shape}. '
          'Expected [1, ${AppConfig.inputHeight}, ${AppConfig.inputWidth}, ${AppConfig.inputChannels}].',
        );
      }

      // Validate output shape: expected [1, 384, 384, 1]
      if (outTensor.shape.length != 4 ||
          outTensor.shape[1] != AppConfig.inputHeight ||
          outTensor.shape[2] != AppConfig.inputWidth ||
          outTensor.shape[3] != 1) {
        throw UnsupportedTensorException(
          'Unexpected output tensor shape: ${outTensor.shape}. '
          'Expected [1, ${AppConfig.inputHeight}, ${AppConfig.inputWidth}, 1].',
        );
      }

      // Update metadata with actual runtime tensor information
      _metadata = ModelMetadata(
        modelName: 'DGNet-MobileNetV3',
        version: '1.0.0-tactical',
        backboneName: 'MobileNetV3-Large',
        inputShape: List<int>.from(inTensor.shape),
        inputDataType: inTensor.type.toString(),
        outputShape: List<int>.from(outTensor.shape),
        outputDataType: outTensor.type.toString(),
        quantizationMode: 'Optimized FP32',
        delegateType: 'CPU (4 Threads)',
        fileSizeMb: 3.95,
      );

      _isInitialized = true;
      debugPrint('[COD] DGNet model initialized successfully.');
    } catch (e) {
      debugPrint('[COD] Failed to initialize TFLite model: $e');
      rethrow;
    }
  }

  @override
  Future<DetectionResult> runInference(
    img.Image inputImage, {
    double threshold = AppConfig.defaultThreshold,
    int minRegionArea = AppConfig.defaultMinRegionAreaPixels,
  }) async {
    if (!_isInitialized || _interpreter == null) {
      await initialize();
    }

    final originalWidth = inputImage.width;
    final originalHeight = inputImage.height;

    // 1. Preprocessing: resize to 384x384 and normalize to 0.0-1.0
    final preprocessed = _preprocessor.process(inputImage);

    // 2. Prepare output buffer with shape [1, 384, 384, 1]
    var rawOutput = List.generate(
      1,
      (_) => List.generate(
        AppConfig.inputHeight,
        (_) => List.generate(
          AppConfig.inputWidth,
          (_) => List<double>.filled(1, 0.0),
        ),
      ),
    );

    // 3. Inference: run through TFLite interpreter and measure pure inference time
    final inferenceStopwatch = Stopwatch()..start();
    _interpreter!.run(preprocessed.tensorInput, rawOutput);
    inferenceStopwatch.stop();
    final inferenceMs = inferenceStopwatch.elapsedMicroseconds / 1000.0;

    // 4. Postprocessing: thresholding, connected components, bounding boxes
    final postprocessed = _postprocessor.process(
      rawOutput: rawOutput,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      threshold: threshold,
      minRegionArea: minRegionArea,
    );

    final totalMs = preprocessed.elapsedMilliseconds +
        inferenceMs +
        postprocessed.elapsedMilliseconds;

    return DetectionResult(
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      maskWidth: AppConfig.inputWidth,
      maskHeight: AppConfig.inputHeight,
      probabilityMask: postprocessed.probabilityMask,
      binaryMask: postprocessed.binaryMask,
      regions: postprocessed.regions,
      preprocessingMs: preprocessed.elapsedMilliseconds,
      inferenceMs: inferenceMs,
      postprocessingMs: postprocessed.elapsedMilliseconds,
      totalMs: totalMs,
    );
  }

  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}
