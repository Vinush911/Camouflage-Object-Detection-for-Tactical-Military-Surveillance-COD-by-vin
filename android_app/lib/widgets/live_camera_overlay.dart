import 'dart:math';
import 'package:flutter/material.dart';
import '../models/target_region.dart';

// Draws a simple detection overlay over the camera preview.
// Shows bounding boxes and classification labels for detected camouflaged objects.
class LiveCameraOverlay extends StatelessWidget {
  final List<TargetRegion> regions;
  final int frameWidth;
  final int frameHeight;
  final bool showFraming;

  const LiveCameraOverlay({
    super.key,
    this.regions = const [],
    required this.frameWidth,
    required this.frameHeight,
    this.showFraming = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LiveOverlayPainter(
        regions: regions,
        frameWidth: frameWidth,
        frameHeight: frameHeight,
        showFraming: showFraming,
      ),
      child: Container(),
    );
  }
}

class _LiveOverlayPainter extends CustomPainter {
  final List<TargetRegion> regions;
  final int frameWidth;
  final int frameHeight;
  final bool showFraming;

  _LiveOverlayPainter({
    required this.regions,
    required this.frameWidth,
    required this.frameHeight,
    required this.showFraming,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final viewWidth = size.width;
    final viewHeight = size.height;

    // Draw simple viewfinder framing guides on the screen
    if (showFraming) {
      _drawHudFraming(canvas, viewWidth, viewHeight);
    }

    if (regions.isEmpty) return;

    // Single stable color for basic detection boxes
    const boxColor = Color(0xFF00FF41);
    final boxPaint = Paint()
      ..color = boxColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = boxColor.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    final cornerPaint = Paint()
      ..color = boxColor
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final tagBg = Paint()
      ..color = boxColor
      ..style = PaintingStyle.fill;

    const tagTextStyle = TextStyle(
      color: Colors.black,
      fontSize: 11,
      fontWeight: FontWeight.bold,
      fontFamily: 'monospace',
    );

    // Calculate scale factor and offsets to map camera coordinates onto the screen
    final scale = (frameWidth > 0 && frameHeight > 0)
        ? max(viewWidth / frameWidth, viewHeight / frameHeight)
        : 1.0;
    final scaledWidth = frameWidth * scale;
    final scaledHeight = frameHeight * scale;
    final offsetX = (viewWidth - scaledWidth) / 2.0;
    final offsetY = (viewHeight - scaledHeight) / 2.0;

    for (final region in regions) {
      final rect = _projectRect(
        region.boundingBox,
        scale,
        offsetX,
        offsetY,
        viewWidth,
        viewHeight,
      );

      // Draw detection box and light translucent background fill
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, boxPaint);

      // Draw corner brackets
      _drawCornerBrackets(canvas, rect, cornerPaint);

      // Text label showing class name and confidence score
      final labelText =
          '${region.displayLabel} ${(region.confidence * 100).toInt()}%';

      _drawTagLabel(
        canvas: canvas,
        text: labelText,
        rect: rect,
        viewWidth: viewWidth,
        textStyle: tagTextStyle,
        bgPaint: tagBg,
      );
    }
  }

  // Converts box coordinates from camera pixel size to phone screen size
  Rect _projectRect(
    Rect box,
    double scale,
    double ox,
    double oy,
    double vw,
    double vh,
  ) {
    if (frameWidth > 0 && frameHeight > 0) {
      return Rect.fromLTRB(
        box.left * scale + ox,
        box.top * scale + oy,
        box.right * scale + ox,
        box.bottom * scale + oy,
      );
    } else {
      return Rect.fromLTRB(
        box.left * vw,
        box.top * vh,
        box.right * vw,
        box.bottom * vh,
      );
    }
  }

  // Draws four corner lines around the bounding box
  void _drawCornerBrackets(Canvas canvas, Rect rect, Paint paint) {
    final cornerLen = min(rect.width * 0.2, 20.0);

    // Top-Left corner
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + cornerLen, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left, rect.top + cornerLen),
      paint,
    );

    // Top-Right corner
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right - cornerLen, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + cornerLen),
      paint,
    );

    // Bottom-Left corner
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + cornerLen, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left, rect.bottom - cornerLen),
      paint,
    );

    // Bottom-Right corner
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right - cornerLen, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right, rect.bottom - cornerLen),
      paint,
    );
  }

  // Draws a simple text badge above or below the bounding box
  void _drawTagLabel({
    required Canvas canvas,
    required String text,
    required Rect rect,
    required double viewWidth,
    required TextStyle textStyle,
    required Paint bgPaint,
  }) {
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    const paddingH = 6.0;
    const paddingV = 3.0;
    final tagW = textPainter.width + (paddingH * 2);
    final tagH = textPainter.height + (paddingV * 2);

    // Position label above the box if there is space, otherwise place below
    double tagX = rect.left;
    double tagY = rect.top - tagH - 4;
    if (tagY < 10) {
      tagY = rect.bottom + 4;
    }
    if (tagX + tagW > viewWidth - 8) {
      tagX = max(8.0, viewWidth - tagW - 8);
    }

    final tagRect = Rect.fromLTWH(tagX, tagY, tagW, tagH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(tagRect, const Radius.circular(3)),
      bgPaint,
    );

    textPainter.paint(canvas, Offset(tagX + paddingH, tagY + paddingV));
  }

  // Draws subtle corner viewfinder guides and center crosshair
  void _drawHudFraming(Canvas canvas, double w, double h) {
    final framingPaint = Paint()
      ..color = const Color(0x3300FF41)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const margin = 20.0;
    const len = 28.0;
    final bMarginY = h - 180.0;

    // Top-Left
    canvas.drawLine(
      const Offset(margin, margin),
      const Offset(margin + len, margin),
      framingPaint,
    );
    canvas.drawLine(
      const Offset(margin, margin),
      const Offset(margin, margin + len),
      framingPaint,
    );

    // Top-Right
    canvas.drawLine(
      Offset(w - margin, margin),
      Offset(w - margin - len, margin),
      framingPaint,
    );
    canvas.drawLine(
      Offset(w - margin, margin),
      Offset(w - margin, margin + len),
      framingPaint,
    );

    // Bottom-Left
    canvas.drawLine(
      Offset(margin, bMarginY),
      Offset(margin + len, bMarginY),
      framingPaint,
    );
    canvas.drawLine(
      Offset(margin, bMarginY),
      Offset(margin, bMarginY - len),
      framingPaint,
    );

    // Bottom-Right
    canvas.drawLine(
      Offset(w - margin, bMarginY),
      Offset(w - margin - len, bMarginY),
      framingPaint,
    );
    canvas.drawLine(
      Offset(w - margin, bMarginY),
      Offset(w - margin, bMarginY - len),
      framingPaint,
    );

    // Center crosshair
    final cx = w / 2.0;
    final cy = (bMarginY + margin) / 2.0;
    const gap = 16.0;
    const lineLen = 18.0;

    canvas.drawLine(
      Offset(cx - gap - lineLen, cy),
      Offset(cx - gap, cy),
      framingPaint,
    );
    canvas.drawLine(
      Offset(cx + gap, cy),
      Offset(cx + gap + lineLen, cy),
      framingPaint,
    );
    canvas.drawLine(
      Offset(cx, cy - gap - lineLen),
      Offset(cx, cy - gap),
      framingPaint,
    );
    canvas.drawLine(
      Offset(cx, cy + gap),
      Offset(cx, cy + gap + lineLen),
      framingPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LiveOverlayPainter oldDelegate) {
    return oldDelegate.regions != regions ||
        oldDelegate.frameWidth != frameWidth ||
        oldDelegate.frameHeight != frameHeight ||
        oldDelegate.showFraming != showFraming;
  }
}
