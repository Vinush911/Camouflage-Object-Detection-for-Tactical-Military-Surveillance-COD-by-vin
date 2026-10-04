// Represents runtime model information and tensor specifications.
// These values come directly from inspecting the loaded TFLite model and its configuration file.

enum ModelStatus {
  notLoaded,
  loaded,
  unavailable,
  incompatible,
  error,
}

class ModelMetadata {
  final String modelName;
  final String task; // "segmentation" or "classification"
  final String assetPath;
  final ModelStatus status;
  final List<int> inputShape;
  final String inputDataType;
  final List<int> outputShape;
  final String outputDataType;
  final double fileSizeMb;
  final String quantizationMode;
  final String delegateType;
  final List<String> classes;
  final bool isPrototype;
  final String? errorMessage;

  const ModelMetadata({
    required this.modelName,
    required this.task,
    required this.assetPath,
    required this.status,
    required this.inputShape,
    required this.inputDataType,
    required this.outputShape,
    required this.outputDataType,
    this.fileSizeMb = 0.0,
    this.quantizationMode = 'Standard FP32',
    this.delegateType = 'CPU',
    this.classes = const [],
    this.isPrototype = false,
    this.errorMessage,
  });

  bool get isLoaded => status == ModelStatus.loaded;
  bool get isUnavailable => status == ModelStatus.unavailable;
  bool get isIncompatible => status == ModelStatus.incompatible;

  String get statusDisplay {
    switch (status) {
      case ModelStatus.loaded:
        return isPrototype ? 'Loaded (Untrained Prototype)' : 'Loaded';
      case ModelStatus.unavailable:
        return 'Unavailable';
      case ModelStatus.incompatible:
        return 'Incompatible';
      case ModelStatus.error:
        return 'Error';
      case ModelStatus.notLoaded:
        return 'Not Loaded';
    }
  }

  // Factory for missing or uninitialized model
  factory ModelMetadata.unavailable({
    required String modelName,
    required String task,
    required String assetPath,
    String? message,
  }) {
    return ModelMetadata(
      modelName: modelName,
      task: task,
      assetPath: assetPath,
      status: ModelStatus.unavailable,
      inputShape: const [],
      inputDataType: 'None',
      outputShape: const [],
      outputDataType: 'None',
      errorMessage: message ?? 'Model file not found at $assetPath',
    );
  }

  // Factory for incompatible model
  factory ModelMetadata.incompatible({
    required String modelName,
    required String task,
    required String assetPath,
    required List<int> actualInput,
    required List<int> actualOutput,
    required String inputType,
    required String outputType,
    required String reason,
  }) {
    return ModelMetadata(
      modelName: modelName,
      task: task,
      assetPath: assetPath,
      status: ModelStatus.incompatible,
      inputShape: actualInput,
      inputDataType: inputType,
      outputShape: actualOutput,
      outputDataType: outputType,
      errorMessage: reason,
    );
  }
}
