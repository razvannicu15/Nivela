import 'dart:math' as math;

import 'i18n.dart';

/// Accelerometer reading in Android device axes (m/s²):
/// x → right, y → up, z → out of the screen. Flat on a table: (0, 0, +9.81).
class Vec3 {
  const Vec3(this.x, this.y, this.z);
  final double x, y, z;
  static const zero = Vec3(0, 0, 0);
  double get length => math.sqrt(x * x + y * y + z * z);
  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double k) => Vec3(x * k, y * k, z * k);
  @override
  String toString() => 'Vec3(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

const double _deg = 180 / math.pi;

/// The four edges, in clockwise order as seen from the screen.
enum Edge { bottom, left, top, right }

/// The six faces/edges that can rest on a surface (calibration targets).
enum Face { back, front, bottom, left, top, right }

Face faceOf(Edge e) => Face.values[e.index + 2];

extension EdgeX on Edge {
  /// Turns to apply to the UI so text stays upright when this edge points down.
  int get quarterTurns => const [0, 1, 2, 3][index];

  /// Next edge clockwise: the one on the display's left when this edge is down.
  Edge get displayLeft => Edge.values[(index + 1) % 4];
  Edge get displayRight => Edge.values[(index + 3) % 4];

  // "up" in device coordinates when this edge points down, and "right".
  (double, double) get _up => switch (this) {
        Edge.bottom => (0, 1),
        Edge.left => (1, 0),
        Edge.top => (0, -1),
        Edge.right => (-1, 0),
      };

  String get label => switch (this) {
        Edge.bottom => tr('Jos', 'Bottom'),
        Edge.left => tr('Stânga', 'Left'),
        Edge.top => tr('Sus', 'Top'),
        Edge.right => tr('Dreapta', 'Right'),
      };
}

extension FaceX on Face {
  bool get isFlat => this == Face.back || this == Face.front;
  String get label => switch (this) {
        Face.back => tr('Spate', 'Back'),
        Face.front => tr('Ecran', 'Front'),
        Face.bottom => tr('Muchia de jos', 'Bottom edge'),
        Face.left => tr('Muchia stângă', 'Left edge'),
        Face.top => tr('Muchia de sus', 'Top edge'),
        Face.right => tr('Muchia dreaptă', 'Right edge'),
      };
  String get hint => switch (this) {
        Face.back => tr('Așază telefonul pe spate, cu ecranul în sus.', 'Lay the phone on its back, screen up.'),
        Face.front => tr('Așază telefonul cu ecranul în jos.', 'Lay the phone screen down.'),
        Face.bottom => tr('Sprijină telefonul pe muchia de jos, în picioare.', 'Stand the phone on its bottom edge.'),
        Face.left => tr('Sprijină telefonul pe muchia stângă.', 'Stand the phone on its left edge.'),
        Face.top => tr('Sprijină telefonul pe muchia de sus (cu capul în jos).', 'Stand the phone on its top edge (upside down).'),
        Face.right => tr('Sprijină telefonul pe muchia dreaptă.', 'Stand the phone on its right edge.'),
      };
}

/// Reading rotated into the frame where [e] points down: (right, up).
(double, double) inEdgeFrame(Vec3 a, Edge e) {
  final (ux, uy) = e._up;
  final rx = uy, ry = -ux;
  return (a.x * rx + a.y * ry, a.x * ux + a.y * uy);
}

/// Edge pointing most towards the ground.
Edge downEdge(Vec3 a) {
  var best = Edge.bottom;
  var bestUp = -double.infinity;
  for (final e in Edge.values) {
    final (_, up) = inEdgeFrame(a, e);
    if (up > bestUp) {
      bestUp = up;
      best = e;
    }
  }
  return best;
}

/// Like [downEdge], but keeps [previous] until another edge is clearly lower,
/// so the display does not flip back and forth around 45°.
Edge stickyDownEdge(Vec3 a, Edge? previous) {
  final best = downEdge(a);
  if (previous == null || previous == best) return best;
  final (_, upPrev) = inEdgeFrame(a, previous);
  final (_, upBest) = inEdgeFrame(a, best);
  return upPrev >= upBest * 0.8 && upPrev > 0 ? previous : best;
}

/// Rotation of [e] away from horizontal, in degrees (-180..180).
/// Positive: the display's right end is lower.
double edgeAngle(Vec3 a, Edge e) {
  final (r, u) = inEdgeFrame(a, e);
  return math.atan2(-r, u) * _deg;
}

/// How much of gravity lies in the screen plane (0 = flat, 1 = upright).
double uprightness(Vec3 a) {
  final l = a.length;
  if (l < 1e-6) return 0;
  return math.sqrt(a.x * a.x + a.y * a.y) / l;
}

/// Flat mode: tilt on both axes in degrees. x > 0: right side lower,
/// y > 0: top side lower. [total] is the overall tilt from horizontal.
class FlatTilt {
  const FlatTilt(this.x, this.y);
  final double x, y;
  double get total {
    final tx = math.tan(x / _deg), ty = math.tan(y / _deg);
    return math.atan(math.sqrt(tx * tx + ty * ty)) * _deg;
  }

  /// Direction of the low side on screen, degrees clockwise from "up".
  double get lowDirection => math.atan2(x, y) * _deg;
  FlatTilt operator -(FlatTilt o) => FlatTilt(x - o.x, y - o.y);
}

Face flatFace(Vec3 a) => a.z >= 0 ? Face.back : Face.front;

FlatTilt flatTilt(Vec3 a) {
  final z = a.z.abs() < 1e-6 ? 1e-6 : a.z.abs();
  return FlatTilt(math.atan2(-a.x, z) * _deg, math.atan2(-a.y, z) * _deg);
}

/// Deviation from the nearest target (0°, or a multiple of 45° when enabled).
double fromTarget(double angle, {bool every45 = false}) {
  final step = every45 ? 45.0 : 180.0;
  final t = (angle / step).round() * step;
  return angle - t;
}

/// Plumb: deviation of a vertical edge from true vertical, given the angle of
/// the contact edge measured as if it were lying horizontally (≈ ±90°).
double plumbDeviation(double contactEdgeAngle) {
  final a = contactEdgeAngle;
  final dev = a - (a >= 0 ? 90 : -90);
  return dev > 90 ? dev - 180 : (dev < -90 ? dev + 180 : dev);
}

enum Unit { degrees, percent, mmPerM, inPerFt }

extension UnitX on Unit {
  String get symbol => switch (this) {
        Unit.degrees => '°',
        Unit.percent => '%',
        Unit.mmPerM => 'mm/m',
        Unit.inPerFt => 'in/ft',
      };
  String get label => switch (this) {
        Unit.degrees => tr('Grade (°)', 'Degrees (°)'),
        Unit.percent => tr('Procent (%)', 'Percent (%)'),
        Unit.mmPerM => tr('Milimetri pe metru (mm/m)', 'Millimetres per metre (mm/m)'),
        Unit.inPerFt => tr('Inch pe picior (in/ft)', 'Inches per foot (in/ft)'),
      };

  /// Value in this unit; null when the slope is too steep to express.
  double? convert(double degrees) {
    if (this == Unit.degrees) return degrees;
    if (degrees.abs() >= 89.5) return null;
    final t = math.tan(degrees / _deg);
    return switch (this) {
      Unit.percent => t * 100,
      Unit.mmPerM => t * 1000,
      Unit.inPerFt => t * 12,
      Unit.degrees => degrees,
    };
  }

  /// Extra decimals so the readout has a comparable resolution in every unit.
  int decimalsFor(int degreeDecimals) => switch (this) {
        Unit.degrees => degreeDecimals,
        Unit.percent => degreeDecimals,
        Unit.mmPerM => math.max(0, degreeDecimals - 1),
        Unit.inPerFt => degreeDecimals + 1,
      };
}

String fmtNumber(double v, int decimals) {
  var s = v.toStringAsFixed(decimals);
  if (RegExp(r'^-0(\.0+)?$').hasMatch(s)) s = s.substring(1);
  return isEn ? s : s.replaceAll('.', ',');
}

/// "1,5°", "2,6 %", "—" when not expressible.
String fmtAngle(double degrees, Unit unit, int decimals, {bool signed = false, bool abs = false}) {
  var v = unit.convert(abs ? degrees.abs() : degrees);
  if (v == null) return '—';
  final s = fmtNumber(v, unit.decimalsFor(decimals));
  final sign = signed && v > 0 && double.parse(v.toStringAsFixed(unit.decimalsFor(decimals))) != 0 ? '+' : '';
  return unit == Unit.degrees ? '$sign$s°' : '$sign$s ${unit.symbol}';
}

/// Smooth, saturating map for drawing bubbles: small angles move fast, big ones saturate.
double bubbleOffset(double degrees, {double scale = 6}) {
  final x = degrees / scale;
  // tanh without dart:math support
  final e = math.exp(2 * x.clamp(-10, 10));
  return (e - 1) / (e + 1);
}
