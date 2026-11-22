import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/level_math.dart';
import '../services/store.dart';
import 'widgets.dart';

/// Eases a list of values towards their targets every frame (liquid feel),
/// independent of how often the sensor reports.
class Smoothed extends StatefulWidget {
  const Smoothed({super.key, required this.values, required this.builder, this.tau = 0.22});
  final List<double> values;
  final double tau;
  final Widget Function(BuildContext context, List<double> values) builder;

  @override
  State<Smoothed> createState() => _SmoothedState();
}

class _SmoothedState extends State<Smoothed> with SingleTickerProviderStateMixin {
  late List<double> _cur = List.of(widget.values);
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = now;
    if (dt == 0) return;
    final k = 1 - math.exp(-dt / widget.tau);
    var changed = false;
    for (var i = 0; i < _cur.length && i < widget.values.length; i++) {
      final d = widget.values[i] - _cur[i];
      if (d.abs() > 1e-4) {
        _cur[i] += d * k;
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  @override
  void didUpdateWidget(Smoothed old) {
    super.didUpdateWidget(old);
    if (widget.values.length != _cur.length) _cur = List.of(widget.values);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _cur);
}

/// The rounded "instrument face" the measuring views sit on.
class InstrumentCard extends StatelessWidget {
  const InstrumentCard({super.key, required this.child, this.level = false});
  final Widget child;
  final bool level;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final a = alertColor();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? [cs.surfaceContainerHigh, cs.surfaceContainerLow]
              : [Color.lerp(cs.surfaceContainerLowest, Colors.white, 0.6)!, cs.surfaceContainerLow],
        ),
        border: Border.all(color: level ? a : cs.outlineVariant.withValues(alpha: 0.7), width: level ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: level ? a.withValues(alpha: 0.35) : Colors.black.withValues(alpha: dark ? 0.35 : 0.08),
            blurRadius: level ? 24 : 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(31), child: child),
    );
  }
}

/// Sliding pill tabs.
class ModeTabs<T> extends StatelessWidget {
  const ModeTabs({super.key, required this.items, required this.value, required this.onChanged});
  final List<(T, IconData, String)> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final i = items.indexWhere((e) => e.$1 == value);
    final n = items.length;
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(25)),
      child: Stack(children: [
        AnimatedAlign(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment(n == 1 ? 0 : -1 + 2 * i / (n - 1), 0),
          child: FractionallySizedBox(
            widthFactor: 1 / n,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(21),
                boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3))],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var k = 0; k < n; k++)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(21),
                onTap: () => onChanged(items[k].$1),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: k == i ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(items[k].$2, size: 18, color: k == i ? cs.onPrimary : cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(items[k].$3),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Round action button with a label underneath.
class RoundAction extends StatelessWidget {
  const RoundAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.big = false,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool big, selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = big ? 72.0 : 56.0;
    final bg = big ? (selected ? cs.tertiary : cs.primary) : (selected ? cs.tertiaryContainer : cs.secondaryContainer);
    final fg = big ? (selected ? cs.onTertiary : cs.onPrimary) : (selected ? cs.onTertiaryContainer : cs.onSecondaryContainer);
    return SizedBox(
      width: 96,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: s,
          height: s,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            boxShadow: big ? [BoxShadow(color: bg.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 5))] : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Icon(icon, color: fg, size: big ? 32 : 24)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

/// Big readout: number large, unit small.
class Readout extends StatelessWidget {
  const Readout(this.degrees, {super.key, this.signed = false, this.abs = true, this.level = false, this.size = 84, this.dash = false, this.color});
  final double degrees;
  final bool signed, abs, level, dash;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = dash ? '—' : fmt(degrees, signed: signed, abs: abs);
    final unit = store.unit;
    String number = text, suffix = '';
    if (!dash && text != '—') {
      if (unit == Unit.degrees) {
        number = text.substring(0, text.length - 1);
        suffix = '°';
      } else {
        final i = text.lastIndexOf(' ');
        number = text.substring(0, i);
        suffix = text.substring(i + 1);
      }
    }
    final c = color ?? (level ? Color.lerp(alertColor(), cs.onSurface, 0.15)! : cs.onSurface);
    final num = TextStyle(
      fontFamily: 'Roboto',
      fontSize: size,
      height: 1,
      fontWeight: FontWeight.w500,
      letterSpacing: -size * 0.04,
      color: c,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(number, style: num),
      if (suffix.isNotEmpty)
        Padding(
          padding: EdgeInsets.only(top: size * (unit == Unit.degrees ? 0.02 : 0.12), left: size * 0.03),
          child: Text(suffix,
              style: num.copyWith(
                  fontSize: unit == Unit.degrees ? size * 0.62 : size * 0.3,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  color: c.withValues(alpha: 0.7))),
        ),
    ]);
  }
}

/// Small caption with an icon, under the readout.
class Caption extends StatelessWidget {
  const Caption(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 16, color: cs.onSurfaceVariant), const SizedBox(width: 6)],
        Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
      ]),
    );
  }
}
