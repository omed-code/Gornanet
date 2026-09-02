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
                  opacity: theme.brightness == Brightness.dark ? .1 : .055,
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
  const _SpiderWebPainter({required this.color, required this.opacity});

  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width * .76, 320.0);
    final center = Offset(size.width + 8, -8);
    const spokes = 9;
    const rings = 7;

    final spokePaint = Paint()
      ..color = color.withValues(alpha: opacity * .72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var index = 0; index < spokes; index++) {
      final angle = math.pi / 2 + (math.pi / 2) * index / (spokes - 1);
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
        math.pi / 2,
        math.pi / 2,
        false,
        ringPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpiderWebPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.opacity != opacity;
}
