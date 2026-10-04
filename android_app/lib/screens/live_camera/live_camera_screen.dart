import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../camera/live_inference_controller.dart';
import '../../widgets/live_camera_overlay.dart';

// Live camera screen for basic camouflage object detection.
// Shows real-time camera view, detection bounding boxes, confidence slider,
// CPU thread controls, and performance metrics (latency, FPS, RAM).
class LiveCameraScreen extends StatefulWidget {
  const LiveCameraScreen({super.key});

  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen> {
  late final LiveInferenceController _controller;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _controller = LiveInferenceController();
    _controller.initializeCamera();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            if (_controller.status == LiveCameraStatus.uninitialized ||
                _controller.status == LiveCameraStatus.initializing) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF00FF41)),
                    SizedBox(height: 16),
                    Text(
                      'Initializing camera sensor...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              );
            }

            if (_controller.status == LiveCameraStatus.permissionDenied) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.no_photography_outlined,
                        size: 64,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Camera Permission Required',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _controller.errorMessage ??
                            'Please enable camera permission in device settings.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _controller.initializeCamera(),
                        child: const Text('RETRY PERMISSION'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (_controller.status == LiveCameraStatus.error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _controller.errorMessage ?? 'An error occurred.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final camController = _controller.cameraController;
            if (camController == null || !camController.value.isInitialized) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF00FF41)),
              );
            }

            final regions = _controller.currentResult?.regions ?? const [];

            return Stack(
              fit: StackFit.expand,
              children: [
                // 1. Live Camera Preview
                Center(
                  child: CameraPreview(camController),
                ),

                // 2. Basic Detection Overlay (bounding boxes and labels)
                Positioned.fill(
                  child: LiveCameraOverlay(
                    regions: regions,
                    frameWidth: _controller.frameWidth,
                    frameHeight: _controller.frameHeight,
                    showFraming: true,
                  ),
                ),

                // 3. Top Status Bar (Feed state, target count, toggle controls)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    color: const Color(0xCC000000),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back Button
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),

                        // Feed Status
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _controller.isStreaming
                                    ? const Color(0xFF00FF41)
                                    : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _controller.isStreaming ? 'LIVE' : 'PAUSED',
                              style: TextStyle(
                                color: _controller.isStreaming
                                    ? const Color(0xFF00FF41)
                                    : Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),

                        // Targets Count Badge and Controls Toggle
                        Row(
                          children: [
                            const Text(
                              'TARGETS: ',
                              style: TextStyle(
                                color: Color(0x9900FF41),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            Text(
                              regions.length.toString().padLeft(2, '0'),
                              style: const TextStyle(
                                color: Color(0xFF00FF41),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                _showControls
                                    ? Icons.tune
                                    : Icons.tune_outlined,
                                color: const Color(0xFF00FF41),
                                size: 18,
                              ),
                              tooltip: 'Toggle Controls',
                              onPressed: () => setState(
                                () => _showControls = !_showControls,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. Interactive Live System Controls (Confidence Slider & CPU Threads)
                Positioned(
                  bottom: 124,
                  left: 16,
                  right: 16,
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_showControls,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xDD0A0A0A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x4000FF41)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'DETECTION CONFIGURATION',
                              style: TextStyle(
                                color: Color(0x9900FF41),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Row 1: Confidence / Sensitivity Slider
                            Row(
                              children: [
                                const SizedBox(
                                  width: 90,
                                  child: Text(
                                    'CONFIDENCE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: const Color(0xFF00FF41),
                                      inactiveTrackColor:
                                          const Color(0x4000FF41),
                                      thumbColor: const Color(0xFF00FF41),
                                      overlayColor: const Color(0x2000FF41),
                                      thumbShape:
                                          const RoundSliderThumbShape(
                                        enabledThumbRadius: 6,
                                      ),
                                      trackHeight: 2,
                                    ),
                                    child: Slider(
                                      value: _controller.confidenceThreshold,
                                      min: 0.10,
                                      max: 0.90,
                                      divisions: 16,
                                      onChanged: (val) {
                                        _controller.setConfidenceThreshold(
                                          val,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 42,
                                  child: Text(
                                    '${(_controller.confidenceThreshold * 100).toInt()}%',
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      color: Color(0xFF00FF41),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            // Row 2: CPU Threads Controls
                            Row(
                              children: [
                                const SizedBox(
                                  width: 90,
                                  child: Text(
                                    'CPU THREADS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                _buildThreadButton(
                                  label: '-',
                                  onTap: () => _controller.decrementThreads(),
                                ),
                                Container(
                                  width: 36,
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${_controller.cpuThreads}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                _buildThreadButton(
                                  label: '+',
                                  onTap: () => _controller.incrementThreads(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 5. Bottom Telemetry Bar (Latency, FPS, RAM) + Start/Stop Button
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    color: const Color(0xEE050505),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Telemetry Row
                        Row(
                          children: [
                            _buildTelemetryColumn(
                              title: 'LATENCY',
                              value: _controller.lastInferenceMs > 0
                                  ? '${_controller.lastInferenceMs.toStringAsFixed(1)} ms'
                                  : (_controller.isStreaming
                                      ? 'Measuring...'
                                      : 'Paused'),
                              valueColor: Colors.white,
                            ),
                            _buildTelemetryColumn(
                              title: 'FPS',
                              value: _controller.fps > 0
                                  ? '${_controller.fps.toStringAsFixed(0)} FPS'
                                  : (_controller.isStreaming ? '...' : '0 FPS'),
                              valueColor: const Color(0xFF00FF41),
                            ),
                            _buildTelemetryColumn(
                              title: 'RAM USAGE',
                              value: '${_controller.ramUsageMb} MB',
                              valueColor: Colors.white,
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Play/Pause stream toggle button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: Icon(
                              _controller.isStreaming
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              size: 18,
                            ),
                            label: Text(
                              _controller.isStreaming
                                  ? 'PAUSE LIVE DETECTION'
                                  : 'START LIVE DETECTION',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: _controller.isStreaming
                                  ? const Color(0xFF333333)
                                  : const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: () {
                              if (_controller.isStreaming) {
                                _controller.stopStreaming();
                              } else {
                                _controller.startStreaming();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildThreadButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 32,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0x2500FF41),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0x6000FF41)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF00FF41),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryColumn({
    required String title,
    required String value,
    required Color valueColor,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFAAAAAA),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
