import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/level_math.dart';
import '../models/models.dart';
import '../services/meter.dart';
import '../services/sensor.dart';
import '../services/store.dart';
import 'calibration_page.dart';
import 'instrument.dart';
import 'painters.dart';
import 'widgets.dart';

class LevelPage extends StatefulWidget {
  const LevelPage({super.key});
  @override
  State<LevelPage> createState() => _LevelPageState();
}

class _LevelPageState extends State<LevelPage> {
  late final Meter meter = Meter(store.lastMode)..start();

  @override
  void dispose() {
    meter.dispose();
    super.dispose();
  }

  void _setMode(Mode m) {
    meter.mode = m;
    store.lastMode = m;
    store.save();
  }

  void _save() {
    final m = meter.toMeasurement();
    store.addMeasurement(m);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(tr('Salvat: ${measurementValue(m)}', 'Saved: ${measurementValue(m)}')),
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: meter,
        builder: (context, _) {
          final r = meter.reading;
          final level = meter.isLevel(r) && Sensor.instance.hasData;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                Expanded(
                  child: ModeTabs<Mode>(
                    items: [
                      (Mode.level, Icons.horizontal_rule_rounded, Mode.level.label),
                      (Mode.plumb, Icons.height_rounded, Mode.plumb.label),
                      (Mode.flat, Icons.adjust_rounded, Mode.flat.label),
                    ],
                    value: meter.mode,
                    onChanged: _setMode,
                  ),
                ),
              ]),
            ),
            _StatusRow(meter: meter, reading: r),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: InstrumentCard(
                  level: level,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPress: meter.toggleLock,
                    child: switch (meter.mode) {
                      Mode.flat => _FlatView(meter: meter, reading: r, level: level),
                      _ => RotatedBox(
                          quarterTurns: r.edge.quarterTurns,
                          child: meter.mode == Mode.level
                              ? _LevelView(meter: meter, reading: r, level: level)
                              : _PlumbView(meter: meter, reading: r, level: level),
                        ),
                    },
                  ),
                ),
              ),
            ),
            if (!r.positionOk && !meter.locked) _PositionHint(mode: meter.mode, onSwitch: _setMode),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.end, children: [
                RoundAction(
                  icon: Icons.exposure_zero_rounded,
                  label: meter.relative ? tr('Absolut', 'Absolute') : tr('Zero', 'Zero'),
                  selected: meter.relative,
                  onTap: meter.toggleRelative,
                ),
                RoundAction(
                  big: true,
                  icon: switch (meter.lockState) {
                    MeterLock.locked => Icons.lock_rounded,
                    MeterLock.live => Icons.lock_open_rounded,
                    _ => Icons.timer_outlined,
                  },
                  label: switch (meter.lockState) {
                    MeterLock.locked => tr('Deblochează', 'Unlock'),
                    MeterLock.armedStill => tr('Ține nemișcat', 'Hold still'),
                    MeterLock.countdown => '${meter.secondsLeft} s',
                    MeterLock.live => tr('Blochează', 'Lock'),
                  },
                  selected: meter.lockState != MeterLock.live,
                  onTap: meter.lockPressed,
                ),
                RoundAction(icon: Icons.bookmark_add_outlined, label: tr('Salvează', 'Save'), onTap: _save),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

class _EdgeMenu extends StatelessWidget {
  const _EdgeMenu({required this.meter, required this.reading});
  final Meter meter;
  final Reading reading;

  @override
  Widget build(BuildContext context) {
    if (meter.mode == Mode.plumb) {
      return PopupMenuButton<bool>(
        tooltip: tr('Muchia pe perete', 'Edge on the wall'),
        initialValue: store.plumbOnLeft,
        onSelected: (v) {
          store.plumbOnLeft = v;
          store.save();
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: true, child: Text(tr('Muchia stângă pe perete', 'Left edge on the wall'))),
          PopupMenuItem(value: false, child: Text(tr('Muchia dreaptă pe perete', 'Right edge on the wall'))),
        ],
        child: Pill(store.plumbOnLeft ? tr('Muchia stângă pe perete', 'Left edge on wall') : tr('Muchia dreaptă pe perete', 'Right edge on wall'),
            icon: store.plumbOnLeft ? Icons.border_left : Icons.border_right, trailing: Icons.expand_more),
      );
    }
    return PopupMenuButton<Edge?>(
      tooltip: tr('Muchia de referință', 'Reference edge'),
      onSelected: (e) {
        store.autoEdge = e == null;
        if (e != null) store.levelEdge = e;
        store.save();
      },
      itemBuilder: (_) => [
        CheckedPopupMenuItem(value: null, checked: store.autoEdge, child: Text(tr('Automat', 'Automatic'))),
        for (final e in Edge.values)
          CheckedPopupMenuItem(
              value: e, checked: !store.autoEdge && store.levelEdge == e, child: Text(tr('Muchia: ${e.label}', 'Edge: ${e.label}'))),
      ],
      child: Pill(store.autoEdge ? '${reading.face.label} · ${tr('auto', 'auto')}' : reading.face.label,
          icon: store.autoEdge ? Icons.screen_rotation_alt : Icons.border_bottom, trailing: Icons.expand_more),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.meter, required this.reading});
  final Meter meter;
  final Reading reading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final face = reading.face;
    final pills = <Widget>[
      if (meter.mode == Mode.flat) Pill(face.label, icon: Icons.smartphone) else _EdgeMenu(meter: meter, reading: reading),
      if (!store.profile.has(face))
        Pill(tr('Necalibrat', 'Not calibrated'), icon: Icons.tune, color: cs.error, onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => CalibrationPage(start: face)));
        }),
      if (Sensor.instance.lowAccuracy) Pill(tr('Senzor imprecis', 'Low sensor accuracy'), icon: Icons.warning_amber, color: cs.error),
      if (meter.relative) Pill(tr('Relativ', 'Relative'), icon: Icons.exposure_zero, color: cs.tertiary),
      if (meter.locked) Pill(tr('Blocat', 'Locked'), icon: Icons.lock, color: cs.primary, filled: true, onTap: meter.unlock),
    ];
    return SizedBox(
      height: 44,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            for (var i = 0; i < pills.length; i++) ...[if (i > 0) const SizedBox(width: 6), pills[i]],
          ]),
        ),
      ),
    );
  }
}

(String, IconData) _direction(double angle, Mode mode) {
  if (angle.abs() < 0.05) return (tr('La nivel', 'Level'), Icons.check_circle_outline);
  if (mode == Mode.plumb) {
    return angle > 0
        ? (tr('Înclinat spre dreapta', 'Leaning right'), Icons.east)
        : (tr('Înclinat spre stânga', 'Leaning left'), Icons.west);
  }
  return angle > 0
      ? (tr('Ridică partea dreaptă', 'Raise the right side'), Icons.north_east)
      : (tr('Ridică partea stângă', 'Raise the left side'), Icons.north_west);
}

class _LevelView extends StatelessWidget {
  const _LevelView({required this.meter, required this.reading, required this.level});
  final Meter meter;
  final Reading reading;
  final bool level;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ok = reading.positionOk || meter.locked;
    final target = ok ? reading.angle : 0.0;
    final shown = meter.stable('level', target);
    final (dirText, dirIcon) = _direction(shown, Mode.level);
    final accent = level ? alertColor() : cs.primary;
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth > box.maxHeight * 1.1;
      final readout = Column(mainAxisSize: MainAxisSize.min, children: [
        Readout(shown, level: level, dash: !ok, size: wide ? 68 : 76),
        const SizedBox(height: 10),
        Caption(ok ? dirText : tr('Pune telefonul pe o muchie', 'Stand the phone on an edge'),
            icon: ok ? (meter.locked ? Icons.lock : dirIcon) : Icons.smartphone),
      ]);
      final dial = AspectRatio(
        aspectRatio: 1,
        child: Smoothed(
          values: [target],
          builder: (context, v) => CustomPaint(painter: AttitudePainter(angle: v[0], level: level, cs: cs, alert: alertColor())),
        ),
      );
      final vial = SizedBox(
        height: 60,
        width: double.infinity,
        child: Smoothed(
          values: [target],
          builder: (context, v) =>
              CustomPaint(painter: VialPainter(angle: v[0], cs: cs, liquid: accent, tolerance: store.tolerance)),
        ),
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(children: [
          if (wide)
            Expanded(
              child: Row(children: [
                Expanded(child: Center(child: readout)),
                const SizedBox(width: 12),
                Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: dial),
              ]),
            )
          else ...[
            readout,
            Expanded(child: Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8), child: dial))),
          ],
          const SizedBox(height: 14),
          vial,
        ]),
      );
    });
  }
}

class _PlumbView extends StatelessWidget {
  const _PlumbView({required this.meter, required this.reading, required this.level});
  final Meter meter;
  final Reading reading;
  final bool level;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final left = reading.contact == reading.edge.displayLeft;
    final ok = reading.positionOk || meter.locked;
    final target = ok ? reading.angle : 0.0;
    final shown = meter.stable('plumb', target);
    final (dirText, dirIcon) = _direction(shown, Mode.plumb);
    return Stack(fit: StackFit.expand, children: [
      Smoothed(
        values: [target],
        builder: (context, v) => CustomPaint(
            painter: PlumbPainter(angle: v[0], level: level, cs: cs, alert: alertColor(), contactLeft: left)),
      ),
      Align(
        alignment: const Alignment(0, 0.92),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Readout(shown, level: level, dash: !ok, size: 72),
          const SizedBox(height: 8),
          Caption(ok ? dirText : tr('Sprijină muchia pe perete', 'Hold the edge against the wall'),
              icon: ok ? (meter.locked ? Icons.lock : dirIcon) : Icons.smartphone),
        ]),
      ),
    ]);
  }
}

class _FlatView extends StatelessWidget {
  const _FlatView({required this.meter, required this.reading, required this.level});
  final Meter meter;
  final Reading reading;
  final bool level;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ok = reading.positionOk || meter.locked;
    final t = ok ? (reading.flat ?? const FlatTilt(0, 0)) : const FlatTilt(0, 0);
    final total = meter.stable('flat', t.total), sx = meter.stable('fx', t.x), sy = meter.stable('fy', t.y);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(children: [
        Readout(total, level: level, dash: !ok, abs: false, size: 64),
        const SizedBox(height: 6),
        Text(ok ? tr('Înclinare totală', 'Total tilt') : tr('Așază telefonul culcat', 'Lay the phone down'),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        const SizedBox(height: 10),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Smoothed(
                values: [t.x, t.y],
                builder: (context, v) => CustomPaint(
                    painter: FlatPainter(tilt: FlatTilt(v[0], v[1]), level: level, cs: cs, alert: alertColor(), tolerance: store.tolerance)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _AxisTile(label: tr('Stânga ↔ dreapta', 'Left ↔ right'), axis: 'X', value: sx, ok: ok)),
          const SizedBox(width: 10),
          Expanded(child: _AxisTile(label: tr('Sus ↕ jos', 'Top ↕ bottom'), axis: 'Y', value: sy, ok: ok)),
        ]),
      ]),
    );
  }
}

class _AxisTile extends StatelessWidget {
  const _AxisTile({required this.label, required this.axis, required this.value, required this.ok});
  final String label, axis;
  final double value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final frac = (value.abs() / 5).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(6)),
            child: Text(axis, style: TextStyle(color: cs.onPrimary, fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
        ]),
        const SizedBox(height: 6),
        Text(ok ? fmt(value, signed: true) : '—',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (context, b) {
          return Stack(children: [
            Container(height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2))),
            Positioned(
              left: value >= 0 ? b.maxWidth / 2 : b.maxWidth / 2 * (1 - frac),
              width: b.maxWidth / 2 * frac,
              child: Container(height: 4, decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(2))),
            ),
            Positioned(left: b.maxWidth / 2 - 1, child: Container(width: 2, height: 4, color: cs.onSurface)),
          ]);
        }),
      ]),
    );
  }
}

class _PositionHint extends StatelessWidget {
  const _PositionHint({required this.mode, required this.onSwitch});
  final Mode mode;
  final void Function(Mode) onSwitch;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final flat = mode == Mode.flat;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Material(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
          child: Row(children: [
            Icon(flat ? Icons.stay_current_portrait : Icons.smartphone, size: 20, color: cs.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                flat
                    ? tr('Telefonul stă în picioare.', 'The phone is standing up.')
                    : tr('Telefonul stă culcat.', 'The phone is lying flat.'),
                style: TextStyle(color: cs.onSecondaryContainer),
              ),
            ),
            TextButton(
              onPressed: () => onSwitch(flat ? Mode.level : Mode.flat),
              child: Text(flat ? tr('Mod Nivel', 'Level mode') : tr('Mod Plan', 'Flat mode')),
            ),
          ]),
        ),
      ),
    );
  }
}
