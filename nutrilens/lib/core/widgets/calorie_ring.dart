import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/theme_x.dart';
import '../theme/tokens.dart';

/// Animated progress ring. Turns to the error colour when over target.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.size,
    this.stroke = 14,
    this.color,
    this.trackColor,
    this.child,
  });

  final double progress;
  final double size;
  final double stroke;
  final Color? color;
  final Color? trackColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    // A little over is normal; only flag clear overshoots.
    final over = progress > 1.05;
    final c = over ? context.colors.error : (color ?? context.colors.onSurface);
    final track = trackColor ?? context.brand.ringTrack;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress.clamp(0, 1).toDouble()),
        duration: reduce ? Duration.zero : Motion.ring,
        curve: Motion.emphasized,
        builder: (context, value, child) => CustomPaint(
          painter: _RingPainter(value, stroke, c, track),
          child: child,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.stroke, this.color, this.track);
  final double value;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect =
        Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, base..color = track);
    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      base..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}
