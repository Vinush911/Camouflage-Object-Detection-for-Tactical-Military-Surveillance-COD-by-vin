import 'package:flutter/material.dart';
import '../../controllers/detection_controller.dart';
import '../../model/model_registry.dart';
import '../../widgets/model_status_card.dart';

// Model Information and Diagnostics screen.
// Inspects and displays runtime TFLite tensor metadata for both models
// and allows configuring sensitivity thresholds and hardware execution delegates.

class ModelInfoScreen extends StatefulWidget {
  final DetectionController controller;

  const ModelInfoScreen({super.key, required this.controller});

  @override
  State<ModelInfoScreen> createState() => _ModelInfoScreenState();
}

class _ModelInfoScreenState extends State<ModelInfoScreen> {
  late double _currentThreshold;
  late int _currentMinArea;
  final ModelRegistry _registry = ModelRegistry();

  @override
  void initState() {
    super.initState();
    _currentThreshold = widget.controller.threshold;
    _currentMinArea = widget.controller.minRegionArea;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'MODEL DIAGNOSTICS & SETTINGS',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload Models',
            onPressed: () async {
              await _registry.initialize();
              setState(() {});
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Model assets reloaded.')),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Detection Sensitivity Card
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
                    'DETECTION SENSITIVITY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Threshold Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Segmentation Threshold',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        _currentThreshold.toStringAsFixed(2),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pixels with probability >= this value are treated as foreground.',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  Slider(
                    value: _currentThreshold,
                    min: 0.1,
                    max: 0.9,
                    divisions: 16,
                    activeColor: const Color(0xFF1E3A8A),
                    onChanged: (val) {
                      setState(() => _currentThreshold = val);
                      widget.controller.updateThreshold(val);
                    },
                  ),

                  const Divider(height: 16),

                  // Minimum Region Size Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Min Target Area',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        '$_currentMinArea pixels',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Connected blobs smaller than this size are filtered out as noise.',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  Slider(
                    value: _currentMinArea.toDouble(),
                    min: 20,
                    max: 600,
                    divisions: 29,
                    activeColor: const Color(0xFF1E3A8A),
                    onChanged: (val) {
                      final intVal = val.round();
                      setState(() => _currentMinArea = intVal);
                      widget.controller.updateMinRegionArea(intVal);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 2. DGNet Model Diagnostics Card
          ModelStatusCard(
            title: 'Model 1: DGNet Segmentation',
            metadata: _registry.dgnetMetadata,
          ),

          const SizedBox(height: 14),

          // 3. Classifier Model Diagnostics Card
          ModelStatusCard(
            title: 'Model 2: Target Classifier',
            metadata: _registry.classifierMetadata,
          ),

          const SizedBox(height: 16),

          // 4. Research Note Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Text(
              'Research Reference Note: DGNet produces binary camouflage segmentation. '
              'Detected disconnected targets are cropped and passed to the classification model. '
              'If the classifier model is unavailable, the segmentation pipeline continues '
              'to identify targets labeled as "Camouflaged Target" without fake inferences.',
              style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.4),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
