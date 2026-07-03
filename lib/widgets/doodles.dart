import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Which hand-drawn spot illustration to paint.
enum Doodle { quill, envelope, sprout, spark, folder, heart, moon }

/// A single-weight, deliberately-imperfect line doodle.
///
/// Strokes are given a small deterministic jitter (seeded, not per-frame) so
/// they read as hand-drawn without flickering on rebuild. These are spot
/// illustrations, not an icon set — used sparingly for warmth.
class DoodleIcon extends StatelessWidget {
  const DoodleIcon(
    this.doodle, {
    super.key,
    this.size = 72,
    this.color = AppColors.ink,
    this.strokeWidth = 2.2,
  });

  final Doodle doodle;
  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DoodlePainter(doodle, color, strokeWidth),
      ),
    );
  }
}

class _DoodlePainter extends CustomPainter {
  _DoodlePainter(this.doodle, this.color, this.strokeWidth);

  final Doodle doodle;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    // Deterministic jitter seeded per doodle so strokes look hand-made.
    final rnd = math.Random(doodle.index * 7 + 13);
    Offset j(double x, double y, [double amp = 0.012]) => Offset(
          x * w + (rnd.nextDouble() - 0.5) * amp * w,
          y * h + (rnd.nextDouble() - 0.5) * amp * h,
        );

    Path stroke(List<Offset> pts, {bool close = false}) {
      final p = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        final prev = pts[i - 1];
        final cur = pts[i];
        final mid = Offset((prev.dx + cur.dx) / 2, (prev.dy + cur.dy) / 2);
        p.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      }
      p.lineTo(pts.last.dx, pts.last.dy);
      if (close) p.close();
      return p;
    }

    switch (doodle) {
      case Doodle.quill:
        canvas.drawPath(
          stroke([j(0.22, 0.82), j(0.72, 0.28), j(0.86, 0.16)]),
          paint,
        );
        canvas.drawPath(
          stroke([j(0.72, 0.28), j(0.60, 0.34), j(0.68, 0.44), j(0.82, 0.30)]),
          paint,
        );
        canvas.drawPath(stroke([j(0.22, 0.82), j(0.34, 0.80)]), paint);
        break;
      case Doodle.envelope:
        canvas.drawPath(
          stroke(
            [
              j(0.16, 0.30),
              j(0.84, 0.30),
              j(0.84, 0.74),
              j(0.16, 0.74),
            ],
            close: true,
          ),
          paint,
        );
        canvas.drawPath(
          stroke([j(0.16, 0.30), j(0.50, 0.56), j(0.84, 0.30)]),
          paint,
        );
        break;
      case Doodle.sprout:
        canvas.drawPath(stroke([j(0.50, 0.84), j(0.50, 0.44)]), paint);
        canvas.drawPath(
          stroke([j(0.50, 0.52), j(0.30, 0.40), j(0.34, 0.24), j(0.50, 0.40)]),
          paint,
        );
        canvas.drawPath(
          stroke([j(0.50, 0.48), j(0.70, 0.34), j(0.68, 0.20), j(0.50, 0.36)]),
          paint,
        );
        break;
      case Doodle.spark:
        canvas.drawPath(stroke([j(0.50, 0.16), j(0.50, 0.40)]), paint);
        canvas.drawPath(stroke([j(0.50, 0.60), j(0.50, 0.84)]), paint);
        canvas.drawPath(stroke([j(0.16, 0.50), j(0.40, 0.50)]), paint);
        canvas.drawPath(stroke([j(0.60, 0.50), j(0.84, 0.50)]), paint);
        canvas.drawPath(stroke([j(0.28, 0.28), j(0.42, 0.42)]), paint);
        canvas.drawPath(stroke([j(0.58, 0.58), j(0.72, 0.72)]), paint);
        break;
      case Doodle.folder:
        canvas.drawPath(
          stroke(
            [
              j(0.16, 0.34),
              j(0.42, 0.34),
              j(0.50, 0.42),
              j(0.84, 0.42),
              j(0.84, 0.74),
              j(0.16, 0.74),
            ],
            close: true,
          ),
          paint,
        );
        break;
      case Doodle.heart:
        canvas.drawPath(
          stroke(
            [
              j(0.50, 0.78),
              j(0.20, 0.48),
              j(0.28, 0.26),
              j(0.50, 0.38),
              j(0.72, 0.26),
              j(0.80, 0.48),
              j(0.50, 0.78),
            ],
            close: true,
          ),
          paint,
        );
        break;
      case Doodle.moon:
        canvas.drawPath(
          stroke([
            j(0.62, 0.18),
            j(0.38, 0.30),
            j(0.34, 0.54),
            j(0.46, 0.76),
            j(0.68, 0.82),
            j(0.52, 0.62),
            j(0.50, 0.42),
            j(0.62, 0.18),
          ]),
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter old) =>
      old.doodle != doodle ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
