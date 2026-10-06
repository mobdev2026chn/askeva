import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

// ---------------------------------------------------------------------------
// Legacy compat shim
// ---------------------------------------------------------------------------

class TrendSeries {
  final List<double> ys;
  final Color line;
  final Color fill;
  const TrendSeries({required this.ys, required this.line, required this.fill});
}

/// No-op legacy helper – TrendChart now accepts raw values directly.
List<TrendSeries> trendSeriesFromData({
  required List<num> sent,
  required List<num> delivered,
  required List<num> read,
  num? targetYMax,
}) =>
    const [];

// ---------------------------------------------------------------------------
// Y-axis scale helpers
// ---------------------------------------------------------------------------

num getYMax(num maxVal) {
  if (maxVal <= 0) return 10;
  if (maxVal <= 3) return 6;
  if (maxVal <= 6) return 6;
  if (maxVal <= 10) return 10;
  if (maxVal <= 20) return 20;
  if (maxVal <= 60) return 65;
  if (maxVal <= 100) return 110;
  if (maxVal <= 200) return 200;
  if (maxVal <= 300) return 300;
  if (maxVal <= 500) return 500;
  if (maxVal <= 750) return 750;
  if (maxVal <= 1000) return 1000;
  if (maxVal <= 1500) return 1500;
  if (maxVal <= 2000) return 2000;
  if (maxVal <= 2500) return 2500;
  if (maxVal <= 3000) return 3000;
  if (maxVal <= 4000) return 4000;
  if (maxVal <= 5000) return 5000;
  if (maxVal <= 7500) return 7500;
  if (maxVal <= 10000) return 10000;
  final mag = pow(10, (log(maxVal) / ln10).floor()).toInt();
  return ((maxVal / mag).ceil() * mag);
}

List<num> getYTicks(num yMax) {
  if (yMax <= 3) return const [3, 2, 1, 0];
  if (yMax == 6) return const [6, 4, 2, 0];
  if (yMax == 10) return const [10, 8, 6, 4, 2, 0];
  if (yMax == 20) return const [20, 15, 10, 5, 0];
  if (yMax == 65) return const [65, 60, 55, 50, 45, 40, 35, 30, 25, 20, 15, 10, 0];
  if (yMax == 110) return const [110, 100, 90, 80, 70, 60, 50, 40, 30, 20, 10, 0];
  if (yMax == 200) return const [200, 150, 100, 50, 0];
  if (yMax == 300) return const [300, 250, 200, 150, 100, 50, 0];
  if (yMax == 500) return const [500, 400, 300, 200, 100, 0];
  if (yMax == 750) return const [750, 500, 250, 0];
  if (yMax == 1000) return const [1000, 800, 600, 400, 200, 0];
  if (yMax == 1500) return const [1500, 1000, 500, 0];
  if (yMax == 2000) return const [2000, 1600, 1200, 800, 400, 0];
  if (yMax == 2500) return const [2500, 2000, 1500, 1000, 500, 0];
  if (yMax == 3000) return const [3000, 2500, 2000, 1500, 1000, 500, 0];
  if (yMax == 4000) return const [4000, 3000, 2000, 1000, 0];
  if (yMax == 5000) return const [5000, 4000, 3000, 2000, 1000, 0];
  if (yMax == 7500) return const [7500, 5000, 2500, 0];
  if (yMax == 10000) return const [10000, 8000, 6000, 4000, 2000, 0];
  final step = (yMax / 5).ceil();
  return [for (var i = 5; i >= 0; i--) (i * step).round()];
}

// ---------------------------------------------------------------------------
// TrendChart widget
// ---------------------------------------------------------------------------

class TrendChart extends StatefulWidget {
  final List<num> sentValues;
  final List<num> deliveredValues;
  final List<num> readValues;
  final List<String> dates;

  // Optional overrides
  final List<TrendSeries>? series;
  final List<String>? labels;
  final num? yMaxOverride;
  final List<num>? yTicksOverride;

  const TrendChart({
    super.key,
    required this.sentValues,
    required this.deliveredValues,
    required this.readValues,
    required this.dates,
    this.series,
    this.labels,
    this.yMaxOverride,
    this.yTicksOverride,
  });

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  int? _hoveredIndex;
  bool _isHovering = false;

  num get _dataMax {
    num m = 0;
    for (final list in [widget.sentValues, widget.deliveredValues, widget.readValues]) {
      for (final v in list) {
        if (v > m) m = v;
      }
    }
    return m;
  }

  void _onHover(Offset pos, double pL, double pR, int n) {
    if (n < 1) return;
    final ratio = ((pos.dx - pL) / (pR - pL)).clamp(0.0, 1.0);
    final idx = (ratio * (n - 1)).round().clamp(0, n - 1);
    if (_hoveredIndex != idx || !_isHovering) {
      setState(() {
        _hoveredIndex = idx;
        _isHovering = true;
      });
    }
  }

  void _onExit() {
    if (_isHovering) {
      setState(() {
        _isHovering = false;
        _hoveredIndex = null;
      });
    }
  }

  String _fmtDate(String raw) {
    var s = raw.trim().split('T')[0].split(' ')[0];
    final del = s.contains('-') ? '-' : (s.contains('/') ? '/' : null);
    if (del != null) {
      final p = s.split(del);
      if (p.length >= 3) {
        if (p[0].length == 4) return '${p[2].padLeft(2, '0')}/${p[1].padLeft(2, '0')}';
        return '${p[0].padLeft(2, '0')}/${p[1].padLeft(2, '0')}';
      }
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final sent = widget.sentValues;
    final del = widget.deliveredValues;
    final read = widget.readValues;
    final n = sent.length;

    final yMax = widget.yMaxOverride ?? getYMax(_dataMax);
    final yTicks = widget.yTicksOverride ?? getYTicks(yMax);
    final effYMax = yMax > 0 ? yMax : 1;
    final xLabels = widget.dates.map(_fmtDate).toList();

    return LayoutBuilder(builder: (ctx, box) {
      const lm = 40.0;
      const bm = 24.0;
      const tp = 8.0;
      const h = 200.0;
      final w = box.maxWidth;
      final pL = lm;
      final pR = w;
      final pB = h - bm;

      String hovDate = '';
      num hovS = 0, hovD = 0, hovR = 0;
      double hovX = 0;

      if (_isHovering && _hoveredIndex != null && _hoveredIndex! < n) {
        final i = _hoveredIndex!;
        hovDate = i < xLabels.length ? xLabels[i] : '';
        hovS = i < sent.length ? sent[i] : 0;
        hovD = i < del.length ? del[i] : 0;
        hovR = i < read.length ? read[i] : 0;
        hovX = pL + (n > 1 ? i / (n - 1) : 0.5) * (pR - pL);
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _onHover(d.localPosition, pL, pR, n),
        onPanUpdate: (d) => _onHover(d.localPosition, pL, pR, n),
        onPanEnd: (_) => _onExit(),
        onTapDown: (d) => _onHover(d.localPosition, pL, pR, n),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onHover: (e) => _onHover(e.localPosition, pL, pR, n),
          onExit: (_) => _onExit(),
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  size: Size(w, h),
                  painter: _ChartPainter(
                    sent: sent,
                    delivered: del,
                    read: read,
                    xLabels: xLabels,
                    yMax: effYMax,
                    yTicks: yTicks,
                    hoveredIndex: _isHovering ? _hoveredIndex : null,
                    lm: lm,
                    bm: bm,
                    tp: tp,
                  ),
                ),
                if (_isHovering && _hoveredIndex != null)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 80),
                    curve: Curves.easeOut,
                    left: (hovX - 65).clamp(pL, w - 135.0),
                    top: 6,
                    child: Container(
                      width: 130,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(hovDate,
                              style: AppText.poppins(
                                  size: 10, weight: FontWeight.w700, color: Colors.white)),
                          const SizedBox(height: 5),
                          _row(const Color(0xFF177A36), 'Sent', hovS),
                          const SizedBox(height: 3),
                          _row(const Color(0xFF3CC23F), 'Delivered', hovD),
                          const SizedBox(height: 3),
                          _row(const Color(0xFF85D653), 'Read', hovR),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _row(Color c, String label, num val) {
    return Row(children: [
      Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text('$label: ',
          style: AppText.poppins(
              size: 9, weight: FontWeight.w500, color: Colors.white70)),
      Expanded(
          child: Text('$val',
              textAlign: TextAlign.end,
              style: AppText.poppins(
                  size: 9, weight: FontWeight.w700, color: Colors.white))),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _ChartPainter extends CustomPainter {
  final List<num> sent, delivered, read;
  final List<String> xLabels;
  final num yMax;
  final List<num> yTicks;
  final int? hoveredIndex;
  final double lm, bm, tp;

  const _ChartPainter({
    required this.sent,
    required this.delivered,
    required this.read,
    required this.xLabels,
    required this.yMax,
    required this.yTicks,
    required this.hoveredIndex,
    required this.lm,
    required this.bm,
    required this.tp,
  });

  @override
  bool shouldRepaint(_ChartPainter o) =>
      o.hoveredIndex != hoveredIndex || o.sent != sent || o.yMax != yMax;

  @override
  void paint(Canvas canvas, Size size) {
    final pL = lm;
    final pR = size.width;
    final pT = tp;
    final pB = size.height - bm;
    final pw = pR - pL;
    final ph = pB - pT;
    final n = sent.length;
    if (n == 0) return;

    double xAt(int i) => pL + (n > 1 ? i / (n - 1) : 0.5) * pw;
    double yAt(num v) => pB - (v / yMax).clamp(0.0, 1.0) * ph;

    // 1. Y-axis grid + labels
    for (final tick in yTicks) {
      final cy = yAt(tick);
      canvas.drawLine(
        Offset(pL, cy),
        Offset(pR, cy),
        Paint()
          ..color = tick == 0
              ? const Color(0xFFD9E0D6)
              : const Color(0xFFEEF1EC)
          ..strokeWidth = 0.8,
      );
      final lbl = _fmtNum(tick);
      final tp2 = TextPainter(
        text: TextSpan(
            text: lbl,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 8.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp2.paint(canvas, Offset(pL - tp2.width - 4, cy - tp2.height / 2));
    }

    // 2. Series
    final series = [
      (sent, const Color(0xFF177A36)),
      (delivered, const Color(0xFF3CC23F)),
      (read, const Color(0xFF85D653)),
    ];

    for (final (vals, color) in series) {
      if (vals.isEmpty) continue;
      final pts = vals.length == 1 ? [...vals, vals.first] : vals;
      final cnt = pts.length;

      final area = Path()..moveTo(xAt(0), yAt(pts[0]));
      for (var i = 1; i < cnt; i++) {
        area.lineTo(xAt(i), yAt(pts[i]));
      }
      area
        ..lineTo(xAt(cnt - 1), pB)
        ..lineTo(xAt(0), pB)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.30),
              color.withValues(alpha: 0.02)
            ],
          ).createShader(Rect.fromLTRB(pL, pT, pR, pB)),
      );

      final line = Path()..moveTo(xAt(0), yAt(pts[0]));
      for (var i = 1; i < cnt; i++) {
        line.lineTo(xAt(i), yAt(pts[i]));
      }
      canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );

      for (var i = 0; i < cnt; i++) {
        final cx = xAt(i);
        final cy = yAt(pts[i]);
        canvas.drawCircle(Offset(cx, cy), 3.0, Paint()..color = Colors.white);
        canvas.drawCircle(
          Offset(cx, cy),
          3.0,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    // 3. X-axis labels
    final ln = xLabels.length;
    if (ln > 0) {
      final step = ln <= 7 ? 1 : (ln / 6).ceil();
      for (var i = 0; i < ln; i += step) {
        final xPos = xAt(i);
        final tp2 = TextPainter(
          text: TextSpan(
              text: xLabels[i],
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B))),
          textDirection: TextDirection.ltr,
        )..layout();
        tp2.paint(canvas, Offset(xPos - tp2.width / 2, pB + 4));
      }
    }

    // 4. Hover
    if (hoveredIndex != null && hoveredIndex! < n) {
      final hx = xAt(hoveredIndex!);
      final dash = Paint()
        ..color = const Color(0xFF177A36).withValues(alpha: 0.45)
        ..strokeWidth = 1.2;
      double cy = pT;
      while (cy < pB) {
        canvas.drawLine(
            Offset(hx, cy), Offset(hx, (cy + 4).clamp(pT, pB)), dash);
        cy += 7;
      }
      for (final (vals, color) in series) {
        if (hoveredIndex! < vals.length) {
          final hy = yAt(vals[hoveredIndex!]);
          canvas.drawCircle(
              Offset(hx, hy), 5.0, Paint()..color = Colors.white);
          canvas.drawCircle(
            Offset(hx, hy),
            5.0,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0,
          );
        }
      }
    }
  }

  String _fmtNum(num v) {
    if (v >= 1000) {
      final k = v / 1000;
      return k == k.truncate() ? '${k.toInt()}k' : '${k.toStringAsFixed(1)}k';
    }
    return '$v';
  }
}
