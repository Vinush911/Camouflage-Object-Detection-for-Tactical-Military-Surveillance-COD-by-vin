import 'package:flutter/foundation.dart';
import '../benchmark/benchmark_service.dart';
import '../models/benchmark_result.dart';

enum BenchmarkStatus {
  idle,
  running,
  completed,
  error,
}

// Controller managing benchmark execution state, progress reporting, and results.

class BenchmarkController extends ChangeNotifier {
  final BenchmarkService _benchmarkService;

  BenchmarkStatus _status = BenchmarkStatus.idle;
  String? _errorMessage;
  String _progressMessage = 'Ready to start benchmark.';
  int _currentStep = 0;
  int _totalSteps = 0;

  BenchmarkResult? _report;

  int warmupRuns = 3;
  int measuredRuns = 10;

  BenchmarkController({BenchmarkService? service})
      : _benchmarkService = service ?? BenchmarkService();

  BenchmarkStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String get progressMessage => _progressMessage;
  int get currentStep => _currentStep;
  int get totalSteps => _totalSteps;
  BenchmarkResult? get report => _report;

  // Starts the benchmark test suite
  Future<void> startBenchmark() async {
    _status = BenchmarkStatus.running;
    _errorMessage = null;
    _currentStep = 0;
    _totalSteps = warmupRuns + measuredRuns;
    _progressMessage = 'Starting benchmark test...';
    notifyListeners();

    try {
      final result = await _benchmarkService.runBenchmark(
        warmupRuns: warmupRuns,
        measuredRuns: measuredRuns,
        onProgress: (progress) {
          _currentStep = progress.currentStep;
          _totalSteps = progress.totalSteps;
          _progressMessage = progress.stageMessage;
          notifyListeners();
        },
      );

      _report = result;
      _status = BenchmarkStatus.completed;
      _progressMessage = 'Benchmark completed successfully.';
      notifyListeners();
    } catch (e) {
      _status = BenchmarkStatus.error;
      _errorMessage = 'Benchmark failed: $e';
      notifyListeners();
    }
  }
}
