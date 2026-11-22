import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/level_math.dart';

const _rad = math.pi / 180;

/// Bubble travel: full travel is reached slowly, like a real vial.
const vialScale = 9.0;

TextPainter _label(String t, Color c, double size, {FontWeight w = FontWeight.w600}) => TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontFamily: 'Roboto', color: c, fontSize: size, fontWeight: w)),
      textDirection: TextDirection.ltr,
    )..layout();

/// Flat Material vial: tube, tinted liquid, two marks and a white bubble.
class VialPainter extends CustomPainter {
  VialPainter({required this.angle, required this.cs, required this.accent, required this.tolerance});
  final double angle, tolerance;
  final ColorScheme cs;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final h = size.height;
    final tube = RRect.fromRectAndRadius(rect, Radius.circular(h / 2));
    canvas.drawRRect(tube, Paint()..color = cs.surface);
    canvas.drawRRect(tube, Paint()..color = accent.withValues(alpha: 0.16));
    canvas.drawRRect(tube, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = accent.withValues(alpha: 0.45));

    final pad = h * 0.14;
    final bw = size.width * 0.24, bh = h - 2 * pad;
    final travel = size.width / 2 - bw / 2 - pad;
    final cx = size.width / 2;
    final tol = bw / 2 + 4 + travel * bubbleOffset(tolerance, scale: vialScale).abs();
    final mark = Paint()..color = cs.onSurface.withValues(alpha: 0.7)..strokeWidth = 3..strokeCap = StrokeCap.round;
    final minor = Paint()..color = cs.onSurface.withValues(alpha: 0.28)..strokeWidth = 1.4..strokeCap = StrokeCap.round;
    for (final s in [-1.0, 1.0]) {
      canvas.drawLine(Offset(cx + s * tol, pad), Offset(cx + s * tol, h - pad), mark);
      for (final d in [2.0, 5.0]) {
        final x = cx + s * (bw / 2 + 4 + travel * bubbleOffset(d, scale: vialScale));
        canvas.drawLine(Offset(x, pad), Offset(x, pad + h * 0.16), minor);
        canvas.drawLine(Offset(x, h - pad - h * 0.16), Offset(x, h - pad), minor);
      }
    }
    final bx = cx - bubbleOffset(angle, scale: vialScale) * travel;
    final b = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(bx, h / 2), width: bw, height: bh), Radius.circular(bh / 2));
    canvas.drawRRect(b, Paint()..color = Colors.white);
    canvas.drawRRect(b, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..color = accent);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(b.left + bw * 0.22, b.top + bh * 0.2, bw * 0.4, bh * 0.16), Radius.circular(bh * 0.08)),
        Paint()..color = accent.withValues(alpha: 0.18));
  }

  @override
  bool shouldRepaint(VialPainter o) => o.angle != angle || o.accent != accent || o.cs != cs || o.tolerance != tolerance;
}

/// Round horizon: ground below the true horizon, fixed phone marks, roll ticks.
class AttitudePainter extends CustomPainter {
  AttitudePainter({required this.angle, required this.cs, required this.accent});
  final double angle;
  final ColorScheme cs;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = math.min(size.width, size.height) / 2 - 2;
    final r = outer - 18;

    canvas.drawCircle(c, outer, Paint()..color = cs.surface);
    final tk = Paint()..color = cs.onSurfaceVariant..strokeCap = StrokeCap.round;
    for (var d = -60; d <= 60; d += 5) {
      final a = d * _rad;
      final dir = Offset(math.sin(a), -math.cos(a));
      final major = d % 30 == 0, mid = d % 10 == 0;
      tk.strokeWidth = major ? 2.2 : 1.3;
      tk.color = cs.onSurfaceVariant.withValues(alpha: major ? 0.9 : 0.5);
      canvas.drawLine(c + dir * (r + 4), c + dir * (r + (major ? 15 : (mid ? 11 : 8))), tk);
    }

    final win = Rect.fromCircle(center: c, radius: r);
    canvas.save();
    canvas.clipPath(Path()..addOval(win));
    canvas.drawRect(win, Paint()..color = accent.withValues(alpha: 0.10));
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-angle * _rad);
    canvas.drawRect(Rect.fromLTRB(-r * 1.5, 0, r * 1.5, r * 1.5), Paint()..color = accent);
    canvas.drawLine(Offset(-r * 1.5, 0), Offset(r * 1.5, 0), Paint()..color = cs.surface..strokeWidth = 2.5);
    canvas.drawPath(
        Path()
          ..moveTo(0, -r + 3)
          ..lineTo(-8, -r + 17)
          ..lineTo(8, -r + 17)
          ..close(),
        Paint()..color = accent);
    canvas.restore();
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = accent.withValues(alpha: 0.5));

    final ink = cs.onSurface;
    final top = c + Offset(0, -r - 3);
    canvas.drawPath(
        Path()
          ..moveTo(top.dx, top.dy)
          ..lineTo(top.dx - 7, top.dy - 13)
          ..lineTo(top.dx + 7, top.dy - 13)
          ..close(),
        Paint()..color = ink);
    final wing = Paint()..color = ink..strokeWidth = 4.5..strokeCap = StrokeCap.round;
    canvas.drawLine(c + Offset(-r * 0.7, 0), c + Offset(-r * 0.26, 0), wing);
    canvas.drawLine(c + Offset(r * 0.26, 0), c + Offset(r * 0.7, 0), wing);
    canvas.drawCircle(c, 5, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(AttitudePainter o) => o.angle != angle || o.cs != cs || o.accent != accent;
}

/// Plumb line from the top against the phone's own vertical.
class PlumbPainter extends CustomPainter {
  PlumbPainter({required this.angle, required this.cs, required this.accent, required this.contactLeft});
  final double angle; // + = bob swings right
  final ColorScheme cs;
  final Color accent;
  final bool contactLeft;

  static double visual(double deg) => bubbleOffset(deg, scale: 8) * 30;

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width / 2, 14);
    final len = size.height - 74;

    final ex = contactLeft ? 2.0 : size.width - 2.0;
    canvas.drawLine(Offset(ex, 0), Offset(ex, size.height),
        Paint()..color = accent..strokeWidth = 4..strokeCap = StrokeCap.round);

    final ref = Paint()..color = cs.onSurfaceVariant.withValues(alpha: 0.45)..strokeWidth = 1.4;
    for (var y = pivot.dy; y < pivot.dy + len + 40; y += 11) {
      canvas.drawLine(Offset(pivot.dx, y), Offset(pivot.dx, y + 5), ref);
    }

    final arcR = len + 42;
    final tick = Paint()..color = cs.onSurfaceVariant..strokeCap = StrokeCap.round;
    for (final d in [0.0, 1.0, 2.0, 3.0, 5.0, 10.0]) {
      for (final s in d == 0 ? [1.0] : [-1.0, 1.0]) {
        final a = visual(d * s) * _rad;
        final dir = Offset(math.sin(a), math.cos(a));
        final major = d == 0 || d == 1 || d == 5 || d == 10;
        tick.strokeWidth = major ? 2 : 1.2;
        canvas.drawLine(pivot + dir * (arcR - (major ? 13 : 7)), pivot + dir * arcR, tick);
        if (d == 1 || d == 5 || d == 10) {
          final tp = _label('${d.toInt()}°', cs.onSurfaceVariant, 10.5);
          tp.paint(canvas, pivot + dir * (arcR + 11) - Offset(tp.width / 2, tp.height / 2));
        }
      }
    }

    final va = visual(angle) * _rad;
    canvas.drawArc(Rect.fromCircle(center: pivot, radius: 64), math.pi / 2, -va, true, Paint()..color = accent.withValues(alpha: 0.2));
    final end = pivot + Offset(math.sin(va), math.cos(va)) * len;
    canvas.drawLine(pivot, end, Paint()..color = cs.onSurface..strokeWidth = 1.6);
    canvas.drawCircle(pivot, 5, Paint()..color = cs.onSurface);
    canvas.save();
    canvas.translate(end.dx, end.dy);
    canvas.rotate(-va);
    final bob = Path()
      ..moveTo(0, 40)
      ..lineTo(-13, 12)
      ..quadraticBezierTo(-14, 0, -7, -3)
      ..lineTo(7, -3)
      ..quadraticBezierTo(14, 0, 13, 12)
      ..close();
    canvas.drawPath(bob, Paint()..color = accent);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PlumbPainter o) => o.angle != angle || o.cs != cs || o.accent != accent || o.contactLeft != contactLeft;
}

/// Flat mode: bull's-eye with a free bubble.
class FlatPainter extends CustomPainter {
  FlatPainter({required this.tilt, required this.cs, required this.accent, required this.tolerance});
  final FlatTilt tilt;
  final ColorScheme cs;
  final Color accent;
  final double tolerance;

  static const _scale = 9.0;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 2;
    final br = r * 0.15;
    final travel = r - br - 6;

    canvas.drawCircle(c, r, Paint()..color = cs.surface);
    canvas.drawCircle(c, r, Paint()..color = accent.withValues(alpha: 0.16));
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = accent.withValues(alpha: 0.45));
    final ring = Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = cs.onSurfaceVariant.withValues(alpha: 0.35);
    for (final d in [2.0, 5.0]) {
      final rr = br + bubbleOffset(d, scale: _scale) * travel;
      canvas.drawCircle(c, rr, ring);
      final tp = _label('${d.toInt()}°', cs.onSurfaceVariant, 10.5);
      tp.paint(canvas, c + Offset(rr * 0.71 + 3, -rr * 0.71 - tp.height));
    }
    final cross = Paint()..color = cs.onSurfaceVariant.withValues(alpha: 0.25)..strokeWidth = 1;
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), cross);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), cross);
    canvas.drawCircle(c, br + 4 + bubbleOffset(tolerance, scale: _scale) * travel,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 2.2..color = cs.onSurface.withValues(alpha: 0.75));

    var dir = Offset(-tilt.x, tilt.y);
    final dl = dir.distance;
    dir = dl < 1e-9 ? Offset.zero : dir / dl;
    final p = c + dir * (bubbleOffset(tilt.total, scale: _scale) * travel);
    canvas.drawCircle(p, br, Paint()..color = Colors.white);
    canvas.drawCircle(p, br, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = accent);
    canvas.drawCircle(p + Offset(-br * 0.3, -br * 0.3), br * 0.22, Paint()..color = accent.withValues(alpha: 0.18));
  }

  @override
  bool shouldRepaint(FlatPainter o) =>
      o.tilt.x != tilt.x || o.tilt.y != tilt.y || o.cs != cs || o.accent != accent || o.tolerance != tolerance;
}

/// Two vials in a cross: the horizontal arm is left/right level, the vertical
/// arm is the out-of-plane tilt (back of the phone against a wall).
class CrossVialPainter extends CustomPainter {
  CrossVialPainter({
    required this.roll,
    required this.pitch,
    required this.cs,
    required this.accent,
    required this.rollColor,
    required this.pitchColor,
    required this.tolerance,
  });
  final double roll, pitch, tolerance;
  final ColorScheme cs;
  final Color accent, rollColor, pitchColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final t = (math.min(size.width, size.height) * 0.2).clamp(52.0, 84.0);
    final hLen = size.width;
    final vLen = math.min(size.height, size.width * 1.15);
    final hr = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: hLen, height: t), Radius.circular(t / 2));
    final vr = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: t, height: vLen), Radius.circular(t / 2));
    final cross = Path.combine(PathOperation.union, Path()..addRRect(hr), Path()..addRRect(vr));

    canvas.drawPath(cross, Paint()..color = cs.surface);
    canvas.drawPath(cross, Paint()..color = accent.withValues(alpha: 0.16));
    canvas.drawPath(cross, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = accent.withValues(alpha: 0.45));

    final pad = t * 0.14;
    final bl = t * 1.35, bt = t - 2 * pad; // bubble length / thickness
    final hTravel = hLen / 2 - bl / 2 - pad;
    final vTravel = vLen / 2 - bl / 2 - pad;
    final mark = Paint()..color = cs.onSurface.withValues(alpha: 0.7)..strokeWidth = 3..strokeCap = StrokeCap.round;
    final minor = Paint()..color = cs.onSurface.withValues(alpha: 0.28)..strokeWidth = 1.4..strokeCap = StrokeCap.round;
    for (final s in [-1.0, 1.0]) {
      final hx = c.dx + s * (bl / 2 + 4 + hTravel * bubbleOffset(tolerance, scale: vialScale).abs());
      canvas.drawLine(Offset(hx, c.dy - t / 2 + pad), Offset(hx, c.dy + t / 2 - pad), mark);
      final vy = c.dy + s * (bl / 2 + 4 + vTravel * bubbleOffset(tolerance, scale: vialScale).abs());
      canvas.drawLine(Offset(c.dx - t / 2 + pad, vy), Offset(c.dx + t / 2 - pad, vy), mark);
      for (final d in [2.0, 5.0]) {
        final x = c.dx + s * (bl / 2 + 4 + hTravel * bubbleOffset(d, scale: vialScale));
        canvas.drawLine(Offset(x, c.dy - t / 2 + pad), Offset(x, c.dy - t / 2 + pad + t * 0.16), minor);
        canvas.drawLine(Offset(x, c.dy + t / 2 - pad - t * 0.16), Offset(x, c.dy + t / 2 - pad), minor);
        final y = c.dy + s * (bl / 2 + 4 + vTravel * bubbleOffset(d, scale: vialScale));
        canvas.drawLine(Offset(c.dx - t / 2 + pad, y), Offset(c.dx - t / 2 + pad + t * 0.16, y), minor);
        canvas.drawLine(Offset(c.dx + t / 2 - pad - t * 0.16, y), Offset(c.dx + t / 2 - pad, y), minor);
      }
    }

    void bubble(Rect r, Color border) {
      final rr = RRect.fromRectAndRadius(r, Radius.circular(math.min(r.width, r.height) / 2));
      canvas.drawRRect(rr, Paint()..color = Colors.white);
      canvas.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..color = border);
    }

    // Vertical bubble rises when the screen tilts up; horizontal goes to the high end.
    final vy = c.dy - bubbleOffset(pitch, scale: vialScale) * vTravel;
    bubble(Rect.fromCenter(center: Offset(c.dx, vy), width: bt, height: bl), pitchColor);
    final hx = c.dx - bubbleOffset(roll, scale: vialScale) * hTravel;
    bubble(Rect.fromCenter(center: Offset(hx, c.dy), width: bl, height: bt), rollColor);
  }

  @override
  bool shouldRepaint(CrossVialPainter o) =>
      o.roll != roll || o.pitch != pitch || o.cs != cs || o.accent != accent || o.rollColor != rollColor || o.pitchColor != pitchColor || o.tolerance != tolerance;
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
