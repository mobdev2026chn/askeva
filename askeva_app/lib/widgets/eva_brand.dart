import 'package:flutter/material.dart';

import '../theme/app_assets.dart';
import '../theme/app_typography.dart';

/// "ASK EVA" speech-bubble logo, using the real brand asset.
/// [onGreen] uses the white cut-out (for green surfaces); otherwise the
/// full green branded mark.
class EvaLogo extends StatelessWidget {
  final double height;
  final bool onGreen;

  const EvaLogo({super.key, this.height = 40, this.onGreen = true});

  @override
  Widget build(BuildContext context) {
    if (onGreen) {
      return Image.asset(AppAssets.logoWhite, height: height, fit: BoxFit.contain);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(height * 0.22),
      child: Image.asset(AppAssets.logoGreen, height: height, fit: BoxFit.contain),
    );
  }
}

/// Programmatic "ASK EVA" speech-bubble wordmark (black on transparent),
/// matching the brand mark used on white surfaces (login badge, profile
/// avatar). Used where a black-on-white asset isn't bundled.
class EvaMark extends StatelessWidget {
  final double size;
  final Color color;
  const EvaMark({super.key, this.size = 56, this.color = const Color(0xFF15231A)});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _EvaMarkPainter(color),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Umlaut dots over the "A" in ASK.
              Padding(
                padding: EdgeInsets.only(bottom: size * 0.02),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dot(size * 0.045),
                    SizedBox(width: size * 0.05),
                    _dot(size * 0.045),
                  ],
                ),
              ),
              Text('ASK',
                  style: AppText.poppins(size: size * 0.27, height: 0.95, weight: FontWeight.w900, color: color, letterSpacing: size * 0.005)),
              Text('EVA',
                  style: AppText.poppins(size: size * 0.27, height: 0.95, weight: FontWeight.w900, color: color, letterSpacing: size * 0.005)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(double d) => Container(width: d, height: d, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _EvaMarkPainter extends CustomPainter {
  final Color color;
  _EvaMarkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.055;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round;
    final r = size.width * 0.18;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke * 1.6),
      Radius.circular(r),
    );
    canvas.drawRRect(rect, paint);
    // Speech-bubble tail at bottom-left.
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final tail = Path()
      ..moveTo(size.width * 0.24, size.height * 0.86)
      ..lineTo(size.width * 0.24, size.height * 0.99)
      ..lineTo(size.width * 0.40, size.height * 0.86)
      ..close();
    canvas.drawPath(tail, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The friendly white-and-green Eva mascot (real brand asset).
class EvaMascot extends StatelessWidget {
  final double size;
  const EvaMascot({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return Image.asset(AppAssets.mascot, width: size, height: size, fit: BoxFit.contain);
  }
}
