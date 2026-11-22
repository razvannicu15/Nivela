import 'package:flutter_test/flutter_test.dart';
import 'package:nivela/core/i18n.dart';
import 'package:nivela/core/level_math.dart';
import 'package:nivela/models/models.dart';
import 'package:nivela/services/meter.dart';
import 'package:nivela/services/sensor.dart';
import 'package:nivela/services/store.dart';

void main() {
  setUp(() {
    setLanguage('en');
    store.profiles.first.offsets.clear();
    store.activeProfile = 0;
    store.autoEdge = true;
    store.every45 = false;
  });

  test('edge angle on every edge', () {
    for (final e in Edge.values) {
      final a = vecForEdge(e, 2.5);
      expect(downEdge(a), e);
      expect(edgeAngle(a, e), closeTo(2.5, 1e-9));
      expect(edgeAngle(vecForEdge(e, -7), e), closeTo(-7, 1e-9));
    }
  });

  test('forward tilt does not change the in-plane angle', () {
    final a = vecForEdge(Edge.bottom, 1.2, forward: 30);
    expect(edgeAngle(a, Edge.bottom), closeTo(1.2, 1e-9));
  });

  test('right end lower means positive', () {
    // Right end lower: gravity has a +x component, so the reading x is negative.
    final a = vecForEdge(Edge.bottom, 3);
    expect(a.x, lessThan(0));
  });

  test('plumb deviation equals the down-edge angle', () {
    for (final e in Edge.values) {
      final a = vecForEdge(e, 1.5);
      expect(plumbDeviation(edgeAngle(a, e.displayLeft)), closeTo(1.5, 1e-9));
      expect(plumbDeviation(edgeAngle(a, e.displayRight)), closeTo(1.5, 1e-9));
    }
  });

  test('flat tilt', () {
    final t = flatTilt(vecForFlat(1, -2));
    expect(t.x, closeTo(1, 1e-9));
    expect(t.y, closeTo(-2, 1e-9));
    expect(flatFace(vecForFlat(0, 0, back: false)), Face.front);
  });

  test('units', () {
    expect(Unit.percent.convert(45)!, closeTo(100, 1e-9));
    expect(Unit.mmPerM.convert(45)!, closeTo(1000, 1e-9));
    expect(Unit.inPerFt.convert(45)!, closeTo(12, 1e-9));
    expect(Unit.percent.convert(90), isNull);
    expect(fmtAngle(-0.04, Unit.degrees, 1), '0.0°');
    expect(fmtAngle(1.25, Unit.percent, 1), '2.2 %');
    setLanguage('ro');
    expect(fmtAngle(1.5, Unit.degrees, 1), '1,5°');
  });

  test('45° targets', () {
    expect(fromTarget(44.6, every45: true), closeTo(-0.4, 1e-9));
    expect(fromTarget(44.6), closeTo(44.6, 1e-9));
    expect(fromTarget(179.5), closeTo(-0.5, 1e-9));
  });

  test('calibration offset removes a constant error', () {
    // Phone reads 0.8° too much on its bottom edge.
    store.profile.offsets[Face.bottom] = [0.8];
    final r = compute(vecForEdge(Edge.bottom, 0.8), Mode.level);
    expect(r.angle, closeTo(0, 1e-9));
    store.profile.offsets[Face.back] = [0.3, -0.2];
    final f = compute(vecForFlat(0.3, -0.2), Mode.flat);
    expect(f.flat!.x, closeTo(0, 1e-9));
    expect(f.flat!.y, closeTo(0, 1e-9));
  });

  test('two readings rotated 180° give the offset, whatever the surface', () {
    const surface = 1.7, offset = 0.4;
    final r1 = edgeAngle(vecForEdge(Edge.bottom, surface + offset), Edge.bottom);
    final r2 = edgeAngle(vecForEdge(Edge.bottom, -surface + offset), Edge.bottom);
    expect((r1 + r2) / 2, closeTo(offset, 1e-9));
  });

  test('sticky edge holds near 45°', () {
    final a = vecForEdge(Edge.bottom, 47);
    expect(downEdge(a), isNot(Edge.bottom));
    expect(stickyDownEdge(a, Edge.bottom), Edge.bottom);
    expect(stickyDownEdge(vecForEdge(Edge.bottom, 60), Edge.bottom), isNot(Edge.bottom));
  });

  test('settings round trip', () {
    store.unit = Unit.mmPerM;
    store.profiles[1].offsets[Face.left] = [0.12];
    store.measurements.add(Measurement(id: '1', time: DateTime(2026, 11, 22), mode: Mode.flat, angle: 1, x: 0.5, y: 0.8, unit: Unit.percent));
    final j = store.toJson();
    final s = Store()..fromJson(j);
    expect(s.unit, Unit.mmPerM);
    expect(s.profiles[1].offsets[Face.left], [0.12]);
    expect(s.measurements.single.y, 0.8);
  });
}
