import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

enum HandButtonVariant { primary, outline, quiet }

/// A button with a deliberately-imperfect hand-drawn rounded border.
class HandButton extends StatelessWidget {
  const HandButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = HandButtonVariant.primary,
    this.icon,
    this.expand = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final HandButtonVariant variant;
  final IconData? icon;
  final bool expand;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final bool isPrimary = variant == HandButtonVariant.primary;
    final Color fg = switch (variant) {
      HandButtonVariant.primary => AppColors.paper,
      HandButtonVariant.outline => AppColors.ink,
      HandButtonVariant.quiet => AppColors.inkSoft,
    };
    final Color? fill = isPrimary ? AppColors.ink : null;
    final bool disabled = onPressed == null || loading;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: AppSpace.xs),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: fg),
            ),
          ),
        ],
      ],
    );

    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: disabled ? null : onPressed,
          child: CustomPaint(
            painter: variant == HandButtonVariant.quiet
                ? null
                : _HandBorderPainter(
                    fill: fill,
                    stroke: variant == HandButtonVariant.outline
                        ? AppColors.ink
                        : Colors.transparent,
                  ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.lg,
                vertical: AppSpace.sm + 2,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class _HandBorderPainter extends CustomPainter {
  _HandBorderPainter({required this.fill, required this.stroke});
  final Color? fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppRadius.lg),
    );
    if (fill != null) {
      canvas.drawRRect(rrect, Paint()..color = fill!);
    }
    if (stroke.alpha != 0) {
      // Slightly wobble the border for a hand-drawn feel.
      final rnd = math.Random(size.width.round());
      final path = Path();
      const steps = 48;
      for (var i = 0; i <= steps; i++) {
        final t = i / steps;
        final m = _pointOnRRect(rrect, t);
        final jx = (rnd.nextDouble() - 0.5) * 1.1;
        final jy = (rnd.nextDouble() - 0.5) * 1.1;
        if (i == 0) {
          path.moveTo(m.dx + jx, m.dy + jy);
        } else {
          path.lineTo(m.dx + jx, m.dy + jy);
        }
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  Offset _pointOnRRect(RRect r, double t) {
    // Approximate perimeter walk of the rounded rect.
    final rect = r.outerRect;
    final perim = 2 * (rect.width + rect.height);
    var d = t * perim;
    if (d < rect.width) return Offset(rect.left + d, rect.top);
    d -= rect.width;
    if (d < rect.height) return Offset(rect.right, rect.top + d);
    d -= rect.height;
    if (d < rect.width) return Offset(rect.right - d, rect.bottom);
    d -= rect.width;
    return Offset(rect.left, rect.bottom - d);
  }

  @override
  bool shouldRepaint(covariant _HandBorderPainter old) =>
      old.fill != fill || old.stroke != stroke;
}
