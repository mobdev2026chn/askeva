import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

/// One area+line series in [TrendChart]. [ys] are y-values in the design's
/// 320x132 viewBox space (baseline = 122, top = 18), matching the source SVG.
class TrendSeries {
  final List<double> ys;
  final Color line;
  final Color fill;
  const TrendSeries({required this.ys, required this.line, required this.fill});
}

// --- seeded trend regeneration (ports home-dashboard.js chartSVGInner) ---

int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;

int _hashStr(String s) {
  int h = 2166136261;
  for (var i = 0; i < s.length; i++) {
    h ^= s.codeUnitAt(i);
    h = _imul(h, 16777619);
  }
  return h & 0xFFFFFFFF;
}

double Function() _mulberry32(int seed) {
  int a = (seed & 0xFFFFFFFF) == 0 ? 1 : (seed & 0xFFFFFFFF);
  return () {
    a = (a + 0x6D2B79F5) & 0xFFFFFFFF;
    int t = a;
    t = _imul(t ^ (t >> 15), t | 1);
    t = (t + _imul(t ^ (t >> 7), t | 61)) ^ t;
    return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0;
  };
}

/// Regenerates the three trend series for [n] points, deterministically seeded
/// from [seedKey] so the same period/range always draws the same shape. The
/// delivered/read curves are scaled by their ratio to [sent] (matching the
/// design: shape is normalised 0..1, one clear peak per period).
List<TrendSeries> buildTrendSeries({
  required int sent,
  required int delivered,
  required int read,
  required int n,
  required String seedKey,
}) {
  n = n.clamp(2, 32);
  final s = sent <= 0 ? 1 : sent;
  final rDel = (delivered / s).clamp(0.0, 1.0);
  final rRead = (read / s).clamp(0.0, rDel);
  final rnd = _mulberry32(_hashStr(seedKey));
  final pk = (rnd() * n).floor().clamp(0, n - 1);
  final shape = <double>[for (var i = 0; i < n; i++) 0.3 + rnd() * 0.68];
  shape[pk] = 1.0;
  const yTop = 18.0, yBase = 122.0;
  List<double> ys(double scale) => [for (final v in shape) yBase - (v * scale) * (yBase - yTop)];
  return [
    TrendSeries(ys: ys(1), line: const Color(0xFF177A36), fill: const Color(0x521C7A63)),
    TrendSeries(ys: ys(rDel), line: const Color(0xFF3CC23F), fill: const Color(0x6643BE8E)),
    TrendSeries(ys: ys(rRead), line: const Color(0xFF85D653), fill: const Color(0x8C96DEBE)),
  ];
}

/// Returns dynamic yMax upper bound for chart Y-axis scale.
num getYMax(num maxVal) {
  if (maxVal <= 3) return 3;
  if (maxVal <= 10) return 10;
  if (maxVal <= 20) return 20;
  if (maxVal <= 50) return ((maxVal / 10).ceil() * 10);
  if (maxVal <= 100) return ((maxVal / 10).ceil() * 10);
  if (maxVal <= 500) return ((maxVal / 50).ceil() * 50);
  if (maxVal <= 1000) return ((maxVal / 100).ceil() * 100);
  final step = (maxVal / 5).ceil();
  return ((maxVal / step).ceil() * step);
}

/// Returns list of Y-axis tick values from yMax down to 0 matching web dashboard.
List<num> getYTicks(num yMax) {
  if (yMax == 3) return const [3, 2, 1, 0];
  if (yMax == 10) return const [10, 8, 6, 4, 2, 0];
  if (yMax == 20) return const [20, 15, 10, 5, 0];
  const count = 9;
  final step = yMax / count;
  if (step == step.roundToDouble()) {
    return [for (var i = count; i >= 0; i--) (i * step).round()];
  }
  const intervals = 4;
  final stp = yMax / intervals;
  return [for (var i = intervals; i >= 0; i--) (i * stp).round()];
}

/// Builds the three trend series directly from real per-day counts (Sent /
/// Delivered / Read), normalising all three against the global yMax so the
/// plot area matches the Y-axis scale 1:1.
List<TrendSeries> trendSeriesFromData({
  required List<num> sent,
  required List<num> delivered,
  required List<num> read,
}) {
  List<num> pad(List<num> v) => v.length == 1 ? [v.first, v.first] : v;
  sent = pad(sent);
  delivered = pad(delivered);
  read = pad(read);
  const yTop = 18.0, yBase = 122.0;
  num maxV = 0;
  for (final list in [sent, delivered, read]) {
    for (final v in list) {
      if (v > maxV) maxV = v;
    }
  }
  final yMax = getYMax(maxV);
  List<double> ys(List<num> data) =>
      [for (final v in data) yBase - (v / yMax).clamp(0.0, 1.0) * (yBase - yTop)];
  return [
    TrendSeries(ys: ys(sent), line: const Color(0xFF177A36), fill: const Color(0x521C7A63)),
    TrendSeries(ys: ys(delivered), line: const Color(0xFF3CC23F), fill: const Color(0x6643BE8E)),
    TrendSeries(ys: ys(read), line: const Color(0xFF85D653), fill: const Color(0x8C96DEBE)),
  ];
}

/// Replicates the home-dashboard message trend graph (`svg.hm-chart`):
/// three stacked area+line series over Y-axis grid, with X-axis date labels,
/// interactive hover/touch animations, vertical guideline, series point highlights,
/// date badge on X-axis, and floating web-style tooltip popover.
class TrendChart extends StatefulWidget {
  final List<TrendSeries> series;
  final List<String>? dates; // e.g. "2026-07-22"
  final List<num>? sentValues;
  final List<num>? deliveredValues;
  final List<num>? readValues;
  final List<String>? labels;

  const TrendChart({
    super.key,
    required this.series,
    this.dates,
    this.sentValues,
    this.deliveredValues,
    this.readValues,
    this.labels,
  });

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  int? _hoveredIndex;
  bool _isHovering = false;

  num _calcMaxVal() {
    num maxV = 0;
    for (final list in [widget.sentValues, widget.deliveredValues, widget.readValues]) {
      if (list != null) {
        for (final v in list) {
          if (v > maxV) maxV = v;
        }
      }
    }
    return maxV;
  }

  void _onPointerMove(Offset localPos, double width) {
    if (widget.series.isEmpty) return;
    final n = widget.series.first.ys.length;
    if (n < 1) return;

    const double leftMargin = 28.0;
    final plotWidth = width - leftMargin;
    final xPlot = localPos.dx - leftMargin;

    const double vbW = 320, xL = 8, xR = 312;
    final xVb = (xPlot / plotWidth) * vbW;
    final t = (xVb - xL) / (xR - xL);
    final idx = (t * (n - 1)).round().clamp(0, n - 1);

    if (_hoveredIndex != idx || !_isHovering) {
      setState(() {
        _hoveredIndex = idx;
        _isHovering = true;
      });
    }
  }

  void _onPointerExit() {
    if (_isHovering) {
      setState(() {
        _isHovering = false;
        _hoveredIndex = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const height = 168.0;
        const leftMargin = 28.0;
        final plotWidth = width - leftMargin;
        final n = widget.series.isNotEmpty ? widget.series.first.ys.length : 0;

        final maxVal = _calcMaxVal();
        final yMax = getYMax(maxVal);
        final yTicks = getYTicks(yMax);

        final xLabels = <String>[];
        if (widget.dates != null && widget.dates!.isNotEmpty) {
          xLabels.addAll(widget.dates!.where((d) => d.isNotEmpty));
        } else if (widget.labels != null && widget.labels!.isNotEmpty) {
          xLabels.addAll(widget.labels!);
        }

        double pointX = 0;
        if (_hoveredIndex != null && n > 0) {
          const double vbW = 320, xL = 8, xR = 312;
          final double ratio = (n > 1) ? (_hoveredIndex! / (n - 1)) : 0.5;
          pointX = leftMargin + ((xL + ratio * (xR - xL)) / vbW) * plotWidth;
        }

        String dateText = '';
        num sentVal = 0, deliveredVal = 0, readVal = 0;

        if (_hoveredIndex != null) {
          final idx = _hoveredIndex!;

          if (widget.dates != null && idx < widget.dates!.length && widget.dates![idx].isNotEmpty) {
            dateText = widget.dates![idx];
          } else if (widget.labels != null && idx < widget.labels!.length) {
            dateText = widget.labels![idx];
          } else {
            dateText = 'Day ${idx + 1}';
          }

          final valIdx = (widget.sentValues?.length == 1) ? 0 : idx;
          if (widget.sentValues != null && valIdx < widget.sentValues!.length) {
            sentVal = widget.sentValues![valIdx];
          }
          if (widget.deliveredValues != null && valIdx < widget.deliveredValues!.length) {
            deliveredVal = widget.deliveredValues![valIdx];
          }
          if (widget.readValues != null && valIdx < widget.readValues!.length) {
            readVal = widget.readValues![valIdx];
          }
        }

        const double tooltipW = 125.0;
        final tooltipLeft = (pointX - tooltipW / 2).clamp(leftMargin, width - tooltipW - 4.0);

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onHover: (e) => _onPointerMove(e.localPosition, width),
          onExit: (_) => _onPointerExit(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => _onPointerMove(d.localPosition, width),
            onPanUpdate: (d) => _onPointerMove(d.localPosition, width),
            onPanEnd: (_) => _onPointerExit(),
            onTapDown: (d) => _onPointerMove(d.localPosition, width),
            child: SizedBox(
              width: double.infinity,
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    size: Size(width, height),
                    painter: _TrendPainter(
                      widget.series,
                      hoveredIndex: _isHovering ? _hoveredIndex : null,
                      yMax: yMax,
                      yTicks: yTicks,
                      xAxisLabels: xLabels,
                    ),
                  ),

                  // Floating Tooltip Card (Web design)
                  if (_isHovering && _hoveredIndex != null) ...[
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOutCubic,
                      left: tooltipLeft,
                      top: 2,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: _isHovering ? 1.0 : 0.0,
                        child: Container(
                          width: tooltipW,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF212529),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x40000000),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dateText,
                                style: AppText.poppins(size: 11, weight: FontWeight.w700, color: Colors.white),
                              ),
                              const SizedBox(height: 5),
                              _tooltipRow(const Color(0xFF177A36), 'Sent', sentVal),
                              const SizedBox(height: 3),
                              _tooltipRow(const Color(0xFF3CC23F), 'Delivered', deliveredVal),
                              const SizedBox(height: 3),
                              _tooltipRow(const Color(0xFF85D653), 'Read', readVal),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // X-axis Date Badge with Triangle Pointer
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOutCubic,
                      left: (pointX - 40).clamp(leftMargin, width - 80),
                      bottom: 14,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CustomPaint(
                            size: const Size(8, 4),
                            painter: _TrianglePainter(color: const Color(0xFF262626)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF262626),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              dateText,
                              style: AppText.poppins(size: 9, weight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tooltipRow(Color color, String label, num val) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: AppText.poppins(size: 10, weight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.85)),
        ),
        Expanded(
          child: Text(
            '$val',
            textAlign: TextAlign.end,
            style: AppText.poppins(size: 10, weight: FontWeight.w700, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) => oldDelegate.color != color;
}

class _TrendPainter extends CustomPainter {
  final List<TrendSeries> series;
  final int? hoveredIndex;
  final num yMax;
  final List<num> yTicks;
  final List<String> xAxisLabels;

  _TrendPainter(
    this.series, {
    this.hoveredIndex,
    required this.yMax,
    required this.yTicks,
    required this.xAxisLabels,
  });

  static const double _vbW = 320, _vbH = 132, _xL = 8, _xR = 312, _yTop = 18.0, _baseY = 122.0;

  @override
  void paint(Canvas canvas, Size size) {
    const double leftMargin = 28.0;
    const double bottomMargin = 22.0;

    final plotWidth = size.width - leftMargin;
    final plotHeight = size.height - bottomMargin;

    double px(double x) => leftMargin + (x / _vbW) * plotWidth;
    double py(double y) => (y / _vbH) * plotHeight;

    // 1. Draw Y-axis labels and horizontal grid lines for each tick
    final effectiveYMax = yMax > 0 ? yMax : 1;
    for (final tick in yTicks) {
      final ratio = (tick / effectiveYMax).clamp(0.0, 1.0);
      final yVb = _baseY - ratio * (_baseY - _yTop);
      final canvasY = py(yVb);

      // Horizontal grid line
      final linePaint = Paint()
        ..color = (tick == 0) ? const Color(0xFFE4E8E1) : const Color(0xFFEEF1EC)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(px(_xL), canvasY), Offset(px(_xR), canvasY), linePaint);

      // Y-axis tick label text (e.g. 90, 80 ... 0 or 3, 2, 1, 0)
      final tp = TextPainter(
        text: TextSpan(
          text: '$tick',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: Color(0xFF94A3B8),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(leftMargin - tp.width - 5, canvasY - tp.height / 2));
    }

    // 2. Draw Area and Line series
    for (final s in series) {
      final n = s.ys.length;
      if (n < 2) continue;
      double xAt(int i) => px(_xL + i * (_xR - _xL) / (n - 1));

      final area = Path()..moveTo(xAt(0), py(s.ys[0]));
      for (var i = 1; i < n; i++) {
        area.lineTo(xAt(i), py(s.ys[i]));
      }
      area.lineTo(px(_xR), py(_baseY));
      area.lineTo(px(_xL), py(_baseY));
      area.close();
      canvas.drawPath(area, Paint()..color = s.fill);

      final line = Path()..moveTo(xAt(0), py(s.ys[0]));
      for (var i = 1; i < n; i++) {
        line.lineTo(xAt(i), py(s.ys[i]));
      }
      canvas.drawPath(
        line,
        Paint()
          ..color = s.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // 3. Draw X-axis Date Labels below baseline (YYYY-MM-DD)
    if (xAxisLabels.isNotEmpty) {
      final n = xAxisLabels.length;
      final step = (n <= 7) ? 1 : (n / 6).ceil();
      for (var i = 0; i < n; i += step) {
        final double xRatio = (n > 1) ? (i / (n - 1)) : 0.5;
        final xPos = px(_xL + xRatio * (_xR - _xL));
        if (xPos.isNaN || xPos.isInfinite) continue;
        final label = xAxisLabels[i];
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 8.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        final dx = xPos - tp.width / 2;
        final dy = py(_baseY) + 5;
        if (!dx.isNaN && !dy.isNaN && !dx.isInfinite && !dy.isInfinite) {
          tp.paint(canvas, Offset(dx, dy));
        }
      }
    }

    // 4. Draw vertical guide line and series highlight dots when hovered
    if (hoveredIndex != null && series.isNotEmpty) {
      final n = series.first.ys.length;
      if (hoveredIndex! >= 0 && hoveredIndex! < n) {
        final double xRatio = (n > 1) ? (hoveredIndex! / (n - 1)) : 0.5;
        final hX = px(_xL + xRatio * (_xR - _xL));
        if (hX.isNaN || hX.isInfinite) return;

        // Vertical dashed guideline
        final guidePaint = Paint()
          ..color = const Color(0xFF177A36).withValues(alpha: 0.4)
          ..strokeWidth = 1.2;

        final startY = py(_yTop);
        final endY = py(_baseY);
        double currentY = startY;
        const double dashHeight = 4;
        const double dashSpace = 3;
        while (currentY < endY) {
          canvas.drawLine(
            Offset(hX, currentY),
            Offset(hX, (currentY + dashHeight).clamp(startY, endY)),
            guidePaint,
          );
          currentY += dashHeight + dashSpace;
        }

        // Point highlight circles on each series curve
        for (final s in series) {
          if (hoveredIndex! < s.ys.length) {
            final hY = py(s.ys[hoveredIndex!]);
            final pt = Offset(hX, hY);

            // Subtle outer glow
            canvas.drawCircle(pt, 6.5, Paint()..color = Colors.black.withValues(alpha: 0.12));
            // Outer white ring
            canvas.drawCircle(pt, 5.5, Paint()..color = Colors.white);
            // Inner colored dot matching series line
            canvas.drawCircle(pt, 3.5, Paint()..color = s.line);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.series != series ||
      oldDelegate.hoveredIndex != hoveredIndex ||
      oldDelegate.yMax != yMax ||
      oldDelegate.xAxisLabels != xAxisLabels;
}

/// Semicircle gauge used for the "Message Limit" green card.
class SemiGauge extends StatelessWidget {
  final double percent; // 0..1
  final String centerLabel;
  const SemiGauge({super.key, required this.percent, required this.centerLabel});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      height: 72,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          SizedBox(width: 118, height: 66, child: CustomPaint(painter: _GaugePainter(percent))),
          Positioned(
            top: 30,
            child: Text(centerLabel,
                style: AppText.poppins(size: 22, weight: FontWeight.w700, color: Colors.white, height: 1)),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percent;
  _GaugePainter(this.percent);

  @override
  void paint(Canvas canvas, Size size) {
    // viewBox 118x66; arc center ~ (59,58) radius 50, sweeping the top half.
    final rect = Rect.fromCircle(center: const Offset(59, 58), radius: 50);
    final bg = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final fg = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    const start = 3.14159; // 180°
    const sweep = 3.14159; // half circle
    canvas.drawArc(rect, start, sweep, false, bg);
    canvas.drawArc(rect, start, sweep * percent.clamp(0.003, 1.0), false, fg);
    canvas.drawCircle(const Offset(9.5, 58), 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) => oldDelegate.percent != percent;
}

