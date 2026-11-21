import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';

/// Smooth weight line with a dashed goal line and soft area fill.
class WeightChart extends StatelessWidget {
  const WeightChart({super.key, required this.values, required this.goal});
  final List<double> values;
  final double goal;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Weight trend from ${values.first} to ${values.last} kilograms. Goal $goal.',
      excludeSemantics: true,
      child: SizedBox(
        height: 160,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : Motion.ring,
          curve: Motion.emphasized,
          builder: (_, t, _) => CustomPaint(
            size: Size.infinite,
            painter: _WeightPainter(
              values: values,
              goal: goal,
              t: t,
              line: context.colors.onSurface,
              fill: context.brand.accent,
              grid: context.colors.outlineVariant,
              goalColor: context.brand.success,
              label: context.text.labelSmall!.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeightPainter extends CustomPainter {
  _WeightPainter({
    required this.values,
    required this.goal,
    required this.t,
    required this.line,
    required this.fill,
    required this.grid,
    required this.goalColor,
    required this.label,
  });

  final List<double> values;
  final double goal;
  final double t;
  final Color line;
  final Color fill;
  final Color grid;
  final Color goalColor;
  final TextStyle label;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    const labelW = 34.0;
    final w = size.width - labelW;
    final h = size.height - 8;
    final lo = math.min(values.reduce(math.min), goal) - 0.6;
    final hi = values.reduce(math.max) + 0.6;
    double y(double v) => 4 + h - (v - lo) / (hi - lo) * h;
    double x(int i) => i / (values.length - 1) * w;

    // Grid + labels.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final v in [hi - 0.6, (hi + lo) / 2, lo + 0.6]) {
      canvas.drawLine(Offset(0, y(v)), Offset(w, y(v)), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: v.toStringAsFixed(1), style: label),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(w + 6, y(v) - tp.height / 2));
    }

    // Dashed goal line.
    final gy = y(goal);
    final dash = Paint()
      ..color = goalColor
      ..strokeWidth = 1.5;
    for (var dx = 0.0; dx < w; dx += 8) {
      canvas.drawLine(Offset(dx, gy), Offset(math.min(dx + 4, w), gy), dash);
    }

    // Smooth path.
    final path = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      final px = x(i - 1), py = y(values[i - 1]);
      final cx = x(i), cy = y(values[i]);
      final mx = (px + cx) / 2;
      path.cubicTo(mx, py, mx, cy, cx, cy);
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, w * t + 2, size.height));
    final area = Path.from(path)
      ..lineTo(w, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fill.withValues(alpha: 0.45), fill.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    if (t > 0.98) {
      final end = Offset(x(values.length - 1), y(values.last));
      canvas
        ..drawCircle(end, 7, Paint()..color = fill)
        ..drawCircle(end, 4, Paint()..color = line);
    }
  }

  @override
  bool shouldRepaint(_WeightPainter old) =>
      old.t != t ||
      old.values != values ||
      old.line != line ||
      old.goal != goal;
}

/// Seven daily calorie bars against a goal line.
class WeekBars extends StatelessWidget {
  const WeekBars({
    super.key,
    required this.values,
    required this.labels,
    required this.goal,
    required this.highlight,
  });

  final List<double> values;
  final List<String> labels;
  final double goal;
  final int highlight;

  @override
  Widget build(BuildContext context) {
    final maxV = math.max(goal * 1.15, values.fold<double>(0, math.max));
    final reduce = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      height: 180,
      child: LayoutBuilder(
        builder: (context, c) {
          const labelH = 22.0;
          final chartH = c.maxHeight - labelH;
          final goalY = chartH - goal / maxV * chartH;
          return Stack(
            children: [
              Positioned(
                top: goalY,
                left: 0,
                right: 0,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1.5,
                        color: context.colors.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < values.length; i++)
                    Expanded(
                      child: Semantics(
                        label: '${labels[i]}: ${values[i].round()} calories',
                        excludeSemantics: true,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: 0,
                                end: values[i] / maxV * chartH,
                              ),
                              duration: reduce
                                  ? Duration.zero
                                  : Duration(milliseconds: 600 + i * 60),
                              curve: Motion.emphasized,
                              builder: (_, h, _) => Container(
                                height: math.max(4, h),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: i == highlight
                                      ? context.brand.accent
                                      : values[i] > goal
                                      ? context.colors.error.withValues(
                                          alpha: 0.75,
                                        )
                                      : context.colors.onSurface,
                                  borderRadius: Radii.smAll,
                                ),
                              ),
                            ),
                            SizedBox(
                              height: labelH,
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Text(
                                  labels[i],
                                  style: context.text.labelSmall?.copyWith(
                                    color: i == highlight
                                        ? context.colors.onSurface
                                        : context.colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
