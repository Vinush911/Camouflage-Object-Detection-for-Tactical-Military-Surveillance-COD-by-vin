import 'dart:math';
import 'package:flutter/material.dart';
import '../models/target_region.dart';
import '../models/tracked_target.dart';

// Draws tactical surveillance brackets, persistent target numbers, and tracking info
// over the camera feed. Supports threat level color coding:
// - Amber: Potential anomaly / low confidence (50% - 65%)
// - Tactical Green: Tracking lock / intermediate confidence (65% - 75%)
// - Red Flashing: Confirmed camouflaged threat (> 75%)

class LiveCameraOverlay extends StatelessWidget {
  final List<TargetRegion> regions;
  final List<TrackedTarget> trackedTargets;
  final int frameWidth;
  final int frameHeight;
  final bool showFraming;
  final double pulseValue;

  const LiveCameraOverlay({
    super.key,
    this.regions = const [],
    this.trackedTargets = const [],
    required this.frameWidth,
    required this.frameHeight,
    this.showFraming = true,
    this.pulseValue = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LiveOverlayPainter(
        regions: regions,
        trackedTargets: trackedTargets,
        frameWidth: frameWidth,
        frameHeight: frameHeight,
        showFraming: showFraming,
        pulseValue: pulseValue,
      ),
      child: Container(),
    );
  }
}

class _ThreatStyle {
  final Color mainColor;
  final Color fillColor;
  final String statusBadge;
  final bool isHighThreat;

  const _ThreatStyle({
    required this.mainColor,
    required this.fillColor,
    required this.statusBadge,
    required this.isHighThreat,
  });
}

class _LiveOverlayPainter extends CustomPainter {
  final List<TargetRegion> regions;
  final List<TrackedTarget> trackedTargets;
  final int frameWidth;
  final int frameHeight;
  final bool showFraming;
  final double pulseValue;

  _LiveOverlayPainter({
    required this.regions,
    required this.trackedTargets,
    required this.frameWidth,
    required this.frameHeight,
    required this.showFraming,
    this.pulseValue = 1.0,
  });

  // Determines visual styling and alert category based on confidence level
  _ThreatStyle _getThreatStyle(double confidence, bool isOccluded) {
    if (isOccluded) {
      const occludedColor = Color(0xFFFFB300); // Amber warning
      return _ThreatStyle(
        mainColor: occludedColor,
        fillColor: occludedColor.withValues(alpha: 0.08),
        statusBadge: 'SEARCHING...',
        isHighThreat: false,
      );
    }

    if (confidence > 0.75) {
      // High threat: pulsing tactical red to demand immediate attention
      final pulseColor = Color.lerp(
        const Color(0xFFFF1744), // Deep tactical red
        const Color(0xFFFF5252), // Bright flashing red
        pulseValue,
      )!;

      return _ThreatStyle(
        mainColor: pulseColor,
        fillColor: const Color(0xFFFF1744).withValues(alpha: 0.12 + 0.10 * pulseValue),
        statusBadge: 'THREAT',
        isHighThreat: true,
      );
    }

    if (confidence >= 0.65) {
      // Confirmed active lock: solid military green
      const greenColor = Color(0xFF00FF41);
      return _ThreatStyle(
        mainColor: greenColor,
        fillColor: greenColor.withValues(alpha: 0.12),
        statusBadge: 'LOCK',
        isHighThreat: false,
      );
    }

    // Low confidence: amber warning for potential anomalies
    const anomalyColor = Color(0xFFFFB300);
    return _ThreatStyle(
      mainColor: anomalyColor,
      fillColor: anomalyColor.withValues(alpha: 0.10),
      statusBadge: 'ANOMALY',
      isHighThreat: false,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final viewWidth = size.width;
    final viewHeight = size.height;

    // 1. Draw static viewfinder framing brackets and center crosshair
    if (showFraming) {
      _drawHudFraming(canvas, viewWidth, viewHeight);
    }

    final hasTracked = trackedTargets.isNotEmpty;
    final hasRegions = regions.isNotEmpty;

    if (!hasTracked && !hasRegions) return;

    const tagTextStyle = TextStyle(
      color: Colors.black,
      fontSize: 10,
      fontWeight: FontWeight.bold,
      fontFamily: 'monospace',
      letterSpacing: 0.4,
    );

    // 2. Compute scale and offset to align camera frame with screen viewport
    final scale = (frameWidth > 0 && frameHeight > 0)
        ? max(viewWidth / frameWidth, viewHeight / frameHeight)
        : 1.0;
    final scaledWidth = frameWidth * scale;
    final scaledHeight = frameHeight * scale;
    final offsetX = (viewWidth - scaledWidth) / 2.0;
    final offsetY = (viewHeight - scaledHeight) / 2.0;

    // 3. Render tracked targets if available (smooth, persistent IDs), else fallback to raw regions
    if (hasTracked) {
      for (final target in trackedTargets) {
        final box = target.boundingBox;
        final rect = _projectRect(box, scale, offsetX, offsetY, viewWidth, viewHeight);
        final style = _getThreatStyle(target.confidence, target.isOccluded);

        final boxPaint = Paint()
          ..color = style.mainColor
          ..strokeWidth = style.isHighThreat ? 2.5 : 2.0
          ..style = PaintingStyle.stroke;

        final fillPaint = Paint()
          ..color = style.fillColor
          ..style = PaintingStyle.fill;

        final cornerPaint = Paint()
          ..color = style.mainColor
          ..strokeWidth = style.isHighThreat ? 4.5 : 4.0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        final tagBg = Paint()
          ..color = style.mainColor
          ..style = PaintingStyle.fill;

        // Draw translucent inner fill and box outline
        canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, boxPaint);

        // Draw corner targeting brackets
        _drawCornerBrackets(canvas, rect, cornerPaint);

        // Draw small center target reticle (+)
        _drawCenterPip(canvas, rect.center, cornerPaint);

        // Create label text showing target ID, threat badge, confidence percentage, and time tracked
        final labelText = target.isOccluded
            ? '${target.formattedTrackId} [${style.statusBadge}]'
            : '${target.formattedTrackId} ${style.statusBadge} [${(target.confidence * 100).toInt()}%] • ${target.timeOnTarget}';

        _drawTagLabel(
          canvas: canvas,
          text: labelText,
          rect: rect,
          viewWidth: viewWidth,
          textStyle: tagTextStyle,
          bgPaint: tagBg,
        );
      }
    } else {
      // Fallback: draw raw detection regions
      for (final region in regions) {
        final box = region.boundingBox;
        final rect = _projectRect(box, scale, offsetX, offsetY, viewWidth, viewHeight);
        final conf = region.confidence;
        final style = _getThreatStyle(conf, false);

        final boxPaint = Paint()
          ..color = style.mainColor
          ..strokeWidth = style.isHighThreat ? 2.5 : 2.0
          ..style = PaintingStyle.stroke;

        final fillPaint = Paint()
          ..color = style.fillColor
          ..style = PaintingStyle.fill;

        final cornerPaint = Paint()
          ..color = style.mainColor
          ..strokeWidth = style.isHighThreat ? 4.5 : 4.0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        final tagBg = Paint()
          ..color = style.mainColor
          ..style = PaintingStyle.fill;

        canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, boxPaint);
        _drawCornerBrackets(canvas, rect, cornerPaint);

        final labelText = region.isClassified
            ? '#${region.id} ${region.classificationClass!.toUpperCase()} ${(conf * 100).toInt()}%'
            : '#${region.id} ${style.statusBadge} ${(conf * 100).toInt()}%';

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
  }

  // Projects box from camera pixels to phone screen pixels
  Rect _projectRect(Rect box, double scale, double ox, double oy, double vw, double vh) {
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

  // Draws corner bracket tick marks
  void _drawCornerBrackets(Canvas canvas, Rect rect, Paint paint) {
    final cornerLen = min(rect.width * 0.2, 24.0);

    // Top-Left
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left + cornerLen, rect.top), paint);
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left, rect.top + cornerLen), paint);

    // Top-Right
    canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right - cornerLen, rect.top), paint);
    canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right, rect.top + cornerLen), paint);

    // Bottom-Left
    canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left + cornerLen, rect.bottom), paint);
    canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left, rect.bottom - cornerLen), paint);

    // Bottom-Right
    canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right - cornerLen, rect.bottom), paint);
    canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - cornerLen), paint);
  }

  // Draws center reticle pip (+)
  void _drawCenterPip(Canvas canvas, Offset center, Paint paint) {
    const pipSize = 4.0;
    final pipPaint = Paint()
      ..color = paint.color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(center.dx - pipSize, center.dy),
      Offset(center.dx + pipSize, center.dy),
      pipPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - pipSize),
      Offset(center.dx, center.dy + pipSize),
      pipPaint,
    );
  }

  // Draws badge label above or below the bounding box
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

    final paddingH = 6.0;
    final paddingV = 3.0;
    final tagW = textPainter.width + (paddingH * 2);
    final tagH = textPainter.height + (paddingV * 2);

    // Place label above the box if there is room, otherwise place it below
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

  // Draws static viewfinder corner brackets and center crosshair
  void _drawHudFraming(Canvas canvas, double w, double h) {
    final framingPaint = Paint()
      ..color = const Color(0x3300FF41)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const margin = 20.0;
    const len = 32.0;
    final bMarginY = h - 180.0;

    // Viewfinder Top-Left
    canvas.drawLine(const Offset(margin, margin), const Offset(margin + len, margin), framingPaint);
    canvas.drawLine(const Offset(margin, margin), const Offset(margin, margin + len), framingPaint);

    // Viewfinder Top-Right
    canvas.drawLine(Offset(w - margin, margin), Offset(w - margin - len, margin), framingPaint);
    canvas.drawLine(Offset(w - margin, margin), Offset(w - margin, margin + len), framingPaint);

    // Viewfinder Bottom-Left
    canvas.drawLine(Offset(margin, bMarginY), Offset(margin + len, bMarginY), framingPaint);
    canvas.drawLine(Offset(margin, bMarginY), Offset(margin, bMarginY - len), framingPaint);

    // Viewfinder Bottom-Right
    canvas.drawLine(Offset(w - margin, bMarginY), Offset(w - margin - len, bMarginY), framingPaint);
    canvas.drawLine(Offset(w - margin, bMarginY), Offset(w - margin, bMarginY - len), framingPaint);

    // Center crosshair
    final cx = w / 2.0;
    final cy = (bMarginY + margin) / 2.0;
    const gap = 18.0;
    const lineLen = 22.0;

    canvas.drawLine(Offset(cx - gap - lineLen, cy), Offset(cx - gap, cy), framingPaint);
    canvas.drawLine(Offset(cx + gap, cy), Offset(cx + gap + lineLen, cy), framingPaint);
    canvas.drawLine(Offset(cx, cy - gap - lineLen), Offset(cx, cy - gap), framingPaint);
    canvas.drawLine(Offset(cx, cy + gap), Offset(cx, cy + gap + lineLen), framingPaint);
  }

  @override
  bool shouldRepaint(covariant _LiveOverlayPainter oldDelegate) {
    return oldDelegate.regions != regions ||
        oldDelegate.trackedTargets != trackedTargets ||
        oldDelegate.frameWidth != frameWidth ||
        oldDelegate.frameHeight != frameHeight ||
        oldDelegate.showFraming != showFraming ||
        oldDelegate.pulseValue != pulseValue;
  }
}
