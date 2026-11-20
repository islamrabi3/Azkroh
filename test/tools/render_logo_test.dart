import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Path star(Offset c, double r, double rot) {
  Path sq(double a0) {
    final p = Path();
    for (int i = 0; i < 4; i++) {
      final a = a0 + i * math.pi / 2;
      final pt = c + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }
  return Path.combine(PathOperation.union, sq(rot), sq(rot + math.pi / 4));
}

void paintLogo(Canvas canvas, double s, {bool background = true}) {
  final c = Offset(s / 2, s / 2);
  const emerald = Color(0xFF0F5C4A);
  const emeraldDark = Color(0xFF0A3A30);
  const gold = Color(0xFFD9B44A);
  const goldDark = Color(0xFFB08A2E);
  const cream = Color(0xFFFFF8E6);

  if (background) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, s, s),
      Paint()
        ..shader = ui.Gradient.radial(
            c - Offset(0, s * 0.08), s * 0.75, [const Color(0xFF13705A), emeraldDark]),
    );
    // Faint geometric pattern
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.004
      ..color = Colors.white.withOpacity(0.06);
    canvas.drawPath(star(c, s * 0.62, 0), line);
    canvas.drawPath(star(c, s * 0.62, math.pi / 8), line);
    canvas.drawCircle(c, s * 0.47, line);
  }

  // Gold eight-pointed star with soft shadow
  final r = s * 0.34;
  canvas.drawPath(
      star(c + Offset(0, s * 0.012), r, 0),
      Paint()
        ..color = Colors.black.withOpacity(0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.02));
  canvas.drawPath(
      star(c, r, 0),
      Paint()
        ..shader = ui.Gradient.linear(
            c - Offset(r, r), c + Offset(r, r), [const Color(0xFFF0D27A), gold, goldDark],
            [0, 0.55, 1]));
  // Inner thin star outline
  canvas.drawPath(
      star(c, r * 0.86, 0),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.006
        ..color = emeraldDark.withOpacity(0.35));

  // Emerald medallion
  final mr = r * 0.66;
  canvas.drawCircle(c, mr,
      Paint()..shader = ui.Gradient.radial(c - Offset(0, mr * 0.3), mr * 1.2, [emerald, emeraldDark]));
  canvas.drawCircle(
      c,
      mr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.008
        ..color = gold.withOpacity(0.9));

  // Open Mushaf: two curved pages
  final bw = mr * 1.05; // book width
  final bh = mr * 0.62;
  final top = c.dy - bh * 0.35;
  final spine = Offset(c.dx, top + bh * 0.95);
  Path page(bool right) {
    final dir = right ? 1.0 : -1.0;
    final p = Path()..moveTo(c.dx, top + bh * 0.12);
    p.quadraticBezierTo(c.dx + dir * bw * 0.25, top - bh * 0.12,
        c.dx + dir * bw * 0.5, top + bh * 0.02);
    p.lineTo(c.dx + dir * bw * 0.5, top + bh * 0.86);
    p.quadraticBezierTo(c.dx + dir * bw * 0.25, top + bh * 0.72, spine.dx, spine.dy);
    p.close();
    return p;
  }
  final pagePaint = Paint()
    ..shader = ui.Gradient.linear(Offset(c.dx, top), Offset(c.dx, top + bh), [cream, const Color(0xFFF1E3BC)]);
  canvas.drawPath(page(false), pagePaint);
  canvas.drawPath(page(true), pagePaint);
  // Text lines on pages
  final ln = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = s * 0.0075
    ..color = goldDark.withOpacity(0.75);
  for (int i = 0; i < 3; i++) {
    final y = top + bh * (0.3 + i * 0.17);
    for (final dir in [-1.0, 1.0]) {
      final x1 = c.dx + dir * bw * 0.11;
      final x2 = c.dx + dir * bw * 0.4;
      canvas.drawLine(Offset(x1, y + (dir < 0 ? 0 : 0)), Offset(x2, y - bh * 0.03), ln);
    }
  }
  // Spine
  canvas.drawLine(Offset(c.dx, top + bh * 0.12), spine,
      Paint()
        ..strokeWidth = s * 0.006
        ..color = goldDark);

  // Small crescent above the book
  final cc = Offset(c.dx, top - bh * 0.42);
  final cr = mr * 0.17;
  final crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: cc, radius: cr)),
      Path()..addOval(Rect.fromCircle(center: cc + Offset(cr * 0.45, -cr * 0.2), radius: cr * 0.85)));
  canvas.drawPath(crescent, Paint()..color = gold);
}

Future<void> render(String path, double size, {bool background = true}) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  paintLogo(canvas, size, background: background);
  final img = await rec.endRecording().toImage(size.toInt(), size.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('render logo', () async {
    final out = Platform.environment['LOGO_OUT'] ?? 'build';
    await render('$out/azkroh_logo.png', 1024);
    await render('$out/azkroh_logo_fg.png', 1024, background: false);
  });
}
