import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
import '../models/model_metadata.dart';
import 'model_config.dart';
import 'model_loader.dart';

// Central model registry for the entire application.
// All model file paths, configurations, runtime interpreters, and metadata
// are stored and managed here so the rest of the application remains decoupled.

class ModelRegistry extends ChangeNotifier {
  static final ModelRegistry _instance = ModelRegistry._internal();
  factory ModelRegistry() => _instance;
  ModelRegistry._internal();

  // Loaded packages for each model
  LoadedModelPackage? _dgnetPackage;
  LoadedModelPackage? _classifierPackage;

  // Metadata caches (used even if a model is unavailable or incompatible)
  ModelMetadata _dgnetMetadata = ModelMetadata.unavailable(
    modelName: 'DGNet Segmentation Model',
    task: 'segmentation',
    assetPath: AppConstants.dgnetModelPath,
  );

  ModelMetadata _classifierMetadata = ModelMetadata.unavailable(
    modelName: 'Target Classifier',
    task: 'classification',
    assetPath: AppConstants.classifierModelPath,
    message: 'Classification model file not present in assets.',
  );

  // Active hardware delegate configuration
  String _activeDelegate = 'CPU';
  int _cpuThreads = 4;

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  String get activeDelegate => _activeDelegate;
  int get cpuThreads => _cpuThreads;

  LoadedModelPackage? get dgnetPackage => _dgnetPackage;
  LoadedModelPackage? get classifierPackage => _classifierPackage;

  ModelMetadata get dgnetMetadata => _dgnetMetadata;
  ModelMetadata get classifierMetadata => _classifierMetadata;

  bool get isDgnetLoaded => _dgnetPackage != null && _dgnetMetadata.isLoaded;
  bool get isClassifierLoaded => _classifierPackage != null && _classifierMetadata.isLoaded;

  // Initializes both models from assets
  Future<void> initialize() async {
    await loadDgnetModel();
    await loadClassifierModel();
    _isInitialized = true;
    notifyListeners();
  }

  // Loads or reloads the DGNet segmentation model
  Future<void> loadDgnetModel() async {
    debugPrint('[ModelRegistry] Loading DGNet model from ${AppConstants.dgnetModelPath}...');

    try {
      final package = await ModelLoader.loadModel(
        modelPath: AppConstants.dgnetModelPath,
        configPath: AppConstants.dgnetConfigPath,
        task: 'segmentation',
        fallbackConfig: ModelConfig.defaultDgnet(),
        hardwareDelegate: _activeDelegate,
        numThreads: _cpuThreads,
      );

      if (package != null) {
        _dgnetPackage?.interpreter.close();
        _dgnetPackage = package;
        _dgnetMetadata = package.metadata;
        debugPrint('[ModelRegistry] DGNet model loaded successfully.');
      } else {
        _dgnetPackage = null;
        _dgnetMetadata = ModelMetadata.unavailable(
          modelName: 'DGNet Segmentation Model',
          task: 'segmentation',
          assetPath: AppConstants.dgnetModelPath,
          message: 'DGNet model unavailable at ${AppConstants.dgnetModelPath}',
        );
        debugPrint('[ModelRegistry] DGNet model unavailable.');
      }
    } on ModelIncompatibleException catch (e) {
      _dgnetPackage = null;
      _dgnetMetadata = ModelMetadata.incompatible(
        modelName: 'DGNet Model (Incompatible)',
        task: 'segmentation',
        assetPath: AppConstants.dgnetModelPath,
        actualInput: e.actualInput ?? [],
        actualOutput: e.actualOutput ?? [],
        inputType: 'Unknown',
        outputType: 'Unknown',
        reason: e.message,
      );
      debugPrint('[ModelRegistry] DGNet model incompatible: ${e.message}');
    } catch (e) {
      _dgnetPackage = null;
      _dgnetMetadata = ModelMetadata.unavailable(
        modelName: 'DGNet Segmentation Model',
        task: 'segmentation',
        assetPath: AppConstants.dgnetModelPath,
        message: 'Error loading DGNet: $e',
      );
      debugPrint('[ModelRegistry] Error loading DGNet: $e');
    }
  }

  // Loads or reloads the target classification model
  Future<void> loadClassifierModel() async {
    debugPrint('[ModelRegistry] Loading Classifier model from ${AppConstants.classifierModelPath}...');

    try {
      final package = await ModelLoader.loadModel(
        modelPath: AppConstants.classifierModelPath,
        configPath: AppConstants.classifierConfigPath,
        task: 'classification',
        fallbackConfig: ModelConfig.defaultClassifier(),
        hardwareDelegate: _activeDelegate,
        numThreads: _cpuThreads,
      );

      if (package != null) {
        _classifierPackage?.interpreter.close();
        _classifierPackage = package;
        _classifierMetadata = package.metadata;
        debugPrint('[ModelRegistry] Classifier model loaded successfully.');
      } else {
        _classifierPackage = null;
        _classifierMetadata = ModelMetadata.unavailable(
          modelName: 'Target Classifier',
          task: 'classification',
          assetPath: AppConstants.classifierModelPath,
          message: 'Classification model unavailable.',
        );
        debugPrint('[ModelRegistry] Classifier model unavailable.');
      }
    } on ModelIncompatibleException catch (e) {
      _classifierPackage = null;
      _classifierMetadata = ModelMetadata.incompatible(
        modelName: 'Target Classifier (Incompatible)',
        task: 'classification',
        assetPath: AppConstants.classifierModelPath,
        actualInput: e.actualInput ?? [],
        actualOutput: e.actualOutput ?? [],
        inputType: 'Unknown',
        outputType: 'Unknown',
        reason: e.message,
      );
      debugPrint('[ModelRegistry] Classifier incompatible: ${e.message}');
    } catch (e) {
      _classifierPackage = null;
      _classifierMetadata = ModelMetadata.unavailable(
        modelName: 'Target Classifier',
        task: 'classification',
        assetPath: AppConstants.classifierModelPath,
        message: 'Error loading classifier: $e',
      );
      debugPrint('[ModelRegistry] Error loading classifier: $e');
    }
  }

  // Allows switching the hardware backend (e.g. CPU with different thread count)
  Future<void> updateHardwareDelegate({
    required String delegate,
    int threads = 4,
  }) async {
    _activeDelegate = delegate;
    _cpuThreads = threads;
    await initialize();
  }

  // Frees memory when the registry is closed
  void disposeRegistry() {
    _dgnetPackage?.interpreter.close();
    _classifierPackage?.interpreter.close();
    _dgnetPackage = null;
    _classifierPackage = null;
    _isInitialized = false;
  }
}
