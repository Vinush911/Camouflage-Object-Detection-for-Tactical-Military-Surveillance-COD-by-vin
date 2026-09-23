// Models for storing benchmark measurements and hardware statistics.

class LatencyStats {
  final double minMs;
  final double avgMs;
  final double maxMs;
  final double medianMs;

  const LatencyStats({
    required this.minMs,
    required this.avgMs,
    required this.maxMs,
    required this.medianMs,
  });

  factory LatencyStats.fromSamples(List<double> samples) {
    if (samples.isEmpty) {
      return const LatencyStats(minMs: 0, avgMs: 0, maxMs: 0, medianMs: 0);
    }
    final sorted = List<double>.from(samples)..sort();
    final min = sorted.first;
    final max = sorted.last;
    final sum = sorted.reduce((a, b) => a + b);
    final avg = sum / sorted.length;
    final median = sorted.length % 2 == 1
        ? sorted[sorted.length ~/ 2]
        : (sorted[sorted.length ~/ 2 - 1] + sorted[sorted.length ~/ 2]) / 2.0;

    return LatencyStats(
      minMs: min,
      avgMs: avg,
      maxMs: max,
      medianMs: median,
    );
  }
}

class BenchmarkResult {
  final LatencyStats preprocessing;
  final LatencyStats dgnetInference;
  final LatencyStats postprocessing;
  final LatencyStats? classificationInference;
  final LatencyStats total;
  final double estimatedFps;
  final int warmupRuns;
  final int measuredRuns;
  final String deviceModel;
  final String androidVersion;
  final String memoryUsage;
  final String delegateType;
  final String dgnetModelName;
  final String? classifierModelName;

  const BenchmarkResult({
    required this.preprocessing,
    required this.dgnetInference,
    required this.postprocessing,
    this.classificationInference,
    required this.total,
    required this.estimatedFps,
    required this.warmupRuns,
    required this.measuredRuns,
    required this.deviceModel,
    required this.androidVersion,
    required this.memoryUsage,
    required this.delegateType,
    required this.dgnetModelName,
    this.classifierModelName,
  });
}
