import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/level_math.dart';

const _rad = math.pi / 180;

/// Level mode: a horizon that stays truly horizontal, plus a spirit vial along
/// the bottom edge (the edge resting on the surface).
class LevelPainter extends CustomPainter {
  LevelPainter({required this.angle, required this.level, required this.cs, required this.alert, required this.tolerance});
  final double angle; // degrees, + = right end lower
  final bool level;
  final ColorScheme cs;
  final Color alert;
  final double tolerance;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.42);
    final big = size.longestSide * 2;
    final accent = level ? alert : cs.primary;

    // Lower half below the true horizon.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-angle * _rad);
    canvas.drawRect(Rect.fromLTRB(-big, 0, big, big), Paint()..color = accent.withValues(alpha: level ? 0.20 : 0.09));
    canvas.drawLine(Offset(-big, 0), Offset(big, 0),
        Paint()
          ..color = accent.withValues(alpha: 0.9)
          ..strokeWidth = level ? 3 : 2);
    canvas.restore();

    // Device horizontal: ticks at both sides and a centre ring.
    final ref = Paint()
      ..color = cs.onSurface.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, c.dy), Offset(28, c.dy), ref);
    canvas.drawLine(Offset(size.width - 28, c.dy), Offset(size.width, c.dy), ref);

    _vial(canvas, size, accent);
  }

  void _vial(Canvas canvas, Size size, Color accent) {
    final w = math.min(size.width * 0.84, 520.0);
    const h = 56.0;
    final rect = Rect.fromCenter(center: Offset(size.width / 2, size.height - h / 2 - 22), width: w, height: h);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(h / 2));
    canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [accent.withValues(alpha: 0.30), accent.withValues(alpha: 0.55), accent.withValues(alpha: 0.30)],
          ).createShader(rect));
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = cs.outline.withValues(alpha: 0.7));

    const bw = 74.0, bh = 36.0;
    final travel = w / 2 - bw / 2 - 8;
    // Marker lines where the bubble sits when within tolerance.
    final m = bw / 2 + 4 + travel * bubbleOffset(tolerance).abs();
    final mk = Paint()
      ..color = cs.onSurface.withValues(alpha: 0.65)
      ..strokeWidth = 2;
    for (final s in [-1, 1]) {
      canvas.drawLine(Offset(rect.center.dx + s * m, rect.top + 6), Offset(rect.center.dx + s * m, rect.bottom - 6), mk);
    }
    final bx = rect.center.dx - bubbleOffset(angle) * travel;
    _bubble(canvas, Rect.fromCenter(center: Offset(bx, rect.center.dy), width: bw, height: bh), cs);
  }

  @override
  bool shouldRepaint(LevelPainter o) =>
      o.angle != angle || o.level != level || o.cs != cs || o.alert != alert || o.tolerance != tolerance;
}

void _bubble(Canvas canvas, Rect r, ColorScheme cs) {
  canvas.drawOval(
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 0.9,
          colors: [Colors.white, Colors.white.withValues(alpha: 0.82), Colors.white.withValues(alpha: 0.55)],
          stops: const [0, 0.55, 1],
        ).createShader(r));
  canvas.drawOval(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.black.withValues(alpha: 0.25));
}

/// Plumb mode: a plumb line hanging from the top, against the phone's own
/// vertical. Small angles are exaggerated so they are visible.
class PlumbPainter extends CustomPainter {
  PlumbPainter({required this.angle, required this.level, required this.cs, required this.alert, required this.contactLeft});
  final double angle; // + = top leans right (bob swings right)
  final bool level;
  final ColorScheme cs;
  final Color alert;
  final bool contactLeft;

  static double visual(double deg) => bubbleOffset(deg, scale: 5) * 32;

  @override
  void paint(Canvas canvas, Size size) {
    final accent = level ? alert : cs.primary;
    final pivot = Offset(size.width / 2, 26);
    final len = size.height * 0.60;

    // Contact edge highlight.
    final ex = contactLeft ? 3.0 : size.width - 3.0;
    canvas.drawLine(Offset(ex, 16), Offset(ex, size.height - 16),
        Paint()
          ..color = accent.withValues(alpha: 0.55)
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round);

    if (level) {
      canvas.drawRect(Offset.zero & size, Paint()..color = alert.withValues(alpha: 0.12));
    }

    // Reference vertical (dashed).
    final ref = Paint()
      ..color = cs.onSurface.withValues(alpha: 0.4)
      ..strokeWidth = 1.5;
    for (var y = pivot.dy; y < pivot.dy + len + 30; y += 12) {
      canvas.drawLine(Offset(pivot.dx, y), Offset(pivot.dx, y + 6), ref);
    }

    // Scale arc with ticks at 1, 2, 5, 10, 20°.
    final arcR = len + 2;
    final tick = Paint()
      ..color = cs.onSurfaceVariant
      ..strokeWidth = 1.6;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final d in [0.0, 1.0, 2.0, 5.0, 10.0, 20.0]) {
      for (final s in d == 0 ? [1] : [-1, 1]) {
        final a = visual(d * s) * _rad;
        final dir = Offset(math.sin(a), math.cos(a));
        final major = d == 0 || d == 5 || d == 10;
        canvas.drawLine(pivot + dir * (arcR + 10), pivot + dir * (arcR + (major ? 26 : 19)), tick);
        if (d >= 5) {
          tp.text = TextSpan(text: '${d.toInt()}°', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11));
          tp.layout();
          final p = pivot + dir * (arcR + 38);
          tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
        }
      }
    }

    // Swept angle.
    final va = visual(angle) * _rad;
    final sweepRect = Rect.fromCircle(center: pivot, radius: 64);
    canvas.drawArc(sweepRect, math.pi / 2, -va, true, Paint()..color = accent.withValues(alpha: 0.22));

    // String and bob.
    final end = pivot + Offset(math.sin(va), math.cos(va)) * len;
    canvas.drawLine(pivot, end,
        Paint()
          ..color = cs.onSurface.withValues(alpha: 0.85)
          ..strokeWidth = 2);
    canvas.drawCircle(pivot, 6, Paint()..color = cs.onSurface);
    final bob = Path()
      ..moveTo(end.dx, end.dy + 34)
      ..quadraticBezierTo(end.dx - 18, end.dy + 4, end.dx, end.dy - 6)
      ..quadraticBezierTo(end.dx + 18, end.dy + 4, end.dx, end.dy + 34)
      ..close();
    canvas.save();
    canvas.translate(end.dx, end.dy);
    canvas.rotate(-va);
    canvas.translate(-end.dx, -end.dy);
    canvas.drawPath(bob, Paint()..color = accent);
    canvas.drawPath(
        bob,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.black.withValues(alpha: 0.2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(PlumbPainter o) =>
      o.angle != angle || o.level != level || o.cs != cs || o.alert != alert || o.contactLeft != contactLeft;
}

/// Flat mode: bull's-eye with a free bubble.
class FlatPainter extends CustomPainter {
  FlatPainter({required this.tilt, required this.level, required this.cs, required this.alert, required this.tolerance});
  final FlatTilt tilt;
  final bool level;
  final ColorScheme cs;
  final Color alert;
  final double tolerance;

  static const _scale = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final accent = level ? alert : cs.primary;
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 6;
    final br = r * 0.17;
    final travel = r - br - 4;

    final disc = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            accent.withValues(alpha: level ? 0.38 : 0.22),
            accent.withValues(alpha: level ? 0.22 : 0.10),
          ]).createShader(disc));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = cs.outline.withValues(alpha: 0.7));

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = cs.onSurface.withValues(alpha: 0.28);
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final d in [1.0, 2.0, 5.0, 10.0]) {
      final rr = bubbleOffset(d, scale: _scale) * travel;
      canvas.drawCircle(c, rr, ring);
      tp.text = TextSpan(text: '${d.toInt()}°', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10.5));
      tp.layout();
      tp.paint(canvas, c + Offset(rr * 0.71 + 3, -rr * 0.71 - tp.height));
    }
    // Target ring: bubble inside it = level.
    canvas.drawCircle(
        c,
        br + bubbleOffset(tolerance, scale: _scale) * travel + 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = cs.onSurface.withValues(alpha: 0.75));
    final cross = Paint()
      ..color = cs.onSurface.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), cross);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), cross);

    // Bubble goes to the high side.
    final t = tilt.total;
    var dir = Offset(-tilt.x, tilt.y);
    final dl = dir.distance;
    dir = dl < 1e-9 ? Offset.zero : dir / dl;
    final p = c + dir * (bubbleOffset(t, scale: _scale) * travel);
    _bubble(canvas, Rect.fromCircle(center: p, radius: br), cs);
  }

  @override
  bool shouldRepaint(FlatPainter o) =>
      o.tilt.x != tilt.x || o.tilt.y != tilt.y || o.level != level || o.cs != cs || o.alert != alert || o.tolerance != tolerance;
}

/// Camera mode overlay: grid, crosshair, true horizon and verticals.
class CameraGuidesPainter extends CustomPainter {
  CameraGuidesPainter({
    required this.angle,
    required this.level,
    required this.alert,
    required this.grid,
    required this.horizon,
    required this.plumbLines,
    required this.crosshair,
    required this.opacity,
  });
  final double angle;
  final bool level;
  final Color alert;
  final int grid;
  final bool horizon, plumbLines, crosshair;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final white = Colors.white.withValues(alpha: 0.55 * opacity);
    final thin = Paint()
      ..color = white
      ..strokeWidth = 1;
    if (grid > 0) {
      for (var i = 1; i < grid; i++) {
        final x = size.width * i / grid, y = size.height * i / grid;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), thin);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), thin);
      }
    }
    final c = size.center(Offset.zero);
    final accent = (level ? alert : Colors.white).withValues(alpha: opacity);
    final big = size.longestSide * 1.5;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.35 * opacity)
      ..strokeWidth = 4.5;
    final main = Paint()
      ..color = accent
      ..strokeWidth = level ? 3 : 2.2;

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-angle * _rad);
    if (horizon) {
      canvas.drawLine(Offset(-big, 0), Offset(-46, 0), shadow);
      canvas.drawLine(Offset(46, 0), Offset(big, 0), shadow);
      canvas.drawLine(Offset(-big, 0), Offset(-46, 0), main);
      canvas.drawLine(Offset(46, 0), Offset(big, 0), main);
    }
    if (plumbLines) {
      final v = Paint()
        ..color = accent.withValues(alpha: 0.8 * opacity)
        ..strokeWidth = 1.6;
      for (final x in [-size.width / 3, size.width / 3]) {
        canvas.drawLine(Offset(x, -big), Offset(x, big), v);
      }
    }
    canvas.restore();

    if (crosshair) {
      final p = Paint()
        ..color = Colors.white.withValues(alpha: 0.9 * opacity)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(c, 30, p);
      canvas.drawLine(c - const Offset(40, 0), c - const Offset(22, 0), p);
      canvas.drawLine(c + const Offset(22, 0), c + const Offset(40, 0), p);
      canvas.drawLine(c - const Offset(0, 8), c + const Offset(0, 8), p);
    }
  }

  @override
  bool shouldRepaint(CameraGuidesPainter o) => true;
}
