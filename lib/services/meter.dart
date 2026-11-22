import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/level_math.dart';
import '../models/models.dart';
import 'native.dart';
import 'sensor.dart';
import 'store.dart';

/// One computed reading, already calibrated and relative to the zero point.
class Reading {
  const Reading({
    required this.mode,
    required this.angle,
    required this.edge,
    required this.face,
    required this.positionOk,
    this.flat,
    this.contact,
    this.forward = 0,
    this.pitch = 0,
  });

  final Mode mode;

  /// Main value in degrees: deviation from level / vertical, or total tilt (flat).
  final double angle;

  /// Edge pointing down (sets how the display is rotated).
  final Edge edge;

  /// Face or edge resting on the surface (for calibration).
  final Face face;

  /// Plumb: the edge held against the wall.
  final Edge? contact;

  final FlatTilt? flat;

  /// Phone is held the way this mode expects.
  final bool positionOk;

  /// Forward/backward tilt out of the screen plane (camera mode).
  final double forward;

  /// Level mode, calibrated: how far the phone's back plane is from vertical
  /// (+ = screen tilts up). With the back on a wall: is the wall plumb?
  final double pitch;

  double get primary => flat?.total ?? angle;
}

Reading compute(Vec3 a, Mode mode, {double? zeroAngle, double? zeroPitch, FlatTilt? zeroFlat, Edge? sticky}) {
  final p = store.profile;
  final up = uprightness(a);
  switch (mode) {
    case Mode.level:
      final e = !store.autoEdge ? store.levelEdge : (up > 0.5 ? stickyDownEdge(a, sticky) : sticky ?? Edge.bottom);
      var dev = fromTarget(edgeAngle(a, e) - p.edge(e), every45: store.every45);
      if (zeroAngle != null) dev -= zeroAngle;
      var pitch = _forward(a) - (p.has(Face.back) ? p.flat(Face.back).y : 0);
      if (zeroPitch != null) pitch -= zeroPitch;
      return Reading(mode: mode, angle: dev, edge: e, face: faceOf(e), positionOk: up > 0.5,
          forward: _forward(a), pitch: pitch);
    case Mode.plumb:
      final down = up > 0.5 ? stickyDownEdge(a, sticky) : sticky ?? Edge.bottom;
      final c = store.plumbOnLeft ? down.displayLeft : down.displayRight;
      var dev = plumbDeviation(edgeAngle(a, c) - p.edge(c));
      if (store.every45) dev = fromTarget(dev, every45: true);
      if (zeroAngle != null) dev -= zeroAngle;
      return Reading(mode: mode, angle: dev, edge: down, face: faceOf(c), contact: c, positionOk: up > 0.5,
          forward: _forward(a));
    case Mode.flat:
      final f = flatFace(a);
      var t = flatTilt(a) - p.flat(f);
      if (zeroFlat != null) t = t - zeroFlat;
      return Reading(mode: mode, angle: t.total, edge: Edge.bottom, face: f, flat: t, positionOk: up < 0.8);
  }
}

double _forward(Vec3 a) {
  final l = a.length;
  if (l < 1e-6) return 0;
  return math.asin((a.z / l).clamp(-1.0, 1.0)) * 180 / math.pi;
}

enum MeterLock { live, armedStill, countdown, locked }

/// Shared logic for the measuring screens: lock, auto-lock, relative zero and alerts.
class Meter extends ChangeNotifier {
  Meter(this._mode);

  Mode _mode;
  Mode get mode => _mode;
  set mode(Mode m) {
    if (m == _mode) return;
    _mode = m;
    unlock(silent: true);
    _wasLevel = false;
    notifyListeners();
  }

  final Map<Mode, double> _zeroAngle = {};
  double? _zeroPitch;
  final Map<Mode, FlatTilt> _zeroFlat = {};
  bool get relative => _mode == Mode.flat ? _zeroFlat.containsKey(_mode) : _zeroAngle.containsKey(_mode);

  MeterLock lockState = MeterLock.live;
  Reading? _locked;
  DateTime? _countdownEnd;
  DateTime? _armedAt;
  DateTime? _stillSince;
  Timer? _timer;

  bool get locked => lockState == MeterLock.locked;
  int get secondsLeft =>
      _countdownEnd == null ? 0 : (_countdownEnd!.difference(DateTime.now()).inMilliseconds / 1000).ceil().clamp(0, 99);

  bool _wasLevel = false;
  DateTime _lastAlert = DateTime(2000);
  bool _started = false;

  Reading get reading => _locked ?? live;
  Edge? _sticky;
  Reading get live => compute(Sensor.instance.value, _mode,
      zeroAngle: _zeroAngle[_mode], zeroPitch: _mode == Mode.level ? _zeroPitch : null, zeroFlat: _zeroFlat[_mode], sticky: _sticky);

  final Map<String, double> _shown = {};

  /// Displayed value with hysteresis: it only changes when the reading moves
  /// by most of one displayed step, so the last digit does not flicker.
  double stable(String key, double v) {
    final step = switch (store.decimals) { 0 => 1.0, 1 => 0.1, _ => 0.01 };
    final old = _shown[key];
    if (old == null || (v - old).abs() >= step * 0.8 || locked) _shown[key] = v;
    return _shown[key]!;
  }

  bool isLevel(Reading r) => r.positionOk && r.primary.abs() <= store.tolerance;

  void start() {
    if (_started) return;
    _started = true;
    Sensor.instance.start();
    Sensor.instance.addListener(_tick);
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_started) {
      Sensor.instance.removeListener(_tick);
      Sensor.instance.stop();
    }
    super.dispose();
  }

  void _tick() {
    if (!Sensor.instance.hasData) return;
    final r = live;
    if (r.mode != Mode.flat && r.positionOk) _sticky = r.edge;
    final now = DateTime.now();

    if (lockState == MeterLock.armedStill) {
      if (Sensor.instance.isStill && now.difference(_armedAt!).inMilliseconds > 600) {
        _stillSince ??= now;
        if (now.difference(_stillSince!).inMilliseconds > 900) lock();
      } else if (!Sensor.instance.isStill) {
        _stillSince = null;
      }
    }

    if (!locked) {
      final level = isLevel(r);
      final leave = !r.positionOk || r.primary.abs() > store.tolerance * 1.5 + 0.05;
      if (level && !_wasLevel) {
        _wasLevel = true;
        if (now.difference(_lastAlert).inMilliseconds > 700) {
          _lastAlert = now;
          if (store.vibrate) Native.vibrate(35);
          if (store.sound) Native.beep('level');
        }
      } else if (_wasLevel && leave) {
        _wasLevel = false;
      }
    }
    notifyListeners();
  }

  /// Lock button: immediate, or armed according to the auto-lock setting.
  void lockPressed() {
    if (lockState != MeterLock.live) {
      unlock();
      return;
    }
    switch (store.autoLock) {
      case AutoLock.off:
        lock();
      case AutoLock.still:
        lockState = MeterLock.armedStill;
        _armedAt = DateTime.now();
        _stillSince = null;
        notifyListeners();
      case AutoLock.s3 || AutoLock.s5 || AutoLock.s10:
        lockState = MeterLock.countdown;
        _countdownEnd = DateTime.now().add(Duration(seconds: store.autoLock.seconds));
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(milliseconds: 200), (t) {
          if (DateTime.now().isAfter(_countdownEnd!)) {
            t.cancel();
            lock();
          } else {
            notifyListeners();
          }
        });
        notifyListeners();
    }
  }

  void lock() {
    _timer?.cancel();
    _locked = live;
    lockState = MeterLock.locked;
    _countdownEnd = null;
    if (store.vibrate) Native.vibrate(60);
    if (store.sound) Native.beep('lock');
    notifyListeners();
  }

  void unlock({bool silent = false}) {
    _timer?.cancel();
    _locked = null;
    _countdownEnd = null;
    lockState = MeterLock.live;
    if (!silent) notifyListeners();
  }

  /// Long press: lock now, or unlock.
  void toggleLock() => lockState == MeterLock.live ? lock() : unlock();

  /// Zero button: current reading becomes the reference; again to clear.
  void toggleRelative() {
    if (relative) {
      _zeroAngle.remove(_mode);
      if (_mode == Mode.level) _zeroPitch = null;
      _zeroFlat.remove(_mode);
    } else {
      final r = compute(Sensor.instance.value, _mode, sticky: _sticky);
      if (_mode == Mode.flat) {
        _zeroFlat[_mode] = r.flat!;
      } else {
        _zeroAngle[_mode] = r.angle;
        if (_mode == Mode.level) _zeroPitch = r.pitch;
      }
    }
    if (locked) unlock(silent: true);
    _wasLevel = false;
    notifyListeners();
  }

  Measurement toMeasurement() {
    final r = reading;
    return Measurement(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      time: DateTime.now(),
      mode: _mode,
      angle: r.angle,
      x: r.flat?.x,
      y: r.flat?.y,
      unit: store.unit,
      relative: relative,
      where: r.face.label,
    );
  }
}
