import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class DonutSegment {
  final double value;
  final Color color;
  final String? label;
  const DonutSegment(this.value, this.color, {this.label});
}

/// A donut (conic-style) chart with a centered value, matching `.d2-donut`.
class DonutChart extends StatelessWidget {
  final List<DonutSegment> segments;
  final String centerValue;
  final String centerLabel;
  final double size;
  final double thickness;
  final void Function(int index, DonutSegment segment)? onSegmentTap;

  const DonutChart({
    super.key,
    required this.segments,
    required this.centerValue,
    required this.centerLabel,
    this.size = 118,
    this.thickness = 19,
    this.onSegmentTap,
  });

  void _handleTap(Offset localPosition) {
    if (onSegmentTap == null || segments.isEmpty) return;
    final total = segments.fold<double>(0, (a, b) => a + b.value);
    if (total <= 0) return;

    final center = Offset(size / 2, size / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance > size / 2) return;

    double angle = math.atan2(dy, dx);
    double angleFromTop = angle + math.pi / 2;
    if (angleFromTop < 0) {
      angleFromTop += 2 * math.pi;
    }

    double currentStart = 0;
    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final sweep = (seg.value / total) * 2 * math.pi;
      if (angleFromTop >= currentStart && angleFromTop < currentStart + sweep) {
        onSegmentTap!(i, seg);
        break;
      }
      currentStart += sweep;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isNum = double.tryParse(centerValue) != null || int.tryParse(centerValue) != null;
    
    final Widget topWidget;
    final Widget bottomWidget;
    
    if (isNum) {
      topWidget = Text(centerValue,
          style: AppText.poppins(size: 28, weight: FontWeight.w800, color: AppColors.ink, height: 1.1));
      bottomWidget = Text(centerLabel.toUpperCase(),
          style: AppText.poppins(size: 9, weight: FontWeight.w800, color: AppColors.ink4, letterSpacing: 1.4));
    } else {
      topWidget = Text(centerValue,
          style: AppText.poppins(size: 12, weight: FontWeight.w800, color: AppColors.ink4, height: 1.1));
      bottomWidget = Text(centerLabel,
          style: AppText.poppins(size: 28, weight: FontWeight.w800, color: AppColors.ink, height: 1.1));
    }

    final chartWidget = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(segments, thickness),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              topWidget,
              const SizedBox(height: 2),
              bottomWidget,
            ],
          ),
        ),
      ),
    );

    if (onSegmentTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => _handleTap(details.localPosition),
        child: chartWidget,
      );
    }

    return chartWidget;
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSegment> segments;
  final double thickness;
  _DonutPainter(this.segments, this.thickness);

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (a, b) => a + b.value);
    if (total <= 0) return;
    final rect = Rect.fromLTWH(thickness / 2, thickness / 2, size.width - thickness, size.height - thickness);
    double start = -math.pi / 2;
    final gap = 0.012 * 2 * math.pi;
    for (final seg in segments) {
      final sweep = (seg.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start + gap / 2, sweep - gap, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.segments != segments;
}
