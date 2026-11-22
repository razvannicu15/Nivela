import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/level_math.dart';

const _rad = math.pi / 180;

/// Bubble travel: full travel is reached slowly, like a real vial.
const vialScale = 9.0;

Color _shade(Color c, double l) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness + l).clamp(0.0, 1.0)).toColor();
}

TextPainter _label(String t, Color c, double size, {FontWeight w = FontWeight.w500}) => TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontFamily: 'Roboto', color: c, fontSize: size, fontWeight: w)),
      textDirection: TextDirection.ltr,
    )..layout();

/// A glass spirit vial in [rect]; [angle] in degrees, + = right end lower.
void paintVial(Canvas canvas, Rect rect, double angle, {required ColorScheme cs, required Color liquid, required double tolerance}) {
  final h = rect.height;
  final housing = RRect.fromRectAndRadius(rect, Radius.circular(h / 2));
  final dark = cs.brightness == Brightness.dark;

  // Housing (metal / plastic frame).
  canvas.drawRRect(
      housing.shift(const Offset(0, 3)), Paint()..color = Colors.black.withValues(alpha: dark ? 0.4 : 0.12)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  canvas.drawRRect(
      housing,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? [const Color(0xFF4A5157), const Color(0xFF2B3035), const Color(0xFF3C4247)]
              : [const Color(0xFFF7F8F9), const Color(0xFFD5DADF), const Color(0xFFEDEFF1)],
        ).createShader(rect));
  canvas.drawRRect(housing, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.black.withValues(alpha: dark ? 0.5 : 0.18));

  // Glass tube with liquid.
  final tubeRect = rect.deflate(h * 0.14);
  final tube = RRect.fromRectAndRadius(tubeRect, Radius.circular(tubeRect.height / 2));
  canvas.save();
  canvas.clipRRect(tube);
  canvas.drawRect(
      tubeRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_shade(liquid, 0.22), _shade(liquid, 0.05), _shade(liquid, -0.08), _shade(liquid, 0.08)],
          stops: const [0, 0.35, 0.8, 1],
        ).createShader(tubeRect));

  // Graduation.
  const bw = 0.27; // bubble width as a fraction of the tube
  final bubbleW = tubeRect.width * bw, bubbleH = tubeRect.height * 0.62;
  final travel = tubeRect.width / 2 - bubbleW / 2 - tubeRect.height * 0.18;
  final cx = tubeRect.center.dx;
  final mark = Paint()..color = Colors.black.withValues(alpha: 0.55)..strokeWidth = 2.4;
  final minor = Paint()..color = Colors.black.withValues(alpha: 0.32)..strokeWidth = 1.4;
  final tolOff = bubbleW / 2 + 3 + travel * bubbleOffset(tolerance, scale: vialScale).abs();
  for (final s in [-1.0, 1.0]) {
    canvas.drawLine(Offset(cx + s * tolOff, tubeRect.top), Offset(cx + s * tolOff, tubeRect.bottom), mark);
    for (final d in [1.0, 2.0, 4.0]) {
      final x = cx + s * (bubbleW / 2 + 3 + travel * bubbleOffset(d, scale: vialScale));
      if ((x - cx).abs() <= tolOff + 4) continue;
      canvas.drawLine(Offset(x, tubeRect.top), Offset(x, tubeRect.top + tubeRect.height * 0.22), minor);
      canvas.drawLine(Offset(x, tubeRect.bottom - tubeRect.height * 0.22), Offset(x, tubeRect.bottom), minor);
    }
  }

  // Bubble: goes to the high end.
  final bx = cx - bubbleOffset(angle, scale: vialScale) * travel;
  final br = Rect.fromCenter(center: Offset(bx, tubeRect.center.dy - tubeRect.height * 0.06), width: bubbleW, height: bubbleH);
  final bubble = RRect.fromRectAndRadius(br, Radius.circular(bubbleH / 2));
  canvas.drawRRect(
      bubble,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 0.9,
          colors: [Colors.white.withValues(alpha: 0.95), Color.lerp(Colors.white, liquid, 0.25)!.withValues(alpha: 0.9), _shade(liquid, -0.12)],
          stops: const [0, 0.7, 1],
        ).createShader(br));
  canvas.drawRRect(bubble, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = _shade(liquid, -0.25).withValues(alpha: 0.7));
  canvas.drawOval(
      Rect.fromLTWH(br.left + br.width * 0.18, br.top + br.height * 0.16, br.width * 0.42, br.height * 0.28),
      Paint()..color = Colors.white.withValues(alpha: 0.9));

  // Glass shine and inner shadow.
  canvas.drawRect(
      Rect.fromLTRB(tubeRect.left, tubeRect.top, tubeRect.right, tubeRect.top + tubeRect.height * 0.45),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.45), Colors.white.withValues(alpha: 0)],
        ).createShader(tubeRect));
  canvas.restore();
  canvas.drawRRect(tube, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = Colors.black.withValues(alpha: 0.28));
}

/// Level mode: true horizon, roll scale with pointer, and the vial.
class LevelPainter extends CustomPainter {
  LevelPainter({required this.angle, required this.level, required this.cs, required this.alert, required this.tolerance});
  final double angle; // degrees, + = right end lower
  final bool level;
  final ColorScheme cs;
  final Color alert;
  final double tolerance;

  static Offset center(Size s) => Offset(s.width / 2, s.height * 0.62);
  static double radius(Size s) => math.min(s.width * 0.44, s.height * 0.46);

  @override
  void paint(Canvas canvas, Size size) {
    final c = center(size);
    final r = radius(size);
    final big = size.longestSide * 2;
    final accent = level ? alert : cs.primary;

    // Ground below the true horizon, fading downwards.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-angle * _rad);
    final ground = Rect.fromLTRB(-big, 0, big, size.height);
    canvas.drawRect(
        Rect.fromLTRB(-big, 0, big, big),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [accent.withValues(alpha: level ? 0.26 : 0.16), accent.withValues(alpha: level ? 0.10 : 0.04)],
          ).createShader(ground));
    canvas.drawLine(Offset(-big, 0), Offset(big, 0), Paint()..color = accent..strokeWidth = level ? 3 : 2.2);
    canvas.restore();

    // Fixed roll scale (device), ±45°.
    final tick = Paint()..color = cs.onSurfaceVariant.withValues(alpha: 0.75)..strokeCap = StrokeCap.round;
    for (var d = -45; d <= 45; d++) {
      final major = d % 10 == 0, mid = d % 5 == 0;
      if (!major && !mid && d.abs() > 5) continue;
      final a = d * _rad;
      final dir = Offset(math.sin(a), -math.cos(a));
      final len = major ? 16.0 : (mid ? 10.0 : 6.0);
      tick.strokeWidth = major ? 2.2 : 1.4;
      canvas.drawLine(c + dir * r, c + dir * (r + len), tick);
      if (major && d != 0) {
        final tp = _label('${d.abs()}°', cs.onSurfaceVariant, 12);
        tp.paint(canvas, c + dir * (r + 28) - Offset(tp.width / 2, tp.height / 2));
      }
    }
    // Index at 0°.
    final top = c + Offset(0, -r - 20);
    canvas.drawPath(
        Path()
          ..moveTo(top.dx, top.dy + 4)
          ..lineTo(top.dx - 7, top.dy - 8)
          ..lineTo(top.dx + 7, top.dy - 8)
          ..close(),
        Paint()..color = cs.onSurface);

    // Pointer: true "up", moves with gravity.
    final up = Offset(-math.sin(angle * _rad), -math.cos(angle * _rad));
    final perp = Offset(-up.dy, up.dx);
    final tip = c + up * (r - 2);
    canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo((tip - up * 18 + perp * 9).dx, (tip - up * 18 + perp * 9).dy)
          ..lineTo((tip - up * 18 - perp * 9).dx, (tip - up * 18 - perp * 9).dy)
          ..close(),
        Paint()..color = accent);

    // Device reference marks at the sides.
    final ref = Paint()..color = cs.onSurface.withValues(alpha: 0.6)..strokeWidth = 2.5..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(14, c.dy), Offset(40, c.dy), ref);
    canvas.drawLine(Offset(size.width - 40, c.dy), Offset(size.width - 14, c.dy), ref);

    final vw = math.min(size.width - 40, 460.0);
    paintVial(canvas, Rect.fromCenter(center: Offset(size.width / 2, size.height - 52), width: vw, height: 62), angle,
        cs: cs, liquid: accent, tolerance: tolerance);
  }

  @override
  bool shouldRepaint(LevelPainter o) =>
      o.angle != angle || o.level != level || o.cs != cs || o.alert != alert || o.tolerance != tolerance;
}

/// Plumb mode: plumb line from the top, against the phone's own vertical.
class PlumbPainter extends CustomPainter {
  PlumbPainter({required this.angle, required this.level, required this.cs, required this.alert, required this.contactLeft});
  final double angle; // + = top leans right (bob swings right)
  final bool level;
  final ColorScheme cs;
  final Color alert;
  final bool contactLeft;

  static double visual(double deg) => bubbleOffset(deg, scale: 8) * 30;

  @override
  void paint(Canvas canvas, Size size) {
    final accent = level ? alert : cs.primary;
    final pivot = Offset(size.width / 2, 40);
    final len = size.height * 0.56;

    // Contact edge.
    final ex = contactLeft ? 0.0 : size.width;
    canvas.drawRect(Rect.fromLTRB(ex - 5, 0, ex + 5, size.height), Paint()..color = accent.withValues(alpha: 0.8));

    // Reference vertical.
    final ref = Paint()..color = cs.onSurface.withValues(alpha: 0.35)..strokeWidth = 1.5;
    for (var y = pivot.dy; y < pivot.dy + len + 36; y += 12) {
      canvas.drawLine(Offset(pivot.dx, y), Offset(pivot.dx, y + 6), ref);
    }

    // Scale arc.
    final arcR = len + 46;
    final tick = Paint()..color = cs.onSurfaceVariant..strokeCap = StrokeCap.round;
    for (final d in [0.0, 0.5, 1.0, 2.0, 3.0, 5.0, 10.0]) {
      for (final s in d == 0 ? [1.0] : [-1.0, 1.0]) {
        final a = visual(d * s) * _rad;
        final dir = Offset(math.sin(a), math.cos(a));
        final major = d == 0 || d == 1 || d == 5 || d == 10;
        tick.strokeWidth = major ? 2.2 : 1.3;
        canvas.drawLine(pivot + dir * (arcR - (major ? 14 : 8)), pivot + dir * arcR, tick);
        if (d == 1 || d == 5 || d == 10) {
          final tp = _label('${d.toInt()}°', cs.onSurfaceVariant, 11);
          tp.paint(canvas, pivot + dir * (arcR + 13) - Offset(tp.width / 2, tp.height / 2));
        }
      }
    }

    final va = visual(angle) * _rad;
    canvas.drawArc(Rect.fromCircle(center: pivot, radius: 70), math.pi / 2, -va, true, Paint()..color = accent.withValues(alpha: 0.25));

    // Mount.
    final mount = RRect.fromRectAndRadius(Rect.fromCenter(center: pivot - const Offset(0, 14), width: 56, height: 16), const Radius.circular(6));
    canvas.drawRRect(mount, Paint()..color = cs.onSurface.withValues(alpha: 0.75));

    // String and bob.
    final dir = Offset(math.sin(va), math.cos(va));
    final end = pivot + dir * len;
    canvas.drawLine(pivot, end, Paint()..color = cs.onSurface.withValues(alpha: 0.85)..strokeWidth = 1.8);
    canvas.drawCircle(pivot, 5, Paint()..color = cs.onSurface);
    canvas.save();
    canvas.translate(end.dx, end.dy);
    canvas.rotate(-va);
    final bob = Path()
      ..moveTo(0, 46)
      ..lineTo(-15, 14)
      ..quadraticBezierTo(-17, 0, -8, -4)
      ..lineTo(8, -4)
      ..quadraticBezierTo(17, 0, 15, 14)
      ..close();
    canvas.drawPath(bob.shift(const Offset(2, 4)), Paint()..color = Colors.black.withValues(alpha: 0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawPath(
        bob,
        Paint()
          ..shader = LinearGradient(colors: [_shade(accent, 0.2), accent, _shade(accent, -0.15)], stops: const [0, 0.45, 1])
              .createShader(const Rect.fromLTRB(-17, -4, 17, 46)));
    canvas.drawRect(const Rect.fromLTRB(-5, -10, 5, -3), Paint()..color = cs.onSurface.withValues(alpha: 0.8));
    canvas.restore();
  }

  @override
  bool shouldRepaint(PlumbPainter o) =>
      o.angle != angle || o.level != level || o.cs != cs || o.alert != alert || o.contactLeft != contactLeft;
}

/// Flat mode: bull's-eye vial with a bezel and a free bubble.
class FlatPainter extends CustomPainter {
  FlatPainter({required this.tilt, required this.level, required this.cs, required this.alert, required this.tolerance});
  final FlatTilt tilt;
  final bool level;
  final ColorScheme cs;
  final Color alert;
  final double tolerance;

  static const _scale = 9.0;

  @override
  void paint(Canvas canvas, Size size) {
    final accent = level ? alert : cs.primary;
    final dark = cs.brightness == Brightness.dark;
    final c = size.center(Offset.zero);
    final outer = math.min(size.width, size.height) / 2 - 4;
    final r = outer - 14;
    final br = r * 0.16;
    final travel = r - br - 6;

    // Bezel.
    canvas.drawCircle(c + const Offset(0, 4), outer, Paint()..color = Colors.black.withValues(alpha: dark ? 0.45 : 0.14)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawCircle(
        c,
        outer,
        Paint()
          ..shader = SweepGradient(colors: dark
                  ? const [Color(0xFF4A5157), Color(0xFF2B3035), Color(0xFF50575D), Color(0xFF2B3035), Color(0xFF4A5157)]
                  : const [Color(0xFFF7F8F9), Color(0xFFCDD3D8), Color(0xFFF2F4F5), Color(0xFFCDD3D8), Color(0xFFF7F8F9)])
              .createShader(Rect.fromCircle(center: c, radius: outer)));
    // Bezel ticks every 10°.
    final bt = Paint()..color = (dark ? Colors.white : Colors.black).withValues(alpha: 0.3)..strokeWidth = 1.2;
    for (var k = 0; k < 36; k++) {
      final a = k * 10 * _rad;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * (outer - (k % 9 == 0 ? 11 : 6)), c + d * (outer - 2), bt);
    }

    // Liquid face.
    final face = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.2, -0.3),
            colors: [_shade(accent, 0.28), _shade(accent, 0.12), _shade(accent, -0.02)],
            stops: const [0, 0.7, 1],
          ).createShader(face));

    final ring = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = Colors.black.withValues(alpha: 0.28);
    for (final d in [1.0, 2.0, 5.0]) {
      final rr = br + bubbleOffset(d, scale: _scale) * travel;
      canvas.drawCircle(c, rr, ring);
      final tp = _label('${d.toInt()}°', Colors.black.withValues(alpha: 0.55), 10.5);
      tp.paint(canvas, c + Offset(rr * 0.71 + 2, -rr * 0.71 - tp.height));
    }
    final cross = Paint()..color = Colors.black.withValues(alpha: 0.22)..strokeWidth = 1;
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), cross);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), cross);
    // Target ring.
    canvas.drawCircle(c, br + 3 + bubbleOffset(tolerance, scale: _scale) * travel,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 2.6..color = Colors.black.withValues(alpha: 0.6));

    // Bubble towards the high side.
    var dir = Offset(-tilt.x, tilt.y);
    final dl = dir.distance;
    dir = dl < 1e-9 ? Offset.zero : dir / dl;
    final p = c + dir * (bubbleOffset(tilt.total, scale: _scale) * travel);
    final b = Rect.fromCircle(center: p, radius: br);
    canvas.drawCircle(p + const Offset(0, 3), br, Paint()..color = _shade(accent, -0.25).withValues(alpha: 0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(
        p,
        br,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.35),
            colors: [Colors.white, Color.lerp(Colors.white, accent, 0.2)!, _shade(accent, -0.05)],
            stops: const [0, 0.65, 1],
          ).createShader(b));
    canvas.drawCircle(p, br, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = _shade(accent, -0.3).withValues(alpha: 0.7));

    // Glass shine.
    canvas.save();
    canvas.clipPath(Path()..addOval(face));
    canvas.drawOval(
        Rect.fromLTWH(c.dx - r * 0.75, c.dy - r * 0.95, r * 1.5, r * 0.9),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0)],
          ).createShader(face));
    canvas.restore();
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = Colors.black.withValues(alpha: 0.3));
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
