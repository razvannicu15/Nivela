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

  Future<void> _calibrate(Face? f) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CalibrationPage(start: f)));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: meter,
      builder: (context, _) {
        final r = meter.reading;
        final level = meter.isLevel(r) && Sensor.instance.hasData;
        return Scaffold(
          appBar: AppBar(
            title: Text(tr('Nivelă', 'Level')),
            actions: [
              if (meter.mode != Mode.flat) _EdgeMenu(meter: meter),
              IconButton(
                tooltip: tr('Calibrare', 'Calibration'),
                icon: Badge(
                  isLabelVisible: !store.profile.has(r.face) || Sensor.instance.lowAccuracy,
                  smallSize: 9,
                  child: const Icon(Icons.tune),
                ),
                onPressed: () => _calibrate(store.profile.has(r.face) ? null : r.face),
              ),
            ],
          ),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<Mode>(
                  showSelectedIcon: false,
                  segments: [for (final m in Mode.values) ButtonSegment(value: m, label: Text(m.label))],
                  selected: {meter.mode},
                  onSelectionChanged: (s) => _setMode(s.first),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _HeroCard(meter: meter, reading: r, level: level),
              ),
            ),
            if (!r.positionOk && !meter.locked) _PositionHint(mode: meter.mode, onSwitch: _setMode),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(children: [
                _SideButton(
                  icon: Icons.exposure_zero,
                  label: meter.relative ? tr('Absolut', 'Absolute') : tr('Zero', 'Zero'),
                  selected: meter.relative,
                  onTap: meter.toggleRelative,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()),
                    onPressed: meter.lockPressed,
                    icon: Icon(switch (meter.lockState) {
                      MeterLock.locked => Icons.lock,
                      MeterLock.live => Icons.lock_open,
                      _ => Icons.timer_outlined,
                    }),
                    label: Text(switch (meter.lockState) {
                      MeterLock.locked => tr('Deblochează', 'Unlock'),
                      MeterLock.armedStill => tr('Ține nemișcat…', 'Hold still…'),
                      MeterLock.countdown => tr('Blochez în ${meter.secondsLeft} s', 'Locking in ${meter.secondsLeft} s'),
                      MeterLock.live => tr('Blochează', 'Lock'),
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                _SideButton(icon: Icons.bookmark_add_outlined, label: tr('Salvează', 'Save'), onTap: _save),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({required this.icon, required this.label, required this.onTap, this.selected = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          backgroundColor: selected ? cs.tertiaryContainer : null,
          foregroundColor: selected ? cs.onTertiaryContainer : null,
        ),
        onPressed: onTap,
        child: Icon(icon),
      ),
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
        CheckedPopupMenuItem(value: null, checked: store.autoEdge, child: Text(tr('Muchie automată', 'Automatic edge'))),
        for (final e in Edge.values)
          CheckedPopupMenuItem(
              value: e, checked: !store.autoEdge && store.levelEdge == e, child: Text(tr('Muchia: ${e.label}', 'Edge: ${e.label}'))),
      ],
    );
  }
}

/// The main card: the level itself and its value, nothing else.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.meter, required this.reading, required this.level});
  final Meter meter;
  final Reading reading;
  final bool level;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = Color.alphaBlend((level ? alertColor().withValues(alpha: 0.16) : cs.primaryContainer.withValues(alpha: 0.55)), cs.surface);
    final card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: meter.toggleLock,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(28)),
        child: meter.mode == Mode.flat
            ? _content(context)
            : RotatedBox(quarterTurns: reading.edge.quarterTurns, child: _content(context)),
      ),
    );
    return card;
  }

  Widget _content(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ok = reading.positionOk || meter.locked;
    final accent = level ? alertColor() : cs.primary;
    final mode = meter.mode;

    final flat = ok ? (reading.flat ?? const FlatTilt(0, 0)) : const FlatTilt(0, 0);
    final target = mode == Mode.flat ? flat.total : (ok ? reading.angle : 0.0);
    final shown = meter.stable(mode.name, target);

    final value = Row(mainAxisSize: MainAxisSize.min, children: [
      if (meter.locked) ...[Icon(Icons.lock, color: cs.primary, size: 26), const SizedBox(width: 8)],
      Readout(shown, dash: !ok, abs: true, size: mode == Mode.level ? 64 : 52, color: level ? accent : cs.onSurface),
    ]);

    return LayoutBuilder(builder: (context, box) {
      switch (mode) {
        case Mode.level:
          final vh = (box.maxWidth * 0.26).clamp(70.0, 120.0);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              value,
              SizedBox(height: vh * 0.45),
              SizedBox(
                height: vh,
                width: double.infinity,
                child: Smoothed(
                    values: [target],
                    builder: (c, v) =>
                        CustomPaint(painter: VialPainter(angle: v[0], cs: cs, accent: accent, tolerance: store.tolerance))),
              ),
              SizedBox(height: vh * 0.45 + 30),
            ]),
          );
        case Mode.plumb:
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(children: [
              Expanded(
                child: SizedBox.expand(
                  child: Smoothed(
                    values: [target],
                    builder: (c, v) => CustomPaint(
                        painter: PlumbPainter(
                            angle: v[0], cs: cs, accent: accent, contactLeft: reading.contact == reading.edge.displayLeft)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              value,
            ]),
          );
        case Mode.flat:
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Smoothed(
                      values: [flat.x, flat.y],
                      builder: (c, v) => CustomPaint(
                          painter: FlatPainter(tilt: FlatTilt(v[0], v[1]), cs: cs, accent: accent, tolerance: store.tolerance)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              value,
            ]),
          );
      }
    });
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
