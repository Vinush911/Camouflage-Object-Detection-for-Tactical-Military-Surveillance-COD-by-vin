// Information about the deployed machine learning model.
// This stores technical details like input/output shapes and quantization type.

class ModelMetadata {
  final String modelName;
  final String version;
  final String backboneName;
  final List<int> inputShape;
  final String inputDataType;
  final List<int> outputShape;
  final String outputDataType;
  final String quantizationMode;
  final String delegateType;
  final double fileSizeMb;

  const ModelMetadata({
    required this.modelName,
    required this.version,
    required this.backboneName,
    required this.inputShape,
    required this.inputDataType,
    required this.outputShape,
    required this.outputDataType,
    required this.quantizationMode,
    required this.delegateType,
    required this.fileSizeMb,
  });

  // Default metadata based on our verified DGNet-MobileNetV3 model
  factory ModelMetadata.dgnetMobileNetV3() {
    return const ModelMetadata(
      modelName: 'DGNet-MobileNetV3',
      version: '1.0.0-tactical',
      backboneName: 'MobileNetV3-Large',
      inputShape: [1, 384, 384, 3],
      inputDataType: 'float32',
      outputShape: [1, 384, 384, 1],
      outputDataType: 'float32',
      quantizationMode: 'Default Optimization (FP32 Tensors)',
      delegateType: 'CPU / XNNPACK',
      fileSizeMb: 3.95,
    );
  }
}
