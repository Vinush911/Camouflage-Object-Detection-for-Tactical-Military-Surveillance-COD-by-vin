import 'package:flutter/material.dart';
import '../../controllers/benchmark_controller.dart';
import '../../models/benchmark_result.dart';

// Screen for executing repeated latency benchmarks and inspecting device hardware specifications.

class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({super.key});

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  late final BenchmarkController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BenchmarkController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'PERFORMANCE BENCHMARK',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 0.8,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info banner explaining the warm-up and measurement protocol
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Text(
                    'Benchmarking executes 3 warm-up runs to clear cold-start effects, '
                    'followed by 10 measured runs to report statistically sound '
                    'minimum, average, maximum, and median latencies.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), height: 1.3),
                  ),
                ),

                const SizedBox(height: 16),

                // Execution Controls / Progress Indicator
                if (_controller.status == BenchmarkStatus.running)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 14),
                        Text(
                          _controller.progressMessage,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _controller.totalSteps > 0
                              ? _controller.currentStep / _controller.totalSteps
                              : null,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF1E3A8A)),
                        ),
                      ],
                    ),
                  )
                else
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      _controller.status == BenchmarkStatus.completed
                          ? 'RUN BENCHMARK AGAIN'
                          : 'START BENCHMARK TEST',
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _controller.startBenchmark(),
                  ),

                if (_controller.status == BenchmarkStatus.error) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Text(
                      _controller.errorMessage ?? 'Benchmark failed.',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],

                // Report Section
                if (_controller.report != null) ...[
                  const SizedBox(height: 20),
                  _buildBenchmarkReportCard(_controller.report!),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBenchmarkReportCard(BenchmarkResult report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Measured Latency Table Card
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MEASURED LATENCY (${report.measuredRuns} RUNS)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2.6),
                    1: FlexColumnWidth(1.1),
                    2: FlexColumnWidth(1.1),
                    3: FlexColumnWidth(1.1),
                    4: FlexColumnWidth(1.1),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade100),
                      children: const [
                        Padding(padding: EdgeInsets.all(6), child: Text('Stage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        Padding(padding: EdgeInsets.all(6), child: Text('Min', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        Padding(padding: EdgeInsets.all(6), child: Text('Avg', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        Padding(padding: EdgeInsets.all(6), child: Text('Med', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        Padding(padding: EdgeInsets.all(6), child: Text('Max', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      ],
                    ),
                    _buildStatRow('Preprocessing', report.preprocessing),
                    _buildStatRow('DGNet Inference', report.dgnetInference, isHighlight: true),
                    _buildStatRow('Postprocessing', report.postprocessing),
                    if (report.classificationInference != null)
                      _buildStatRow('Classification', report.classificationInference!, isHighlight: true),
                    _buildStatRow('Total Pipeline', report.total, isBold: true),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Estimated Throughput:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Text(
                      '${report.estimatedFps.toStringAsFixed(1)} FPS',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 2. Hardware and Models Specifications Card
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BENCHMARK HARDWARE & MODELS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoLine('DGNet Model', report.dgnetModelName),
                _buildInfoLine(
                  'Classification Model',
                  report.classifierModelName ?? 'Unavailable (Skipped)',
                ),
                _buildInfoLine('Device Model', report.deviceModel),
                _buildInfoLine('OS Platform', report.androidVersion),
                _buildInfoLine('Memory Usage', report.memoryUsage),
                _buildInfoLine('Execution Delegate', report.delegateType),
              ],
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildStatRow(
    String label,
    LatencyStats stats, {
    bool isHighlight = false,
    bool isBold = false,
  }) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: (isHighlight || isBold) ? FontWeight.bold : FontWeight.normal,
              color: isHighlight ? const Color(0xFF1E3A8A) : Colors.black87,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Text(stats.minMs.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
        ),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            stats.avgMs.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 11,
              fontWeight: (isHighlight || isBold) ? FontWeight.bold : FontWeight.normal,
              color: isHighlight ? const Color(0xFF1E3A8A) : Colors.black87,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Text(stats.medianMs.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
        ),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Text(stats.maxMs.toStringAsFixed(1), style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  Widget _buildInfoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
