import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/level_math.dart';
import '../models/models.dart';
import '../services/store.dart';

Color alertColor() => Color(store.alertColor);

String fmt(double deg, {bool signed = false, bool abs = false, Unit? unit}) =>
    fmtAngle(deg, unit ?? store.unit, store.decimals, signed: signed, abs: abs);

String dateTimeText(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
}

/// Main value of a saved measurement, in the unit it was saved with.
String measurementValue(Measurement m) =>
    fmtAngle(m.angle, m.unit, store.decimals, abs: m.mode != Mode.flat);

String measurementDetail(Measurement m) {
  final parts = <String>[
    m.mode.label,
    if (m.where.isNotEmpty) m.where,
    if (m.x != null && m.y != null)
      'X ${fmtAngle(m.x!, m.unit, store.decimals, signed: true)} · Y ${fmtAngle(m.y!, m.unit, store.decimals, signed: true)}',
    if (m.relative) tr('relativ', 'relative'),
  ];
  return parts.join(' · ');
}

/// Text for copy / share.
String measurementText(Measurement m) {
  final b = StringBuffer('Nivela · ${measurementValue(m)} · ${measurementDetail(m)} · ${dateTimeText(m.time)}');
  if (m.note.trim().isNotEmpty) b.write('\n${m.note.trim()}');
  return b.toString();
}

class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.child, this.width = 720});
  final Widget child;
  final double width;
  @override
  Widget build(BuildContext context) =>
      Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: width), child: child));
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
      child: Text(text.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.primary, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
    );
  }
}

/// Small rounded status label.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.icon, this.color, this.onTap, this.filled = false, this.trailing});
  final String text;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  final bool filled;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.onSurfaceVariant;
    final bg = filled ? c : c.withValues(alpha: 0.12);
    final fg = filled ? (ThemeData.estimateBrightnessForColor(c) == Brightness.dark ? Colors.white : Colors.black) : c;
    return Material(
      color: bg,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 15, color: fg), const SizedBox(width: 5)],
            Text(text, style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w600)),
            if (trailing != null) ...[const SizedBox(width: 2), Icon(trailing, size: 16, color: fg)],
          ]),
        ),
      ),
    );
  }
}

/// Settings-style subtle table row: label left, value right.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.last = false, this.strong = false});
  final String label, value;
  final bool last, strong;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          Expanded(child: Text(label, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
          Text(value,
              style: (strong ? t.titleMedium : t.bodyLarge)?.copyWith(
                  fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      ),
      if (!last) Divider(height: 1, thickness: 0.6, color: cs.outlineVariant.withValues(alpha: 0.6)),
    ]);
  }
}

class ColorDot extends StatelessWidget {
  const ColorDot(this.color, {super.key, required this.selected, required this.onTap});
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? cs.onSurface : Colors.transparent, width: 2.5),
        ),
        child: selected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
      ),
    );
  }
}
