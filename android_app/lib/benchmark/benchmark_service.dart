import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../model/model_registry.dart';
import '../models/benchmark_result.dart';
import '../services/cod_pipeline_service.dart';
import '../utils/app_memory_utils.dart';

// Service that runs standardized performance benchmarks on the detection pipeline.
// Performs warm-up runs first to avoid cold-start bias, then collects repeated
// latency measurements across all stages.

class BenchmarkProgress {
  final int currentStep;
  final int totalSteps;
  final String stageMessage;

  const BenchmarkProgress({
    required this.currentStep,
    required this.totalSteps,
    required this.stageMessage,
  });
}

class BenchmarkService {
  final CodPipelineService _pipeline;
  final ModelRegistry _registry;

  BenchmarkService({
    CodPipelineService? pipeline,
    ModelRegistry? registry,
  })  : _pipeline = pipeline ?? CodPipelineService(),
        _registry = registry ?? ModelRegistry();

  // Runs full benchmark suite with warm-up and repeated measured runs
  Future<BenchmarkResult> runBenchmark({
    int warmupRuns = 3,
    int measuredRuns = 10,
    void Function(BenchmarkProgress progress)? onProgress,
  }) async {
    // Generate a standardized synthetic test image for repeatable benchmarking
    final testImage = _createBenchmarkImage(640, 640);

    final totalSteps = warmupRuns + measuredRuns;

    // 1. Warm-up Phase: run pipeline without recording to warm up caches
    for (int i = 0; i < warmupRuns; i++) {
      onProgress?.call(
        BenchmarkProgress(
          currentStep: i + 1,
          totalSteps: totalSteps,
          stageMessage: 'Warm-up run ${i + 1} of $warmupRuns...',
        ),
      );
      await _pipeline.processImage(testImage);
    }

    // 2. Measured Runs Phase: collect individual stage timings
    final preprocSamples = <double>[];
    final dgnetSamples = <double>[];
    final postprocSamples = <double>[];
    final classifySamples = <double>[];
    final totalSamples = <double>[];

    for (int i = 0; i < measuredRuns; i++) {
      onProgress?.call(
        BenchmarkProgress(
          currentStep: warmupRuns + i + 1,
          totalSteps: totalSteps,
          stageMessage: 'Measuring run ${i + 1} of $measuredRuns...',
        ),
      );

      final result = await _pipeline.processImage(testImage);

      preprocSamples.add(result.preprocessingMs);
      dgnetSamples.add(result.dgnetInferenceMs);
      postprocSamples.add(result.postprocessingMs);
      if (result.isClassifierAvailable) {
        classifySamples.add(result.classificationInferenceMs);
      }
      totalSamples.add(result.totalMs);
    }

    // 3. Compute statistical metrics (min, avg, max, median)
    final preprocStats = LatencyStats.fromSamples(preprocSamples);
    final dgnetStats = LatencyStats.fromSamples(dgnetSamples);
    final postprocStats = LatencyStats.fromSamples(postprocSamples);
    final classifyStats = classifySamples.isNotEmpty
        ? LatencyStats.fromSamples(classifySamples)
        : null;
    final totalStats = LatencyStats.fromSamples(totalSamples);

    // Calculate throughput FPS based on average total latency
    final estimatedFps = totalStats.avgMs > 0 ? (1000.0 / totalStats.avgMs) : 0.0;

    // 4. Query device hardware info
    final deviceInfo = await _queryDeviceInfo();

    return BenchmarkResult(
      preprocessing: preprocStats,
      dgnetInference: dgnetStats,
      postprocessing: postprocStats,
      classificationInference: classifyStats,
      total: totalStats,
      estimatedFps: estimatedFps,
      warmupRuns: warmupRuns,
      measuredRuns: measuredRuns,
      deviceModel: deviceInfo['deviceModel'] ?? 'Unavailable',
      androidVersion: deviceInfo['androidVersion'] ?? 'Unavailable',
      memoryUsage: deviceInfo['memory'] ?? 'Unavailable',
      delegateType: _registry.dgnetMetadata.delegateType,
      dgnetModelName: _registry.dgnetMetadata.modelName,
      classifierModelName: _registry.isClassifierLoaded
          ? _registry.classifierMetadata.modelName
          : null,
    );
  }

  // Generates a clean synthetic RGB image with artificial foreground patches for testing
  img.Image _createBenchmarkImage(int width, int height) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(120, 130, 110)); // Muted woodland olive

    // Draw two simulated targets
    img.fillRect(
      image,
      x1: width ~/ 4,
      y1: height ~/ 4,
      x2: (width ~/ 4) + 120,
      y2: (height ~/ 4) + 120,
      color: img.ColorRgb8(90, 100, 80),
    );

    img.fillRect(
      image,
      x1: width ~/ 2,
      y1: height ~/ 2,
      x2: (width ~/ 2) + 140,
      y2: (height ~/ 2) + 140,
      color: img.ColorRgb8(80, 95, 75),
    );

    return image;
  }

  // Safely queries hardware information without fabricating unavailable numbers
  Future<Map<String, String>> _queryDeviceInfo() async {
    final memMb = AppMemoryUtils.getCurrentRssMb();
    final Map<String, String> info = {
      'deviceModel': 'Unavailable',
      'androidVersion': 'Unavailable',
      'memory': '$memMb MB',
    };

    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        info['deviceModel'] = '${androidInfo.manufacturer} ${androidInfo.model}';
        info['androidVersion'] = 'Android ${androidInfo.version.release} (API ${androidInfo.version.sdkInt})';
      } else if (Platform.isIOS) {
        final iosInfo = await DeviceInfoPlugin().iosInfo;
        info['deviceModel'] = '${iosInfo.name} (${iosInfo.model})';
        info['androidVersion'] = 'iOS ${iosInfo.systemVersion}';
      } else {
        info['deviceModel'] = Platform.operatingSystem;
        info['androidVersion'] = Platform.operatingSystemVersion;
      }
    } catch (e) {
      debugPrint('[BenchmarkService] Could not retrieve device info: $e');
    }

    return info;
  }
}
