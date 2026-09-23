import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/detection_result.dart';
import '../models/target_region.dart';

// Displays the original image with an optional semi-transparent segmentation mask overlay
// and clean bounding box indicators for each detected target.

class MaskOverlayWidget extends StatefulWidget {
  final Uint8List originalImageBytes;
  final DetectionResult result;

  const MaskOverlayWidget({
    super.key,
    required this.originalImageBytes,
    required this.result,
  });

  @override
  State<MaskOverlayWidget> createState() => _MaskOverlayWidgetState();
}

class _MaskOverlayWidgetState extends State<MaskOverlayWidget> {
  bool _showMask = true;
  bool _showBoxes = true;
  double _maskOpacity = 0.55;

  Uint8List? _generatedMaskPngBytes;

  @override
  void initState() {
    super.initState();
    _generateMaskOverlayImage();
  }

  @override
  void didUpdateWidget(covariant MaskOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result.binaryMask != widget.result.binaryMask) {
      _generateMaskOverlayImage();
    }
  }

  // Converts the binary mask into a colored PNG image for overlaying
  void _generateMaskOverlayImage() {
    final mask = widget.result.binaryMask;
    final width = widget.result.maskWidth;
    final height = widget.result.maskHeight;

    if (mask.isEmpty || width <= 0 || height <= 0) {
      setState(() => _generatedMaskPngBytes = null);
      return;
    }

    final maskImage = img.Image(width: width, height: height, numChannels: 4);

    // Teal highlight color for detected camouflage target pixels
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixelValue = mask[y * width + x];
        if (pixelValue > 0) {
          // Semi-transparent teal (R=13, G=148, B=136, Alpha=255)
          maskImage.setPixelRgba(x, y, 13, 148, 136, 255);
        } else {
          // Transparent background
          maskImage.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }

    final pngBytes = Uint8List.fromList(img.encodePng(maskImage));
    setState(() => _generatedMaskPngBytes = pngBytes);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Image & Overlay Viewport
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: widget.result.originalWidth > 0 && widget.result.originalHeight > 0
                ? widget.result.originalWidth / widget.result.originalHeight
                : 1.0,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Original input image
                Image.memory(
                  widget.originalImageBytes,
                  fit: BoxFit.contain,
                ),

                // 2. Semi-transparent segmentation mask overlay
                if (_showMask && _generatedMaskPngBytes != null)
                  Opacity(
                    opacity: _maskOpacity,
                    child: Image.memory(
                      _generatedMaskPngBytes!,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),

                // 3. Clean target bounding boxes and number badges
                if (_showBoxes)
                  CustomPaint(
                    painter: _BoundingBoxPainter(
                      regions: widget.result.regions,
                      imageWidth: widget.result.originalWidth,
                      imageHeight: widget.result.originalHeight,
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Controls bar: toggle mask, toggle boxes, and opacity slider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Mask Toggle
              FilterChip(
                label: const Text('Mask', style: TextStyle(fontSize: 12)),
                selected: _showMask,
                selectedColor: const Color(0xFF0D9488).withValues(alpha: 0.2),
                checkmarkColor: const Color(0xFF0D9488),
                onSelected: (val) => setState(() => _showMask = val),
              ),
              const SizedBox(width: 8),

              // Boxes Toggle
              FilterChip(
                label: const Text('Boxes', style: TextStyle(fontSize: 12)),
                selected: _showBoxes,
                selectedColor: const Color(0xFF1E3A8A).withValues(alpha: 0.2),
                checkmarkColor: const Color(0xFF1E3A8A),
                onSelected: (val) => setState(() => _showBoxes = val),
              ),
              const SizedBox(width: 12),

              // Opacity Slider
              if (_showMask) ...[
                const Text('Opacity:', style: TextStyle(fontSize: 11, color: Colors.black54)),
                Expanded(
                  child: Slider(
                    value: _maskOpacity,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    activeColor: const Color(0xFF0D9488),
                    onChanged: (val) => setState(() => _maskOpacity = val),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// Custom painter to draw bounding boxes scaled to the widget viewport
class _BoundingBoxPainter extends CustomPainter {
  final List<TargetRegion> regions;
  final int imageWidth;
  final int imageHeight;

  _BoundingBoxPainter({
    required this.regions,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageWidth <= 0 || imageHeight <= 0) return;

    final scaleX = size.width / imageWidth;
    final scaleY = size.height / imageHeight;

    final boxPaint = Paint()
      ..color = const Color(0xFF2563EB) // Royal Blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final badgePaint = Paint()
      ..color = const Color(0xFF1E3A8A)
      ..style = PaintingStyle.fill;

    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.bold,
    );

    for (final region in regions) {
      final box = region.boundingBox;
      final scaledRect = Rect.fromLTRB(
        box.left * scaleX,
        box.top * scaleY,
        box.right * scaleX,
        box.bottom * scaleY,
      );

      // Draw box boundary
      canvas.drawRect(scaledRect, boxPaint);

      // Draw target badge label (e.g. "#1 Soldier" or "#1")
      final labelText = region.isClassified
          ? '#${region.id} ${region.classificationClass}'
          : '#${region.id}';

      final textSpan = TextSpan(text: labelText, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final badgeWidth = textPainter.width + 10;
      final badgeHeight = textPainter.height + 4;
      final badgeRect = Rect.fromLTWH(
        scaledRect.left,
        (scaledRect.top - badgeHeight).clamp(0.0, size.height),
        badgeWidth,
        badgeHeight,
      );

      canvas.drawRect(badgeRect, badgePaint);
      textPainter.paint(canvas, Offset(badgeRect.left + 5, badgeRect.top + 2));
    }
  }

  @override
  bool shouldRepaint(covariant _BoundingBoxPainter oldDelegate) {
    return oldDelegate.regions != regions ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight;
  }
}
