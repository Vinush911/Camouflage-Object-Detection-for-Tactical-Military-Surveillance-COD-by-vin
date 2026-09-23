// Custom errors for handling model loading, configuration, and inference issues.

class ModelNotFoundException implements Exception {
  final String message;
  ModelNotFoundException(this.message);

  @override
  String toString() => 'ModelNotFoundException: $message';
}

class UnsupportedTensorException implements Exception {
  final String message;
  UnsupportedTensorException(this.message);

  @override
  String toString() => 'UnsupportedTensorException: $message';
}

class ModelIncompatibleException implements Exception {
  final String message;
  final List<int>? expectedInput;
  final List<int>? actualInput;
  final List<int>? expectedOutput;
  final List<int>? actualOutput;

  ModelIncompatibleException({
    required this.message,
    this.expectedInput,
    this.actualInput,
    this.expectedOutput,
    this.actualOutput,
  });

  @override
  String toString() => 'ModelIncompatibleException: $message';
}

class InferenceException implements Exception {
  final String message;
  InferenceException(this.message);

  @override
  String toString() => 'InferenceException: $message';
}
