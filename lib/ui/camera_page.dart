import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/level_math.dart';
import '../models/models.dart';
import '../services/meter.dart';
import '../services/sensor.dart';
import '../services/store.dart';
import 'instrument.dart';
import 'painters.dart';
import 'widgets.dart';

/// Camera mode: live preview with guidelines that follow the true horizon.
class CameraPage extends StatefulWidget {
  const CameraPage({super.key, this.usePreview = true});
  final bool usePreview;
  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  late final Meter meter = Meter(Mode.level)..start();
  CameraController? _cam;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.usePreview) _open();
  }

  Future<void> _open() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) throw Exception('none');
      final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      final c = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _cam = c;
        _error = null;
      });
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _error = e.code.contains('Access')
            ? tr('Permite accesul la cameră din setările telefonului.', 'Allow camera access in the phone settings.')
            : tr('Camera nu a putut fi pornită.', 'The camera could not be started.'));
      }
    } catch (_) {
      if (mounted) setState(() => _error = tr('Camera nu a putut fi pornită.', 'The camera could not be started.'));
    }
  }

  Future<void> _close() async {
    final c = _cam;
    _cam = null;
    if (mounted) setState(() {});
    await c?.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.usePreview) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _close();
    } else if (state == AppLifecycleState.resumed && _cam == null) {
      _open();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    meter.dispose();
    super.dispose();
  }

  void _guides() {
    showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, set) {
        void upd(VoidCallback f) {
          f();
          store.save();
          set(() {});
          setState(() {});
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(tr('Ghidaje', 'Guidelines'), style: Theme.of(context).textTheme.titleLarge),
              ),
              ListTile(
                title: Text(tr('Grilă', 'Grid')),
                trailing: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 0, label: Text(tr('Fără', 'Off'))),
                    const ButtonSegment(value: 3, label: Text('3×3')),
                    const ButtonSegment(value: 4, label: Text('4×4')),
                  ],
                  selected: {store.grid},
                  onSelectionChanged: (s) => upd(() => store.grid = s.first),
                ),
              ),
              SwitchListTile(
                title: Text(tr('Linia orizontului', 'Horizon line')),
                value: store.horizon,
                onChanged: (v) => upd(() => store.horizon = v),
              ),
              SwitchListTile(
                title: Text(tr('Linii verticale', 'Vertical lines')),
                value: store.plumbLines,
                onChanged: (v) => upd(() => store.plumbLines = v),
              ),
              SwitchListTile(
                title: Text(tr('Țintă în centru', 'Centre crosshair')),
                value: store.crosshair,
                onChanged: (v) => upd(() => store.crosshair = v),
              ),
              ListTile(
                title: Text(tr('Vizibilitate', 'Visibility')),
                subtitle: Slider(
                  value: store.guideOpacity,
                  min: 0.3,
                  max: 1,
                  onChanged: (v) => upd(() => store.guideOpacity = v),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cam = _cam;
    return Container(
      color: Colors.black,
      child: Stack(fit: StackFit.expand, children: [
        if (cam != null && cam.value.isInitialized)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: cam.value.previewSize?.height ?? 1080,
              height: cam.value.previewSize?.width ?? 1920,
              child: CameraPreview(cam),
            ),
          )
        else
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF41566B), Color(0xFF8A9BA8), Color(0xFF5B6B52), Color(0xFF3B4733)],
                stops: [0, 0.48, 0.52, 1],
              ),
            ),
            child: _error == null
                ? const SizedBox.shrink()
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
          ),
        ListenableBuilder(
          listenable: meter,
          builder: (context, _) {
            final r = meter.reading;
            final level = meter.isLevel(r) && Sensor.instance.hasData;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: meter.toggleLock,
              child: RotatedBox(
                quarterTurns: r.edge.quarterTurns,
                child: Stack(fit: StackFit.expand, children: [
                  Smoothed(
                    values: [r.angle],
                    builder: (context, v) => CustomPaint(
                    painter: CameraGuidesPainter(
                      angle: v[0],
                      level: level,
                      alert: alertColor(),
                      grid: store.grid,
                      horizon: store.horizon,
                      plumbLines: store.plumbLines,
                      crosshair: store.crosshair,
                      opacity: store.guideOpacity,
                    ),
                  ),
                  ),
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: _Readout(
                          angle: meter.stable('cam', r.angle),
                          forward: meter.stable('fwd', r.forward),
                          level: level,
                          locked: meter.locked,
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ListenableBuilder(
                listenable: meter,
                builder: (context, _) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _RoundButton(icon: Icons.grid_on, label: tr('Ghidaje', 'Guides'), onTap: _guides),
                  const SizedBox(width: 18),
                  _RoundButton(
                    icon: meter.locked ? Icons.lock : (meter.lockState == MeterLock.live ? Icons.lock_open : Icons.timer_outlined),
                    label: meter.lockState == MeterLock.countdown
                        ? '${meter.secondsLeft} s'
                        : (meter.locked ? tr('Blocat', 'Locked') : tr('Blochează', 'Lock')),
                    onTap: meter.lockPressed,
                    big: true,
                    active: meter.lockState != MeterLock.live,
                  ),
                  const SizedBox(width: 18),
                  _RoundButton(
                    icon: Icons.bookmark_add_outlined,
                    label: tr('Salvează', 'Save'),
                    onTap: () {
                      final m = meter.toMeasurement();
                      store.addMeasurement(Measurement(
                          id: m.id, time: m.time, mode: Mode.level, angle: m.angle, unit: m.unit, where: tr('Cameră', 'Camera')));
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                            content: Text(tr('Salvat: ${measurementValue(m)}', 'Saved: ${measurementValue(m)}')),
                            duration: const Duration(seconds: 2)));
                    },
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({required this.angle, required this.forward, required this.level, required this.locked});
  final double angle, forward;
  final bool level, locked;

  @override
  Widget build(BuildContext context) {
    final c = level ? alertColor() : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(20)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (locked) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.lock, color: Colors.white, size: 20)),
          Text(fmt(angle, abs: true),
              style: TextStyle(
                  color: c, fontSize: 40, fontWeight: FontWeight.w300, height: 1.05, fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
        const SizedBox(height: 2),
        Text(tr('Față / spate ${fmt(forward, signed: true)}', 'Forward / back ${fmt(forward, signed: true)}'),
            style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
      ]),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onTap, this.big = false, this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool big, active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = big ? 70.0 : 54.0;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Material(
        color: active ? cs.primary : Colors.black.withValues(alpha: 0.5),
        shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: big ? 3 : 1.5)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: s, height: s, child: Icon(icon, color: active ? cs.onPrimary : Colors.white, size: big ? 30 : 24)),
        ),
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    ]);
  }
}
