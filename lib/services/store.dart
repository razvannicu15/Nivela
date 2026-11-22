import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../core/i18n.dart';
import '../core/level_math.dart';
import '../models/models.dart';

enum AutoLock { off, still, s3, s5, s10 }

extension AutoLockX on AutoLock {
  String get label => switch (this) {
        AutoLock.off => tr('Dezactivată', 'Off'),
        AutoLock.still => tr('Când telefonul stă nemișcat', 'When the phone holds still'),
        AutoLock.s3 => tr('După 3 secunde', 'After 3 seconds'),
        AutoLock.s5 => tr('După 5 secunde', 'After 5 seconds'),
        AutoLock.s10 => tr('După 10 secunde', 'After 10 seconds'),
      };
  int get seconds => switch (this) { AutoLock.s3 => 3, AutoLock.s5 => 5, AutoLock.s10 => 10, _ => 0 };
}

/// Theme colours offered in Settings (no pink unless asked for).
const themeColors = <int>[0xFF0E7C66, 0xFF2B5CE6, 0xFF3F51B5, 0xFF6750A4, 0xFF00838F, 0xFFE65100, 0xFFB3261E, 0xFF5D6B7A];
const alertColors = <int>[0xFF1DB954, 0xFF2B8CFF, 0xFFFFC107, 0xFFFF7A1A, 0xFF9C5CFF, 0xFF00BFA5];

/// Settings, calibration profiles and saved measurements, in one JSON file.
class Store extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  int seed = themeColors.first;
  String language = 'system';
  int decimals = 1;
  Unit unit = Unit.degrees;
  bool keepOn = true;

  double tolerance = 0.3;
  int alertColor = alertColors.first;
  bool vibrate = true;
  bool sound = false;
  bool every45 = false;

  bool autoEdge = true;
  Edge levelEdge = Edge.bottom;
  bool plumbOnLeft = true;
  AutoLock autoLock = AutoLock.off;
  double smoothing = 0.6;

  Mode lastMode = Mode.level;

  // Camera guidelines.
  int grid = 3; // 0 = off, 3 or 4 lines
  bool horizon = true;
  bool plumbLines = false;
  bool crosshair = true;
  double guideOpacity = 0.85;

  List<CalibrationProfile> profiles = _defaultProfiles();
  int activeProfile = 0;

  final List<Measurement> measurements = [];

  CalibrationProfile get profile => profiles[activeProfile.clamp(0, profiles.length - 1)];

  static List<CalibrationProfile> _defaultProfiles() => [
        CalibrationProfile(name: tr('Fără husă', 'No case')),
        CalibrationProfile(name: tr('Cu husă', 'With case')),
        CalibrationProfile(name: tr('Profil 3', 'Profile 3')),
      ];

  File? _file;

  Future<void> load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/nivela.json');
    } catch (_) {
      setLanguage(language);
      return;
    }
    if (!await _file!.exists()) {
      setLanguage(language);
      profiles = _defaultProfiles();
      return;
    }
    try {
      fromJson(jsonDecode(await _file!.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      await _file!.copy('${_file!.path}.bak');
    }
    setLanguage(language);
  }

  T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
      values.firstWhere((v) => v.name == name, orElse: () => fallback);

  void fromJson(Map<String, dynamic> j) {
    final s = Map<String, dynamic>.from((j['settings'] as Map?) ?? {});
    themeMode = _enum(ThemeMode.values, s['theme'], ThemeMode.system);
    seed = s['seed'] ?? seed;
    language = s['lang'] ?? 'system';
    decimals = (s['dec'] ?? 1).clamp(0, 2);
    unit = _enum(Unit.values, s['unit'], Unit.degrees);
    keepOn = s['keepOn'] ?? true;
    tolerance = (s['tol'] as num?)?.toDouble() ?? 0.3;
    alertColor = s['alertColor'] ?? alertColor;
    vibrate = s['vib'] ?? true;
    sound = s['sound'] ?? false;
    every45 = s['e45'] ?? false;
    autoEdge = s['autoEdge'] ?? true;
    levelEdge = _enum(Edge.values, s['edge'], Edge.bottom);
    plumbOnLeft = s['plumbLeft'] ?? true;
    autoLock = _enum(AutoLock.values, s['autoLock'], AutoLock.off);
    smoothing = (s['smooth'] as num?)?.toDouble() ?? 0.6;
    lastMode = _enum(Mode.values, s['mode'], Mode.level);
    grid = s['grid'] ?? 3;
    horizon = s['horizon'] ?? true;
    plumbLines = s['plumbLines'] ?? false;
    crosshair = s['cross'] ?? true;
    guideOpacity = (s['guideOp'] as num?)?.toDouble() ?? 0.85;
    final p = (j['profiles'] as List?) ?? [];
    profiles = p.map((e) => CalibrationProfile.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final defaults = _defaultProfiles();
    while (profiles.length < 3) {
      profiles.add(defaults[profiles.length]);
    }
    activeProfile = (j['activeProfile'] ?? 0).clamp(0, profiles.length - 1);
    measurements
      ..clear()
      ..addAll(((j['measurements'] as List?) ?? [])
          .map((e) => Measurement.fromJson(Map<String, dynamic>.from(e as Map))));
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'settings': {
          'theme': themeMode.name,
          'seed': seed,
          'lang': language,
          'dec': decimals,
          'unit': unit.name,
          'keepOn': keepOn,
          'tol': tolerance,
          'alertColor': alertColor,
          'vib': vibrate,
          'sound': sound,
          'e45': every45,
          'autoEdge': autoEdge,
          'edge': levelEdge.name,
          'plumbLeft': plumbOnLeft,
          'autoLock': autoLock.name,
          'smooth': smoothing,
          'mode': lastMode.name,
          'grid': grid,
          'horizon': horizon,
          'plumbLines': plumbLines,
          'cross': crosshair,
          'guideOp': guideOpacity,
        },
        'profiles': profiles.map((p) => p.toJson()).toList(),
        'activeProfile': activeProfile,
        'measurements': measurements.map((m) => m.toJson()).toList(),
      };

  Future<void> save() async {
    setLanguage(language);
    notifyListeners();
    final f = _file;
    if (f == null) return;
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(toJson()));
    await tmp.rename(f.path);
  }

  void addMeasurement(Measurement m) {
    measurements.insert(0, m);
    save();
  }

  void removeMeasurement(String id) {
    measurements.removeWhere((m) => m.id == id);
    save();
  }
}

final store = Store();
