import '../core/i18n.dart';
import '../core/level_math.dart';

enum Mode { level, plumb, flat }

extension ModeX on Mode {
  String get label => switch (this) {
        Mode.level => tr('Nivel', 'Level'),
        Mode.plumb => tr('Plumb', 'Plumb'),
        Mode.flat => tr('Plan', 'Flat'),
      };
}

/// Offsets for one calibration profile. Flat faces store (x, y) tilt offsets,
/// edges store one angle. Values are what the phone reads on a truly level
/// surface, found by measuring twice on the same spot, rotated 180°.
class CalibrationProfile {
  CalibrationProfile({required this.name, Map<Face, List<double>>? offsets}) : offsets = offsets ?? {};
  String name;
  final Map<Face, List<double>> offsets;

  bool has(Face f) => offsets.containsKey(f);
  int get count => offsets.length;
  bool get complete => offsets.length == Face.values.length;

  double edge(Edge e) => offsets[faceOf(e)]?.first ?? 0;
  FlatTilt flat(Face f) {
    final o = offsets[f];
    return o == null ? const FlatTilt(0, 0) : FlatTilt(o[0], o[1]);
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'offsets': {for (final e in offsets.entries) e.key.name: e.value},
      };

  factory CalibrationProfile.fromJson(Map<String, dynamic> j) => CalibrationProfile(
        name: j['name'] ?? '',
        offsets: {
          for (final e in Map<String, dynamic>.from((j['offsets'] as Map?) ?? {}).entries)
            if (Face.values.any((f) => f.name == e.key))
              Face.values.byName(e.key): (e.value as List).map((v) => (v as num).toDouble()).toList(),
        },
      );
}

/// A saved reading. Angles are stored in degrees; [unit] is how it was shown.
class Measurement {
  Measurement({
    required this.id,
    required this.time,
    required this.mode,
    required this.angle,
    this.x,
    this.y,
    required this.unit,
    this.relative = false,
    this.note = '',
    this.where = '',
  });

  final String id;
  final DateTime time;
  final Mode mode;
  final double angle;
  final double? x, y;
  final Unit unit;
  final bool relative;
  String note;
  final String where;

  Map<String, dynamic> toJson() => {
        'id': id,
        't': time.toIso8601String(),
        'mode': mode.name,
        'a': angle,
        if (x != null) 'x': x,
        if (y != null) 'y': y,
        'unit': unit.name,
        'rel': relative,
        'note': note,
        'where': where,
      };

  factory Measurement.fromJson(Map<String, dynamic> j) => Measurement(
        id: j['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
        time: DateTime.tryParse(j['t'] ?? '') ?? DateTime.now(),
        mode: Mode.values.firstWhere((m) => m.name == j['mode'], orElse: () => Mode.level),
        angle: (j['a'] as num?)?.toDouble() ?? 0,
        x: (j['x'] as num?)?.toDouble(),
        y: (j['y'] as num?)?.toDouble(),
        unit: Unit.values.firstWhere((u) => u.name == j['unit'], orElse: () => Unit.degrees),
        relative: j['rel'] ?? false,
        note: j['note'] ?? '',
        where: j['where'] ?? '',
      );
}
