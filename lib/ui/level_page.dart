import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/level_math.dart';
import '../models/models.dart';
import '../services/meter.dart';
import '../services/sensor.dart';
import '../services/store.dart';
import 'calibration_page.dart';
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
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(children: [
                Expanded(
                  child: SegmentedButton<Mode>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: Mode.level, label: Text(Mode.level.label), icon: const Icon(Icons.horizontal_rule)),
                      ButtonSegment(value: Mode.plumb, label: Text(Mode.plumb.label), icon: const Icon(Icons.vertical_align_bottom)),
                      ButtonSegment(value: Mode.flat, label: Text(Mode.flat.label), icon: const Icon(Icons.adjust)),
                    ],
                    selected: {meter.mode},
                    onSelectionChanged: (s) => _setMode(s.first),
                  ),
                ),
                if (meter.mode != Mode.flat) _EdgeMenu(meter: meter),
              ]),
            ),
            _StatusRow(meter: meter, reading: r),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: meter.toggleLock,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: meter.locked ? 0.92 : 1,
                  child: switch (meter.mode) {
                    Mode.flat => _FlatView(reading: r, level: level, locked: meter.locked),
                    _ => RotatedBox(
                        quarterTurns: r.edge.quarterTurns,
                        child: meter.mode == Mode.level
                            ? _LevelView(reading: r, level: level, locked: meter.locked)
                            : _PlumbView(reading: r, level: level, locked: meter.locked),
                      ),
                  },
                ),
              ),
            ),
            if (!r.positionOk && !meter.locked) _PositionHint(mode: meter.mode, onSwitch: _setMode),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(children: [
                Expanded(
                  child: _ActionButton(
                    icon: meter.relative ? Icons.exposure_zero : Icons.exposure_zero_outlined,
                    label: meter.relative ? tr('Absolut', 'Absolute') : tr('Zero', 'Zero'),
                    selected: meter.relative,
                    onTap: meter.toggleRelative,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: switch (meter.lockState) {
                      MeterLock.locked => Icons.lock,
                      MeterLock.live => Icons.lock_open,
                      _ => Icons.timer_outlined,
                    },
                    label: switch (meter.lockState) {
                      MeterLock.locked => tr('Deblochează', 'Unlock'),
                      MeterLock.armedStill => tr('Ține nemișcat…', 'Hold still…'),
                      MeterLock.countdown => '${meter.secondsLeft} s',
                      MeterLock.live => tr('Blochează', 'Lock'),
                    },
                    selected: meter.lockState != MeterLock.live,
                    onTap: meter.lockPressed,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(icon: Icons.bookmark_add_outlined, label: tr('Salvează', 'Save'), onTap: _save, primary: true),
                ),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.selected = false, this.primary = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected, primary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: primary ? cs.primary : (selected ? cs.tertiaryContainer : cs.secondaryContainer),
      foregroundColor: primary ? cs.onPrimary : (selected ? cs.onTertiaryContainer : cs.onSecondaryContainer),
    );
    return FilledButton(
      style: style,
      onPressed: onTap,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 20),
        const SizedBox(width: 6),
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

class _EdgeMenu extends StatelessWidget {
  const _EdgeMenu({required this.meter});
  final Meter meter;

  @override
  Widget build(BuildContext context) {
    if (meter.mode == Mode.plumb) {
      return PopupMenuButton<bool>(
        tooltip: tr('Muchia pe perete', 'Edge on the wall'),
        icon: Icon(store.plumbOnLeft ? Icons.border_left : Icons.border_right),
        initialValue: store.plumbOnLeft,
        onSelected: (v) {
          store.plumbOnLeft = v;
          store.save();
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: true, child: Text(tr('Muchia stângă pe perete', 'Left edge on the wall'))),
          PopupMenuItem(value: false, child: Text(tr('Muchia dreaptă pe perete', 'Right edge on the wall'))),
        ],
      );
    }
    return PopupMenuButton<Edge?>(
      tooltip: tr('Muchia de referință', 'Reference edge'),
      icon: Icon(store.autoEdge ? Icons.screen_rotation_alt : Icons.border_bottom),
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
      Pill(face.label, icon: face.isFlat ? Icons.smartphone : Icons.border_bottom),
      if (!store.profile.has(face))
        Pill(tr('Necalibrat', 'Not calibrated'), icon: Icons.tune, color: cs.error, onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => CalibrationPage(start: face)));
        }),
      if (Sensor.instance.lowAccuracy) Pill(tr('Senzor imprecis', 'Low sensor accuracy'), icon: Icons.warning_amber, color: cs.error),
      if (meter.relative) Pill(tr('Relativ', 'Relative'), icon: Icons.exposure_zero, color: cs.tertiary),
      if (meter.locked) Pill(tr('Blocat', 'Locked'), icon: Icons.lock, color: cs.primary, filled: true, onTap: meter.unlock),
    ];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        itemCount: pills.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) => pills[i],
      ),
    );
  }
}

class _BigValue extends StatelessWidget {
  const _BigValue(this.text, {required this.level, required this.locked, this.sub});
  final String text;
  final bool level, locked;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = level ? Color.lerp(alertColor(), cs.onSurface, 0.25) : cs.onSurface;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        if (locked) ...[Icon(Icons.lock, color: cs.primary, size: 28), const SizedBox(width: 8)],
        Text(text,
            style: TextStyle(
                fontSize: 76,
                height: 1,
                fontWeight: FontWeight.w300,
                color: color,
                letterSpacing: -1.5,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
      if (sub != null) ...[
        const SizedBox(height: 8),
        Text(sub!, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    ]);
  }
}

String _direction(double angle, Mode mode) {
  if (angle.abs() < 0.05) return tr('La nivel', 'Level');
  if (mode == Mode.plumb) return angle > 0 ? tr('Înclinat spre dreapta', 'Leaning right') : tr('Înclinat spre stânga', 'Leaning left');
  return angle > 0 ? tr('Ridică partea dreaptă', 'Raise the right side') : tr('Ridică partea stângă', 'Raise the left side');
}

class _LevelView extends StatelessWidget {
  const _LevelView({required this.reading, required this.level, required this.locked});
  final Reading reading;
  final bool level, locked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(fit: StackFit.expand, children: [
      CustomPaint(
          painter: LevelPainter(angle: reading.angle, level: level, cs: cs, alert: alertColor(), tolerance: store.tolerance)),
      Align(
        alignment: const Alignment(0, -0.52),
        child: _BigValue(fmt(reading.angle, abs: true), level: level, locked: locked, sub: _direction(reading.angle, Mode.level)),
      ),
    ]);
  }
}

class _PlumbView extends StatelessWidget {
  const _PlumbView({required this.reading, required this.level, required this.locked});
  final Reading reading;
  final bool level, locked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final left = reading.contact == reading.edge.displayLeft;
    return Stack(fit: StackFit.expand, children: [
      CustomPaint(
          painter: PlumbPainter(angle: reading.angle, level: level, cs: cs, alert: alertColor(), contactLeft: left)),
      Align(
        alignment: const Alignment(0, 0.96),
        child: _BigValue(fmt(reading.angle, abs: true), level: level, locked: locked, sub: _direction(reading.angle, Mode.plumb)),
      ),
    ]);
  }
}

class _FlatView extends StatelessWidget {
  const _FlatView({required this.reading, required this.level, required this.locked});
  final Reading reading;
  final bool level, locked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = reading.flat ?? const FlatTilt(0, 0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        const SizedBox(height: 8),
        _BigValue(fmt(t.total), level: level, locked: locked, sub: tr('Înclinare totală', 'Total tilt')),
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                  painter: FlatPainter(tilt: t, level: level, cs: cs, alert: alertColor(), tolerance: store.tolerance)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Expanded(child: InfoRow(tr('Stânga – dreapta (X)', 'Left – right (X)'), fmt(t.x, signed: true), last: true)),
            Container(width: 1, height: 26, margin: const EdgeInsets.symmetric(horizontal: 12), color: cs.outlineVariant),
            Expanded(child: InfoRow(tr('Sus – jos (Y)', 'Top – bottom (Y)'), fmt(t.y, signed: true), last: true)),
          ]),
        ),
        const SizedBox(height: 4),
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
