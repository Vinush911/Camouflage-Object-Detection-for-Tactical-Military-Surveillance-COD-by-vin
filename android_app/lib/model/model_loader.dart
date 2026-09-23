import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import '../core/errors/app_exceptions.dart';
import '../models/model_metadata.dart';
import 'model_config.dart';

// Handles loading TFLite model files and config JSONs from Flutter assets.
// It inspects actual runtime tensor metadata to ensure the model matches its configuration.

class LoadedModelPackage {
  final tfl.Interpreter interpreter;
  final ModelConfig config;
  final ModelMetadata metadata;

  const LoadedModelPackage({
    required this.interpreter,
    required this.config,
    required this.metadata,
  });
}

class ModelLoader {
  // Loads the JSON configuration file from Flutter assets
  static Future<ModelConfig> loadConfig(
    String configPath, {
    required ModelConfig fallback,
  }) async {
    try {
      final jsonString = await rootBundle.loadString(configPath);
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      return ModelConfig.fromJson(jsonMap);
    } catch (e) {
      debugPrint('[ModelLoader] Could not load config at $configPath: $e. Using fallback.');
      return fallback;
    }
  }

  // Attempts to load a TFLite model asset, inspect its tensors, and validate against its config
  static Future<LoadedModelPackage?> loadModel({
    required String modelPath,
    required String configPath,
    required String task,
    required ModelConfig fallbackConfig,
    String hardwareDelegate = 'CPU',
    int numThreads = 4,
  }) async {
    // 1. Verify model file exists in asset bundle
    ByteData modelByteData;
    try {
      modelByteData = await rootBundle.load(modelPath);
    } catch (e) {
      debugPrint('[ModelLoader] Model file not found at $modelPath: $e');
      return null;
    }

    final fileSizeMb = modelByteData.lengthInBytes / (1024.0 * 1024.0);

    // 2. Load the configuration
    final config = await loadConfig(configPath, fallback: fallbackConfig);

    // 3. Configure interpreter options to use multi-threading for fast processing
    final options = tfl.InterpreterOptions()..threads = numThreads;

    tfl.Interpreter interpreter;
    try {
      interpreter = tfl.Interpreter.fromBuffer(
        modelByteData.buffer.asUint8List(),
        options: options,
      );
    } catch (e) {
      debugPrint('[ModelLoader] Failed to initialize TFLite interpreter for $modelPath: $e');
      throw UnsupportedTensorException('Failed to create interpreter: $e');
    }

    // 4. Inspect runtime tensor metadata
    final inputTensors = interpreter.getInputTensors();
    final outputTensors = interpreter.getOutputTensors();

    if (inputTensors.isEmpty || outputTensors.isEmpty) {
      interpreter.close();
      throw UnsupportedTensorException('Model at $modelPath has no input or output tensors.');
    }

    final inTensor = inputTensors[0];
    final outTensor = outputTensors[0];

    debugPrint('[ModelLoader] [$task] Model loaded: ${modelPath.split('/').last}');
    debugPrint('[ModelLoader]   Input  shape: ${inTensor.shape}, type: ${inTensor.type}');
    debugPrint('[ModelLoader]   Output shape: ${outTensor.shape}, type: ${outTensor.type}');
    // Log quantization parameters visible on the first on-device test.
    // A scale of 0.0 means no external quantization — the tensor stays as float32.
    debugPrint('[ModelLoader]   Input  quant: scale=${inTensor.params.scale}, zero_point=${inTensor.params.zeroPoint}');
    debugPrint('[ModelLoader]   Output quant: scale=${outTensor.params.scale}, zero_point=${outTensor.params.zeroPoint}');

    // 5. Validate tensor shapes against configuration
    final inShape = inTensor.shape;
    final outShape = outTensor.shape;

    // Check input tensor: expected [batch, height, width, channels] or [batch, channels, height, width]
    final hasExpectedInput = inShape.length == 4 &&
        ((inShape[1] == config.inputHeight && inShape[2] == config.inputWidth) ||
            (inShape[2] == config.inputHeight && inShape[3] == config.inputWidth));

    if (!hasExpectedInput) {
      interpreter.close();
      throw ModelIncompatibleException(
        message: 'Input tensor shape mismatch for $task model.',
        expectedInput: [1, config.inputHeight, config.inputWidth, config.inputChannels],
        actualInput: inShape,
        expectedOutput: null,
        actualOutput: outShape,
      );
    }

    // Task-specific output validation
    if (task == 'classification') {
      final outClassesCount = outShape.last;
      if (config.classes.isNotEmpty && config.classes.length != outClassesCount) {
        debugPrint('[ModelLoader] Warning: Config classes count (${config.classes.length}) '
            'does not match model output classes count ($outClassesCount)');
      }
    }

    final metadata = ModelMetadata(
      modelName: config.modelName,
      task: task,
      assetPath: modelPath,
      status: ModelStatus.loaded,
      inputShape: inShape,
      inputDataType: inTensor.type.toString().replaceAll('TensorType.', ''),
      outputShape: outShape,
      outputDataType: outTensor.type.toString().replaceAll('TensorType.', ''),
      fileSizeMb: fileSizeMb,
      quantizationMode: inTensor.type.toString().contains('int') ? 'Quantized INT8' : 'Standard FP32',
      delegateType: '$hardwareDelegate ($numThreads Threads)',
      classes: config.classes,
    );

    return LoadedModelPackage(
      interpreter: interpreter,
      config: config,
      metadata: metadata,
    );
  }
}
