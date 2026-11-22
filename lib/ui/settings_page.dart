import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/level_math.dart';
import '../services/native.dart';
import '../services/store.dart';
import 'calibration_page.dart';
import 'widgets.dart';

/// Set by CI: --dart-define=BUILD=123 --dart-define=BUILT=22.11 14:58
const _build = String.fromEnvironment('BUILD');
const _built = String.fromEnvironment('BUILT');
String get _version => _build.isEmpty ? 'Nivela 0.1' : 'Nivela 0.1.$_build${_built.isEmpty ? '' : ' · $_built'}';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  void _set(VoidCallback f) {
    f();
    store.save();
    setState(() {});
  }

  Future<T?> _pick<T>(String title, List<(T, String)> options, T current) => showModalBottomSheet<T>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(title, style: Theme.of(ctx).textTheme.titleLarge),
            ),
            RadioGroup<T>(
              groupValue: current,
              onChanged: (v) => Navigator.pop(ctx, v),
              child: Column(children: [
                for (final (v, label) in options) RadioListTile<T>(value: v, title: Text(label)),
              ]),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = store.profile;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Setări', 'Settings'))),
      body: MaxWidth(
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          SectionTitle(tr('Limbă', 'Language')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 'system', label: Text(tr('Automat', 'Automatic'))),
                  const ButtonSegment(value: 'ro', label: Text('Română')),
                  const ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {store.language},
                onSelectionChanged: (s) => _set(() => store.language = s.first),
              ),
            ),
          ),
          SectionTitle(tr('Aspect', 'Appearance')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined)),
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined)),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined)),
                ],
                selected: {store.themeMode},
                onSelectionChanged: (s) => _set(() => store.themeMode = s.first),
              ),
            ),
          ),
          ListTile(
            title: Text(tr('Culoare temă', 'Theme colour')),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(spacing: 10, runSpacing: 10, children: [
                for (final c in themeColors)
                  ColorDot(Color(c), selected: store.seed == c, onTap: () => _set(() => store.seed = c)),
              ]),
            ),
          ),
          SectionTitle(tr('Afișare', 'Display')),
          ListTile(
            leading: const Icon(Icons.straighten),
            title: Text(tr('Unitate', 'Unit')),
            subtitle: Text(store.unit.label),
            onTap: () async {
              final v = await _pick(tr('Unitate', 'Unit'), [for (final u in Unit.values) (u, u.label)], store.unit);
              if (v != null) _set(() => store.unit = v);
            },
          ),
          ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: Text(tr('Zecimale', 'Decimals')),
            trailing: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('0')),
                ButtonSegment(value: 1, label: Text('0,0')),
                ButtonSegment(value: 2, label: Text('0,00')),
              ],
              selected: {store.decimals},
              onSelectionChanged: (s) => _set(() => store.decimals = s.first),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.light_mode_outlined),
            title: Text(tr('Ecranul rămâne aprins', 'Keep screen on')),
            value: store.keepOn,
            onChanged: (v) {
              _set(() => store.keepOn = v);
              Native.keepScreenOn(v);
            },
          ),
          SectionTitle(tr('Alerte', 'Alerts')),
          ListTile(
            leading: const Icon(Icons.track_changes),
            title: Text(tr('Toleranță „la nivel”', '"Level" tolerance')),
            subtitle: Slider(
              value: store.tolerance,
              min: 0.1,
              max: 3,
              divisions: 29,
              label: '±${fmtNumber(store.tolerance, 1)}°',
              onChanged: (v) => _set(() => store.tolerance = double.parse(v.toStringAsFixed(1))),
            ),
            trailing: Text('±${fmtNumber(store.tolerance, 1)}°',
                style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
          ),
          ListTile(
            title: Text(tr('Culoare alertă', 'Alert colour')),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(spacing: 10, runSpacing: 10, children: [
                for (final c in alertColors)
                  ColorDot(Color(c), selected: store.alertColor == c, onTap: () => _set(() => store.alertColor = c)),
              ]),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: Text(tr('Vibrație', 'Vibration')),
            value: store.vibrate,
            onChanged: (v) => _set(() => store.vibrate = v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: Text(tr('Sunet', 'Sound')),
            subtitle: Text(tr('La nivel și la blocare', 'When level and when locked')),
            value: store.sound,
            onChanged: (v) {
              _set(() => store.sound = v);
              if (v) Native.beep('level');
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.rotate_90_degrees_ccw),
            title: Text(tr('Alertă la multipli de 45°', 'Alert at multiples of 45°')),
            subtitle: Text(tr('Nivel și Plumb: și la 45°, 90°, 135°…', 'Level and Plumb: also at 45°, 90°, 135°…')),
            value: store.every45,
            onChanged: (v) => _set(() => store.every45 = v),
          ),
          SectionTitle(tr('Măsurare', 'Measuring')),
          SwitchListTile(
            secondary: const Icon(Icons.swap_vert),
            title: Text(tr('Comutare automată Nivel / Plan', 'Auto switch Level / Flat')),
            subtitle: Text(tr('Culcat → Plan, în picioare → Nivel', 'Lying down → Flat, standing → Level')),
            value: store.autoMode,
            onChanged: (v) => _set(() => store.autoMode = v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.screen_rotation_alt),
            title: Text(tr('Muchie aleasă automat', 'Pick edge automatically')),
            subtitle: Text(store.autoEdge
                ? tr('Muchia cea mai de jos', 'The lowest edge')
                : tr('Fixă: ${store.levelEdge.label}', 'Fixed: ${store.levelEdge.label}')),
            value: store.autoEdge,
            onChanged: (v) => _set(() => store.autoEdge = v),
          ),
          ListTile(
            leading: const Icon(Icons.lock_clock_outlined),
            title: Text(tr('Blocare automată', 'Auto lock')),
            subtitle: Text(store.autoLock.label),
            onTap: () async {
              final v = await _pick(tr('Blocare automată', 'Auto lock'), [for (final a in AutoLock.values) (a, a.label)], store.autoLock);
              if (v != null) _set(() => store.autoLock = v);
            },
          ),
          ListTile(
            leading: const Icon(Icons.waves),
            title: Text(tr('Netezire citire', 'Reading smoothing')),
            subtitle: Slider(value: store.smoothing, onChanged: (v) => _set(() => store.smoothing = v)),
            trailing: Text(store.smoothing < 0.34
                ? tr('Rapid', 'Fast')
                : store.smoothing < 0.67
                    ? tr('Mediu', 'Medium')
                    : tr('Calm', 'Calm')),
          ),
          SectionTitle(tr('Calibrare', 'Calibration')),
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text(tr('Calibrare ghidată', 'Guided calibration')),
            subtitle: Text(tr('${p.name} · ${p.count} din 6 poziții', '${p.name} · ${p.count} of 6 positions')),
            trailing: p.complete
                ? Icon(Icons.check_circle, color: cs.primary)
                : Icon(Icons.error_outline, color: p.count == 0 ? cs.error : cs.tertiary),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalibrationPage()));
              setState(() {});
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (var i = 0; i < store.profiles.length; i++)
                  ButtonSegment(value: i, label: Text(store.profiles[i].name, overflow: TextOverflow.ellipsis)),
              ],
              selected: {store.activeProfile},
              onSelectionChanged: (s) => _set(() => store.activeProfile = s.first),
            ),
          ),
          SectionTitle(tr('Despre', 'About')),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(_version),
            subtitle: Text(tr('Fără reclame, toate funcțiile gratuite · by norAz', 'No ads, every feature free · by norAz')),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              tr('Nivela e un ajutor practic, nu un instrument de măsură certificat. Pentru lucrări profesionale sau de siguranță folosește o nivelă reală.',
                  'Nivela is a practical aid, not a certified measuring instrument. For professional or safety-critical work use a real level.'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ]),
      ),
    );
  }
}
