import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/level_math.dart';
import 'store.dart';

/// Accelerometer stream (via MainActivity.kt), low-pass filtered, with
/// stillness detection and Android's accuracy status.
class Sensor extends ChangeNotifier {
  Sensor._();
  static final instance = Sensor._();

  static const _events = EventChannel('nivela/sensor');
  StreamSubscription<dynamic>? _sub;
  int _users = 0;

  /// Filtered reading, updated ~50 times a second.
  Vec3 value = const Vec3(0, 9.81, 0);

  /// Android accuracy: 3 high, 2 medium, 1 low, 0 unreliable, -1 unknown.
  int accuracy = -1;

  /// False until the first sample arrives (or no sensor at all).
  bool hasData = false;

  final _window = ListQueue<Vec3>();
  static const _windowSize = 40; // ≈ 0.8 s

  bool get lowAccuracy => accuracy == 0 || accuracy == 1;

  /// Spread of the last raw samples (m/s²). Small = phone held still.
  double get jitter {
    if (_window.length < 10) return 99;
    var mx = 0.0, my = 0.0, mz = 0.0;
    for (final v in _window) {
      mx += v.x;
      my += v.y;
      mz += v.z;
    }
    final n = _window.length;
    mx /= n;
    my /= n;
    mz /= n;
    var s = 0.0;
    for (final v in _window) {
      s += (v.x - mx) * (v.x - mx) + (v.y - my) * (v.y - my) + (v.z - mz) * (v.z - mz);
    }
    return math.sqrt(s / n);
  }

  bool get isStill => jitter < 0.06;
  bool get isMoving => jitter > 0.35;

  /// Average of the raw samples in the window.
  Vec3 get rawMean {
    if (_window.isEmpty) return value;
    var s = Vec3.zero;
    for (final v in _window) {
      s = s + v;
    }
    return s * (1 / _window.length);
  }

  Vec3 _median(int n) {
    final l = _window.toList();
    final from = math.max(0, l.length - n);
    final xs = <double>[], ys = <double>[], zs = <double>[];
    for (var i = from; i < l.length; i++) {
      xs.add(l[i].x);
      ys.add(l[i].y);
      zs.add(l[i].z);
    }
    double med(List<double> v) => (v..sort())[v.length ~/ 2];
    return Vec3(med(xs), med(ys), med(zs));
  }

  final _rawListeners = <void Function(Vec3)>[];
  void addRawListener(void Function(Vec3) f) => _rawListeners.add(f);
  void removeRawListener(void Function(Vec3) f) => _rawListeners.remove(f);

  void start() {
    _users++;
    if (_sub != null) return;
    try {
      _sub = _events.receiveBroadcastStream().listen((e) {
        final l = (e as List).cast<num>();
        if (l.length >= 4) accuracy = l[3].toInt();
        _push(Vec3(l[0].toDouble(), l[1].toDouble(), l[2].toDouble()));
      }, onError: (_) {});
    } catch (_) {}
  }

  void stop() {
    _users = math.max(0, _users - 1);
    if (_users > 0) return;
    _sub?.cancel();
    _sub = null;
  }

  void _push(Vec3 raw) {
    _window.addLast(raw);
    while (_window.length > _windowSize) {
      _window.removeFirst();
    }
    if (!hasData) {
      value = raw;
      hasData = true;
    } else {
      // 1) Median of the last samples removes spikes.
      // 2) Adaptive low-pass: small differences (tremor, noise) get a long time
      //    constant, a real move (large difference) a short one.
      final m = _median(7);
      final k = store.smoothing.clamp(0.0, 1.0);
      final slowTau = 0.30 + 1.10 * k; // s; default ≈ 0.9 s
      final fastTau = 0.08 + 0.17 * k;
      final d = (m - value).length;
      final t = ((d - 0.5) / 2.0).clamp(0.0, 1.0);
      final tau = slowTau + (fastTau - slowTau) * t * t;
      final alpha = 1 - math.exp(-0.02 / tau);
      value = value + (m - value) * alpha;
    }
    for (final f in List.of(_rawListeners)) {
      f(raw);
    }
    notifyListeners();
  }

  /// Tests and screenshots: set a steady reading.
  @visibleForTesting
  void debugSet(Vec3 v, {int accuracy = 3}) {
    this.accuracy = accuracy;
    _window
      ..clear()
      ..addAll(List.filled(_windowSize, v));
    value = v;
    hasData = true;
    notifyListeners();
  }
}

/// Reading for a phone tilted by the given angles (degrees), handy in tests.
Vec3 vecForEdge(Edge e, double angle, {double forward = 0}) {
  const g = 9.80665;
  final a = angle * math.pi / 180, f = forward * math.pi / 180;
  // In the edge frame, upright: (right, up) = (-sin a, cos a) scaled by cos f.
  final r = -math.sin(a) * g * math.cos(f), u = math.cos(a) * g * math.cos(f);
  final z = math.sin(f) * g;
  final (x, y) = switch (e) {
    Edge.bottom => (r, u),
    Edge.left => (u, -r),
    Edge.top => (-r, -u),
    Edge.right => (-u, r),
  };
  return Vec3(x, y, z);
}

Vec3 vecForFlat(double xDeg, double yDeg, {bool back = true}) {
  const g = 9.80665;
  final tx = math.tan(xDeg * math.pi / 180), ty = math.tan(yDeg * math.pi / 180);
  final z = 1.0;
  final n = math.sqrt(tx * tx + ty * ty + z * z);
  return Vec3(-tx / n * g, -ty / n * g, (back ? 1 : -1) * z / n * g);
}
