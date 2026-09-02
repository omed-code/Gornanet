import 'dart:math' as math;

import 'package:flutter/material.dart';

class SpiderWebBackground extends StatelessWidget {
  const SpiderWebBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _SpiderWebPainter(
                  color: theme.colorScheme.secondary,
                  accentOpacity: theme.brightness == Brightness.dark
                      ? .1
                      : .055,
                  ambientOpacity: theme.brightness == Brightness.dark
                      ? .042
                      : .026,
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _SpiderWebPainter extends CustomPainter {
  const _SpiderWebPainter({
    required this.color,
    required this.accentOpacity,
    required this.ambientOpacity,
  });

  final Color color;
  final double accentOpacity;
  final double ambientOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final topRight = Offset(size.width + 8, -8);
    _drawWeb(
      canvas,
      center: topRight,
      radius: math.max(size.height * .94, size.width * 1.25),
      startAngle: math.pi / 2,
      sweepAngle: math.pi / 2,
      opacity: ambientOpacity,
      spokes: 12,
      rings: 14,
    );

    _drawWeb(
      canvas,
      center: topRight,
      radius: math.min(size.width * .76, 320),
      startAngle: math.pi / 2,
      sweepAngle: math.pi / 2,
      opacity: accentOpacity,
      spokes: 9,
      rings: 7,
    );
  }

  void _drawWeb(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double startAngle,
    required double sweepAngle,
    required double opacity,
    required int spokes,
    required int rings,
  }) {
    final spokePaint = Paint()
      ..color = color.withValues(alpha: opacity * .72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var index = 0; index < spokes; index++) {
      final angle = startAngle + sweepAngle * index / (spokes - 1);
      canvas.drawLine(
        center,
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        spokePaint,
      );
    }

    for (var index = 1; index <= rings; index++) {
      final progress = index / rings;
      final ringPaint = Paint()
        ..color = color.withValues(alpha: opacity * (1 - progress * .55))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * progress),
        startAngle,
        sweepAngle,
        false,
        ringPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpiderWebPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.accentOpacity != accentOpacity ||
      oldDelegate.ambientOpacity != ambientOpacity;
}
