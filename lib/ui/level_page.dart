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
              IconButton(tooltip: tr('Calibrare', 'Calibration'), icon: const Icon(Icons.tune), onPressed: () => _calibrate(null)),
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
                child: _HeroCard(meter: meter, reading: r, level: level, onCalibrate: () => _calibrate(r.face)),
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

(String, IconData) _direction(double angle, Mode mode) {
  if (angle.abs() < 0.05) return (tr('Perfect la nivel', 'Perfectly level'), Icons.check_circle_outline);
  if (mode == Mode.plumb) {
    return angle > 0
        ? (tr('Înclinat spre dreapta', 'Leaning right'), Icons.east)
        : (tr('Înclinat spre stânga', 'Leaning left'), Icons.west);
  }
  if (mode == Mode.flat) return (tr('Înclinare totală', 'Total tilt'), Icons.adjust);
  return angle > 0
      ? (tr('Ridică partea dreaptă', 'Raise the right side'), Icons.north_east)
      : (tr('Ridică partea stângă', 'Raise the left side'), Icons.north_west);
}

/// Small status chip, like "La timp" in Nflight.
class _Chip extends StatelessWidget {
  const _Chip(this.text, {required this.bg, required this.fg, this.icon, this.onTap});
  final String text;
  final Color bg, fg;
  final IconData? icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
            Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

/// The main card: label, status, big value, drawing, and a subtle table.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.meter, required this.reading, required this.level, required this.onCalibrate});
  final Meter meter;
  final Reading reading;
  final bool level;
  final VoidCallback onCalibrate;

  List<Widget> _chips(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final a = alertColor();
    return [
      if (meter.locked)
        _Chip(tr('Blocat', 'Locked'), bg: cs.primary, fg: cs.onPrimary, icon: Icons.lock, onTap: meter.unlock)
      else if (level)
        _Chip(tr('La nivel', 'Level'),
            bg: Color.lerp(a, dark ? Colors.black : Colors.white, dark ? 0.55 : 0.78)!,
            fg: Color.lerp(a, dark ? Colors.white : Colors.black, dark ? 0.55 : 0.55)!),
      if (meter.relative) _Chip(tr('Relativ', 'Relative'), bg: cs.tertiaryContainer, fg: cs.onTertiaryContainer),
      if (!store.profile.has(reading.face))
        _Chip(tr('Necalibrat', 'Not calibrated'), bg: cs.errorContainer, fg: cs.onErrorContainer, onTap: onCalibrate),
      if (Sensor.instance.lowAccuracy) _Chip(tr('Senzor imprecis', 'Low accuracy'), bg: cs.errorContainer, fg: cs.onErrorContainer),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = Color.alphaBlend(cs.primaryContainer.withValues(alpha: 0.55), cs.surface);
    final card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: meter.toggleLock,
      child: Container(
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
    final t = Theme.of(context).textTheme;
    final ok = reading.positionOk || meter.locked;
    final accent = level ? alertColor() : cs.primary;
    final mode = meter.mode;

    final flat = ok ? (reading.flat ?? const FlatTilt(0, 0)) : const FlatTilt(0, 0);
    final target = mode == Mode.flat ? flat.total : (ok ? reading.angle : 0.0);
    final shown = meter.stable(mode.name, target);
    final (dirText, _) = _direction(shown, mode);

    final where = switch (mode) {
      Mode.plumb => reading.contact == null ? '' : faceOf(reading.contact!).label,
      _ => reading.face.label,
    };
    final header = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Text('${mode.label} · $where'.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.labelMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.8, color: cs.onSurfaceVariant)),
      ),
      Wrap(spacing: 6, children: _chips(context)),
    ]);
    final hint = switch (mode) {
      Mode.level => tr('Pune telefonul pe o muchie', 'Stand the phone on an edge'),
      Mode.plumb => tr('Sprijină muchia pe perete', 'Hold the edge against the wall'),
      Mode.flat => tr('Așază telefonul culcat', 'Lay the phone down'),
    };
    final value = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 4),
      Text(ok ? (meter.locked ? tr('Citire blocată', 'Reading locked') : dirText) : hint,
          style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      const SizedBox(height: 6),
      Readout(shown, dash: !ok, abs: true, size: 62, color: cs.onSurface),
    ]);

    // Visual.
    final Widget visual = switch (mode) {
      Mode.level => Column(children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Smoothed(
                    values: [target],
                    builder: (c, v) => CustomPaint(painter: AttitudePainter(angle: v[0], cs: cs, accent: accent))),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: Smoothed(
                values: [target],
                builder: (c, v) =>
                    CustomPaint(painter: VialPainter(angle: v[0], cs: cs, accent: accent, tolerance: store.tolerance))),
          ),
        ]),
      Mode.plumb => Smoothed(
          values: [target],
          builder: (c, v) => CustomPaint(
              painter: PlumbPainter(
                  angle: v[0], cs: cs, accent: accent, contactLeft: reading.contact == reading.edge.displayLeft)),
        ),
      Mode.flat => Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: Smoothed(
              values: [flat.x, flat.y],
              builder: (c, v) => CustomPaint(
                  painter: FlatPainter(tilt: FlatTilt(v[0], v[1]), cs: cs, accent: accent, tolerance: store.tolerance)),
            ),
          ),
        ),
    };

    // Table.
    final alt = Unit.values.where((u) => u != store.unit).toList();
    final cells = mode == Mode.flat
        ? [
            ('X', ok ? fmt(meter.stable('fx', flat.x), signed: true) : '—'),
            ('Y', ok ? fmt(meter.stable('fy', flat.y), signed: true) : '—'),
            (alt.first.symbol.toUpperCase(), ok ? fmt(shown, unit: alt.first) : '—'),
          ]
        : [for (final u in alt) (u.symbol.toUpperCase(), ok ? fmt(shown, abs: true, unit: u) : '—')];
    final table = _Table(cells);

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth > box.maxHeight * 1.15;
      if (wide) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                header,
                value,
                const Spacer(),
                const _Dashes(),
                const SizedBox(height: 12),
                table,
              ]),
            ),
            const SizedBox(width: 20),
            SizedBox(width: box.maxHeight * 0.95, child: visual),
          ]),
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          header,
          value,
          const SizedBox(height: 16),
          Expanded(child: visual),
          const SizedBox(height: 18),
          const _Dashes(),
          const SizedBox(height: 12),
          table,
        ]),
      );
    });
  }
}

class _Table extends StatelessWidget {
  const _Table(this.cells);
  final List<(String, String)> cells;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Row(children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) VerticalDivider(width: 24, thickness: 1, color: cs.outlineVariant),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cells[i].$1,
                  style: t.labelSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.8, color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(cells[i].$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _Dashes extends StatelessWidget {
  const _Dashes();
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.outline.withValues(alpha: 0.6);
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(painter: _DashPainter(c)),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.c);
  final Color c;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = c..strokeWidth = 1.2;
    for (var x = 0.0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, 0.5), Offset(x + 5, 0.5), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter o) => o.c != c;
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
