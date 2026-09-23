import 'package:flutter_test/flutter_test.dart';
import 'package:android_app/models/benchmark_result.dart';

void main() {
  group('Benchmark Statistics Tests', () {
    test('calculates min, max, avg, and median accurately for odd sample count', () {
      final samples = [40.0, 10.0, 30.0, 50.0, 20.0];
      final stats = LatencyStats.fromSamples(samples);

      expect(stats.minMs, 10.0);
      expect(stats.maxMs, 50.0);
      expect(stats.avgMs, 30.0);
      expect(stats.medianMs, 30.0);
    });

    test('calculates median accurately for even sample count', () {
      final samples = [10.0, 20.0, 30.0, 40.0];
      final stats = LatencyStats.fromSamples(samples);

      expect(stats.minMs, 10.0);
      expect(stats.maxMs, 40.0);
      expect(stats.avgMs, 25.0);
      // (20.0 + 30.0) / 2 = 25.0
      expect(stats.medianMs, 25.0);
    });

    test('handles empty samples safely without exceptions', () {
      final stats = LatencyStats.fromSamples([]);

      expect(stats.minMs, 0.0);
      expect(stats.maxMs, 0.0);
      expect(stats.avgMs, 0.0);
      expect(stats.medianMs, 0.0);
    });
  });
}
