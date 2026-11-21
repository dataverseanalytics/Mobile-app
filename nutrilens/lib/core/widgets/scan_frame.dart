import 'package:flutter/material.dart';

/// Four rounded corner brackets — the viewfinder motif used on the welcome
/// screen, the camera and the analysing screen.
class ScanFrame extends StatelessWidget {
  const ScanFrame({
    super.key,
    required this.color,
    this.cornerLength = 34,
    this.stroke = 4,
    this.radius = 22,
    this.child,
  });

  final Color color;
  final double cornerLength;
  final double stroke;
  final double radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FramePainter(color, cornerLength, stroke, radius),
      child: child,
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.color, this.len, this.stroke, this.radius);
  final Color color;
  final double len;
  final double stroke;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    final r = radius;

    Path corner(Offset o, double sx, double sy) => Path()
      ..moveTo(o.dx, o.dy + sy * len)
      ..lineTo(o.dx, o.dy + sy * r)
      ..arcToPoint(
        Offset(o.dx + sx * r, o.dy),
        radius: Radius.circular(r),
        clockwise: sx * sy > 0,
      )
      ..lineTo(o.dx + sx * len, o.dy);

    canvas
      ..drawPath(corner(Offset.zero, 1, 1), p)
      ..drawPath(corner(Offset(w, 0), -1, 1), p)
      ..drawPath(corner(Offset(0, h), 1, -1), p)
      ..drawPath(corner(Offset(w, h), -1, -1), p);
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.color != color || old.len != len || old.stroke != stroke;
}
