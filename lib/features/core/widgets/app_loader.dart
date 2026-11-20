import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Branded loading indicator: a rotating eight-pointed star (the app emblem)
/// with a breathing centre. Use instead of CircularProgressIndicator.
class AppLoader extends StatefulWidget {
  final double size;
  final Color color;

  const AppLoader({
    super.key,
    this.size = 44,
    this.color = const Color(0xFF0F5C4A),
  });

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            painter: _LoaderPainter(_c.value, widget.color),
          ),
        ),
      ),
    );
  }
}

class _LoaderPainter extends CustomPainter {
  final double t;
  final Color color;

  _LoaderPainter(this.t, this.color);

  Path _star(Offset c, double r, double rot) {
    Path square(double a0) {
      final p = Path();
      for (int i = 0; i < 4; i++) {
        final a = a0 + i * math.pi / 2;
        final pt = c + Offset(math.cos(a), math.sin(a)) * r;
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      return p..close();
    }

    return Path.combine(
        PathOperation.union, square(rot), square(rot + math.pi / 4));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final ease = Curves.easeInOutCubic.transform(t);

    // Faint full star (track)
    canvas.drawPath(
      _star(c, r * 0.92, 0),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09
        ..strokeJoin = StrokeJoin.round
        ..color = color.withOpacity(0.15),
    );

    // Rotating star
    canvas.drawPath(
      _star(c, r * 0.92, ease * math.pi / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    // Breathing centre
    final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
    canvas.drawCircle(
      c,
      r * (0.16 + 0.08 * pulse),
      Paint()..color = color.withOpacity(0.55 + 0.45 * pulse),
    );
  }

  @override
  bool shouldRepaint(covariant _LoaderPainter old) =>
      old.t != t || old.color != color;
}
