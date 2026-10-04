import 'package:flutter/material.dart';
import '../models/model_metadata.dart';

// Displays inspected runtime tensor metadata and status for a model.

class ModelStatusCard extends StatelessWidget {
  final String title;
  final ModelMetadata metadata;

  const ModelStatusCard({
    super.key,
    required this.title,
    required this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (metadata.status) {
      case ModelStatus.loaded:
        statusColor = const Color(0xFF0D9488); // Teal
        break;
      case ModelStatus.incompatible:
        statusColor = Colors.red;
        break;
      case ModelStatus.unavailable:
      default:
        statusColor = Colors.orange.shade700;
        break;
    }

    return Card(
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
            // Header with Model Name and Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    metadata.statusDisplay,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Specs
            _buildRow('Model Name', metadata.modelName),
            _buildRow('Asset Path', metadata.assetPath),
            _buildRow(
              'Input Tensor',
              metadata.inputShape.isNotEmpty
                  ? '${metadata.inputShape.join("×")} (${metadata.inputDataType})'
                  : 'Unavailable',
            ),
            _buildRow(
              'Output Tensor',
              metadata.outputShape.isNotEmpty
                  ? '${metadata.outputShape.join("×")} (${metadata.outputDataType})'
                  : 'Unavailable',
            ),
            if (metadata.fileSizeMb > 0)
              _buildRow('File Size', '${metadata.fileSizeMb.toStringAsFixed(2)} MB'),
            _buildRow('Quantization', metadata.quantizationMode),
            _buildRow('Execution Delegate', metadata.delegateType),

            if (metadata.classes.isNotEmpty)
              _buildRow('Configured Classes', metadata.classes.join(', ')),

            // Notice showing that this is an untrained prototype model
            if (metadata.isPrototype) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 16,
                      color: Colors.amber.shade900,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'CLASSIFIER STATUS: UNTRAINED PROTOTYPE\n'
                        'Inference pipeline active. Model weights are uncalibrated prototype weights. '
                        'Ready to swap with trained weights when available.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Incompatibility warning or error message
            if (metadata.errorMessage != null && !metadata.isLoaded) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: metadata.isIncompatible
                      ? Colors.red.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: metadata.isIncompatible
                        ? Colors.red.shade200
                        : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      metadata.isIncompatible
                          ? Icons.error_outline
                          : Icons.info_outline,
                      size: 16,
                      color: metadata.isIncompatible ? Colors.red : Colors.orange.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        metadata.errorMessage!,
                        style: TextStyle(
                          fontSize: 11,
                          color: metadata.isIncompatible
                              ? Colors.red.shade900
                              : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
