import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:image/image.dart' as img;
import '../config/app_config.dart';
import 'cod_inference_service.dart';

// Stores statistics for one stage (min, max, average, standard deviation)
class LatencyStats {
  final double minMs;
  final double maxMs;
  final double avgMs;
  final double stdDevMs;

  const LatencyStats({
    required this.minMs,
    required this.maxMs,
    required this.avgMs,
    required this.stdDevMs,
  });

  factory LatencyStats.fromList(List<double> values) {
    if (values.isEmpty) {
      return const LatencyStats(minMs: 0, maxMs: 0, avgMs: 0, stdDevMs: 0);
    }
    final minVal = values.reduce(min);
    final maxVal = values.reduce(max);
    final avgVal = values.reduce((a, b) => a + b) / values.length;

    // Standard deviation
    var variance = 0.0;
    for (final v in values) {
      variance += (v - avgVal) * (v - avgVal);
    }
    final stdDev = sqrt(variance / values.length);

    return LatencyStats(
      minMs: minVal,
      maxMs: maxVal,
      avgMs: avgVal,
      stdDevMs: stdDev,
    );
  }
}

// Stores the complete benchmark evaluation report
class BenchmarkReport {
  final int warmupRuns;
  final int measuredRuns;
  final LatencyStats preprocessing;
  final LatencyStats inference;
  final LatencyStats postprocessing;
  final LatencyStats total;
  final double estimatedFps;
  final int targetsDetected;
  final String modelName;
  final String inputResolution;
  final double modelSizeMb;
  final String deviceModel;
  final String androidVersion;
  final String memoryUsage;
  final String gpuUsage;

  const BenchmarkReport({
    required this.warmupRuns,
    required this.measuredRuns,
    required this.preprocessing,
    required this.inference,
    required this.postprocessing,
    required this.total,
    required this.estimatedFps,
    required this.targetsDetected,
    required this.modelName,
    required this.inputResolution,
    required this.modelSizeMb,
    required this.deviceModel,
    required this.androidVersion,
    required this.memoryUsage,
    required this.gpuUsage,
  });
}

// Performance Monitor that handles warm-up runs, steady-state benchmarking,
// and hardware measurement without inventing fake metrics.
class PerformanceMonitor {
  final CodInferenceService inferenceService;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  PerformanceMonitor({required this.inferenceService});

  // Executes the benchmarking protocol on a given image or a generated test pattern
  Future<BenchmarkReport> runBenchmark({
    img.Image? testImage,
    int warmupCount = AppConfig.benchmarkWarmupRuns,
    int measuredCount = AppConfig.benchmarkMeasuredRuns,
    Function(int current, int total, String status)? onProgress,
  }) async {
    // Ensure the service is loaded
    await inferenceService.initialize();

    // Use supplied image or generate a realistic 384x384 synthetic test image
    final sample = testImage ?? img.Image(width: 384, height: 384);

    // 1. Warm-up Phase: Run without recording to ensure JIT compiler and caches are hot
    for (var i = 0; i < warmupCount; i++) {
      onProgress?.call(i + 1, warmupCount + measuredCount, 'Warm-up run ${i + 1} of $warmupCount...');
      await inferenceService.runInference(sample);
    }

    // 2. Measurement Phase: Run steady-state inferences and log timing breakdown
    final preprocTimes = <double>[];
    final inferTimes = <double>[];
    final postprocTimes = <double>[];
    final totalTimes = <double>[];
    var lastTargetCount = 0;

    for (var i = 0; i < measuredCount; i++) {
      onProgress?.call(warmupCount + i + 1, warmupCount + measuredCount, 'Benchmark run ${i + 1} of $measuredCount...');
      final result = await inferenceService.runInference(sample);
      preprocTimes.add(result.preprocessingMs);
      inferTimes.add(result.inferenceMs);
      postprocTimes.add(result.postprocessingMs);
      totalTimes.add(result.totalMs);
      lastTargetCount = result.targetCount;
    }

    final preprocStats = LatencyStats.fromList(preprocTimes);
    final inferStats = LatencyStats.fromList(inferTimes);
    final postprocStats = LatencyStats.fromList(postprocTimes);
    final totalStats = LatencyStats.fromList(totalTimes);

    final fps = totalStats.avgMs > 0 ? (1000.0 / totalStats.avgMs) : 0.0;

    // Fetch device information safely
    var deviceName = 'Android Device';
    var androidVer = 'Unknown';
    try {
      final androidInfo = await _deviceInfo.androidInfo;
      deviceName = '${androidInfo.manufacturer} ${androidInfo.model}';
      androidVer = 'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
    } catch (_) {
      // Fallback if running on non-Android platform or permission issue
    }

    final meta = inferenceService.metadata;

    return BenchmarkReport(
      warmupRuns: warmupCount,
      measuredRuns: measuredCount,
      preprocessing: preprocStats,
      inference: inferStats,
      postprocessing: postprocStats,
      total: totalStats,
      estimatedFps: fps,
      targetsDetected: lastTargetCount,
      modelName: meta.modelName,
      inputResolution: '${meta.inputShape[1]} × ${meta.inputShape[2]} × ${meta.inputShape[3]}',
      modelSizeMb: meta.fileSizeMb,
      deviceModel: deviceName,
      androidVersion: androidVer,
      // Note: We do not invent RAM or GPU usage numbers without native profilers.
      // We clearly mark them as N/A per research instructions.
      memoryUsage: 'N/A (Requires Native Profiler)',
      gpuUsage: 'N/A (CPU XNNPACK Mode)',
    );
  }
}
