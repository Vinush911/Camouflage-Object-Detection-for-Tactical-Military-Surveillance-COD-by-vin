import 'package:flutter/material.dart';
import '../models/detection_result.dart';

// Displays a clean breakdown table showing latency for each stage of the pipeline.

class TimingTable extends StatelessWidget {
  final DetectionResult result;

  const TimingTable({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PIPELINE LATENCY BREAKDOWN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 10),

          // Latency Rows
          _buildTimingRow(
            'Image Preprocessing',
            '${result.preprocessingMs.toStringAsFixed(1)} ms',
          ),
          _buildTimingRow(
            'DGNet Segmentation Inference',
            '${result.dgnetInferenceMs.toStringAsFixed(1)} ms',
            isHighlight: true,
          ),
          _buildTimingRow(
            'Mask Postprocessing & Blobs',
            '${result.postprocessingMs.toStringAsFixed(1)} ms',
          ),
          if (result.isClassifierAvailable)
            _buildTimingRow(
              'Target Classification Inference',
              '${result.classificationInferenceMs.toStringAsFixed(1)} ms',
              isHighlight: true,
            )
          else
            _buildTimingRow(
              'Target Classification',
              'Skipped (Segmentation only)',
              isDimmed: true,
            ),

          const Divider(height: 16),

          // Total Pipeline Latency
          _buildTimingRow(
            'Total Pipeline Latency',
            '${result.totalMs.toStringAsFixed(1)} ms',
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimingRow(
    String label,
    String value, {
    bool isHighlight = false,
    bool isBold = false,
    bool isDimmed = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isDimmed
                  ? Colors.grey
                  : (isHighlight ? const Color(0xFF1E3A8A) : Colors.black87),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold || isHighlight ? FontWeight.bold : FontWeight.normal,
              color: isDimmed
                  ? Colors.grey
                  : (isHighlight ? const Color(0xFF1E3A8A) : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
