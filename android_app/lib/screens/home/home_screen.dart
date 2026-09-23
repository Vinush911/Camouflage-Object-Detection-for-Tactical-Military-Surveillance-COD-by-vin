import 'package:flutter/material.dart';
import '../../controllers/detection_controller.dart';
import '../../model/model_registry.dart';
import '../benchmark/benchmark_screen.dart';
import '../live_camera/live_camera_screen.dart';
import '../model_info/model_info_screen.dart';
import '../result/result_screen.dart';

// Home menu screen for the COD Vision research reference tool.

class HomeScreen extends StatelessWidget {
  final DetectionController controller;

  const HomeScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final registry = ModelRegistry();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'COD VISION',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E3A8A), // Deep Navy
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Model Diagnostics & Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ModelInfoScreen(controller: controller),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // Title and Subtitle
              const Center(
                child: Text(
                  'Camouflaged Object Detection',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  'Tactical Surveillance Framework',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Action Buttons
              _buildMenuButton(
                context,
                icon: Icons.camera_alt,
                label: 'CAPTURE IMAGE',
                subtitle: 'Take a photo using the device camera',
                color: const Color(0xFF1E3A8A),
                onTap: () async {
                  await controller.captureFromCamera();
                  if (context.mounted && controller.result != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ResultScreen(controller: controller),
                      ),
                    );
                  }
                },
              ),

              const SizedBox(height: 12),

              _buildMenuButton(
                context,
                icon: Icons.photo_library,
                label: 'SELECT FROM GALLERY',
                subtitle: 'Load an image file from storage',
                color: const Color(0xFF0D9488), // Teal
                onTap: () async {
                  await controller.pickFromGallery();
                  if (context.mounted && controller.result != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ResultScreen(controller: controller),
                      ),
                    );
                  }
                },
              ),

              const SizedBox(height: 12),

              _buildMenuButton(
                context,
                icon: Icons.videocam,
                label: 'LIVE CAMERA STREAM',
                subtitle: 'Real-time camera feed with live inference',
                color: const Color(0xFF334155), // Slate
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LiveCameraScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              _buildMenuButton(
                context,
                icon: Icons.speed,
                label: 'PERFORMANCE BENCHMARK',
                subtitle: 'Measure latency (preproc, DGNet, postproc, classify)',
                color: const Color(0xFF475569),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BenchmarkScreen(),
                    ),
                  );
                },
              ),

              const Spacer(),

              // Error or loading status banner
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  if (controller.status == DetectionStatus.error) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              controller.errorMessage ?? 'An error occurred.',
                              style: const TextStyle(fontSize: 12, color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  if (controller.status == DetectionStatus.loading ||
                      controller.status == DetectionStatus.processing) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Technical info footer reflecting active model statuses
              ListenableBuilder(
                listenable: registry,
                builder: (context, _) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Model:',
                              style: TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                            Text(
                              registry.isDgnetLoaded
                                  ? registry.dgnetMetadata.modelName
                                  : 'DGNet-MobileNetV3',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Mode:',
                              style: TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                            Text(
                              'Offline / On-Device TFLite',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D9488),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
