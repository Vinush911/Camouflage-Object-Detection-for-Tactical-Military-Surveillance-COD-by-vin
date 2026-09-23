// Model configuration parsed from model_config.json files.
// This allows developers to change model specifications without touching Dart code.

class ModelConfig {
  final String modelName;
  final String task; // "segmentation" or "classification"
  final int inputWidth;
  final int inputHeight;
  final int inputChannels;
  final String inputType;
  final String normalization; // "zero_to_one", "minus_one_to_one", "none"
  final String outputActivation; // "none", "sigmoid", "softmax"
  final double threshold;
  final int minRegionArea;
  final List<String> classes;

  const ModelConfig({
    required this.modelName,
    required this.task,
    required this.inputWidth,
    required this.inputHeight,
    this.inputChannels = 3,
    this.inputType = 'float32',
    this.normalization = 'zero_to_one',
    this.outputActivation = 'none',
    this.threshold = 0.30,
    this.minRegionArea = 120,
    this.classes = const [],
  });

  factory ModelConfig.fromJson(Map<String, dynamic> json) {
    return ModelConfig(
      modelName: json['model_name'] as String? ?? 'Unnamed Model',
      task: json['task'] as String? ?? 'segmentation',
      inputWidth: (json['input_width'] as num?)?.toInt() ?? 384,
      inputHeight: (json['input_height'] as num?)?.toInt() ?? 384,
      inputChannels: (json['input_channels'] as num?)?.toInt() ?? 3,
      inputType: json['input_type'] as String? ?? 'float32',
      normalization: json['normalization'] as String? ?? 'zero_to_one',
      outputActivation: json['output_activation'] as String? ?? 'none',
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.30,
      minRegionArea: (json['min_region_area'] as num?)?.toInt() ?? 120,
      classes: (json['classes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'model_name': modelName,
      'task': task,
      'input_width': inputWidth,
      'input_height': inputHeight,
      'input_channels': inputChannels,
      'input_type': inputType,
      'normalization': normalization,
      'output_activation': outputActivation,
      'threshold': threshold,
      'min_region_area': minRegionArea,
      'classes': classes,
    };
  }

  // Default DGNet configuration fallback (used when model_config.json cannot be loaded)
  factory ModelConfig.defaultDgnet() {
    return const ModelConfig(
      modelName: 'DGNet-S',
      task: 'segmentation',
      inputWidth: 384,
      inputHeight: 384,
      inputChannels: 3,
      inputType: 'float32',
      normalization: 'zero_to_one',
      outputActivation: 'none',
      threshold: 0.30,
      minRegionArea: 120,
    );
  }

  // Default Classifier configuration fallback
  factory ModelConfig.defaultClassifier() {
    return const ModelConfig(
      modelName: 'Target Classifier',
      task: 'classification',
      inputWidth: 224,
      inputHeight: 224,
      inputChannels: 3,
      inputType: 'float32',
      normalization: 'zero_to_one',
      classes: ['Soldier', 'Tank'],
    );
  }
}
