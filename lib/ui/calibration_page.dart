import 'dart:async';

import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/level_math.dart';

import '../services/native.dart';
import '../services/sensor.dart';
import '../services/store.dart';
import 'widgets.dart';

/// Six positions; each is measured twice on the same spot, rotated 180°, so
/// the surface tilt cancels out and only the phone's own offset remains.
class CalibrationPage extends StatefulWidget {
  const CalibrationPage({super.key, this.start});

  /// Opens the wizard straight away for this position.
  final Face? start;

  @override
  State<CalibrationPage> createState() => _CalibrationPageState();
}

class _CalibrationPageState extends State<CalibrationPage> {
  @override
  void initState() {
    super.initState();
    if (widget.start != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run([widget.start!]));
    }
  }

  Future<void> _run(List<Face> faces) async {
    await Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => CalibrationWizard(faces: faces)));
    if (mounted) setState(() {});
  }

  Future<void> _rename() async {
    final p = store.profile;
    final c = TextEditingController(text: p.name);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Numele profilului', 'Profile name')),
        content: TextField(controller: c, autofocus: true, maxLength: 18),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Anulează', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(tr('Salvează', 'Save'))),
        ],
      ),
    );
    if (v != null && v.trim().isNotEmpty) {
      p.name = v.trim();
      store.save();
      setState(() {});
    }
  }

  String _value(Face f) {
    final o = store.profile.offsets[f];
    if (o == null) return tr('necalibrat', 'not calibrated');
    if (f.isFlat) return 'X ${fmtAngle(o[0], Unit.degrees, 2, signed: true)} · Y ${fmtAngle(o[1], Unit.degrees, 2, signed: true)}';
    return fmtAngle(o[0], Unit.degrees, 2, signed: true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final p = store.profile;
    final missing = Face.values.where((f) => !p.has(f)).toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Calibrare', 'Calibration'))),
      body: MaxWidth(
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (var i = 0; i < store.profiles.length; i++)
                  ButtonSegment(value: i, label: Text(store.profiles[i].name, overflow: TextOverflow.ellipsis)),
              ],
              selected: {store.activeProfile},
              onSelectionChanged: (s) {
                store.activeProfile = s.first;
                store.save();
                setState(() {});
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline),
            title: Text(tr('Redenumește profilul', 'Rename profile')),
            subtitle: Text(tr('Ex. separat pentru telefon cu husă și fără', 'E.g. one for the phone with a case, one without')),
            onTap: _rename,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              tr('Nu ai nevoie de o suprafață perfect dreaptă: fiecare poziție se măsoară de două ori în același loc, a doua oară rotită cu 180°.',
                  'You do not need a perfectly level surface: each position is measured twice on the same spot, the second time turned 180°.'),
              style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: () => _run(missing.isEmpty ? Face.values : missing),
              icon: const Icon(Icons.play_arrow),
              label: Text(missing.isEmpty
                  ? tr('Recalibrează toate cele 6 poziții', 'Recalibrate all 6 positions')
                  : missing.length == 6
                      ? tr('Pornește calibrarea ghidată', 'Start guided calibration')
                      : tr('Calibrează cele ${missing.length} rămase', 'Calibrate the remaining ${missing.length}')),
            ),
          ),
          SectionTitle(tr('Poziții', 'Positions')),
          for (final f in Face.values)
            ListTile(
              leading: _FaceIcon(f, size: 30),
              title: Text(f.label),
              subtitle: Text(_value(f), style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
              trailing: p.has(f) ? Icon(Icons.check_circle, color: cs.primary) : Icon(Icons.radio_button_unchecked, color: cs.outline),
              onTap: () => _run([f]),
            ),
          if (p.count > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: OutlinedButton.icon(
                onPressed: () {
                  p.offsets.clear();
                  store.save();
                  setState(() {});
                },
                icon: const Icon(Icons.restart_alt),
                label: Text(tr('Șterge calibrarea acestui profil', 'Clear this profile\'s calibration')),
              ),
            ),
        ]),
      ),
    );
  }
}

class _FaceIcon extends StatelessWidget {
  const _FaceIcon(this.face, {this.size = 40});
  final Face face;
  final double size;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = Icon(face == Face.front ? Icons.phone_android : Icons.smartphone, size: size, color: cs.primary);
    return switch (face) {
      Face.back || Face.front => Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.004)
            ..rotateX(1.0),
          child: Opacity(opacity: face == Face.front ? 0.55 : 1, child: icon),
        ),
      Face.bottom => icon,
      Face.left => RotatedBox(quarterTurns: 3, child: icon),
      Face.top => RotatedBox(quarterTurns: 2, child: icon),
      Face.right => RotatedBox(quarterTurns: 1, child: icon),
    };
  }
}

enum _Step { position, still, measure, rotate, still2, measure2, done }

class CalibrationWizard extends StatefulWidget {
  const CalibrationWizard({super.key, required this.faces});
  final List<Face> faces;
  @override
  State<CalibrationWizard> createState() => _CalibrationWizardState();
}

class _CalibrationWizardState extends State<CalibrationWizard> {
  int _i = 0;
  _Step _step = _Step.position;
  final _samples = <Vec3>[];
  List<double>? _first;
  bool _moved = false;
  Timer? _timer;
  static const _needed = 75; // ≈ 1.5 s

  Face get face => widget.faces[_i];

  @override
  void initState() {
    super.initState();
    Sensor.instance.start();
    Sensor.instance.addRawListener(_onRaw);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    Sensor.instance.removeRawListener(_onRaw);
    Sensor.instance.stop();
    super.dispose();
  }

  bool _inPosition(Vec3 a) {
    final up = uprightness(a);
    return switch (face) {
      Face.back => up < 0.25 && a.z > 0,
      Face.front => up < 0.25 && a.z < 0,
      _ => up > 0.9 && faceOf(downEdge(a)) == face,
    };
  }

  List<double> _valueOf(Vec3 mean) {
    if (face.isFlat) {
      final t = flatTilt(mean);
      return [t.x, t.y];
    }
    return [edgeAngle(mean, Edge.values[face.index - 2])];
  }

  void _onRaw(Vec3 v) {
    if (_step != _Step.measure && _step != _Step.measure2) return;
    if (Sensor.instance.jitter > 0.15 || !_inPosition(v)) {
      _samples.clear();
      setState(() => _step = _step == _Step.measure ? _Step.still : _Step.still2);
      return;
    }
    _samples.add(v);
    if (_samples.length >= _needed) {
      var s = Vec3.zero;
      for (final x in _samples) {
        s = s + x;
      }
      final value = _valueOf(s * (1 / _samples.length));
      _samples.clear();
      if (_step == _Step.measure) {
        _first = value;
        _moved = false;
        Native.vibrate(50);
        setState(() => _step = _Step.rotate);
      } else {
        final offset = [for (var k = 0; k < value.length; k++) (value[k] + _first![k]) / 2];
        store.profile.offsets[face] = offset;
        store.save();
        Native.vibrate(120);
        setState(() => _step = _Step.done);
      }
    } else if (_samples.length % 8 == 0) {
      setState(() {});
    }
  }

  void _tick() {
    if (!mounted) return;
    final s = Sensor.instance;
    if (!s.hasData) return;
    final a = s.value;
    switch (_step) {
      case _Step.position:
        if (_inPosition(a)) setState(() => _step = _Step.still);
      case _Step.still:
        if (!_inPosition(a)) {
          setState(() => _step = _Step.position);
        } else if (s.isStill) {
          _samples.clear();
          setState(() => _step = _Step.measure);
        }
      case _Step.rotate:
        if (s.isMoving || !_inPosition(a)) _moved = true;
        if (_moved && _inPosition(a) && s.isStill) {
          _samples.clear();
          setState(() => _step = _Step.measure2);
        } else if (_moved) {
          setState(() => _step = _Step.still2);
        }
      case _Step.still2:
        if (_inPosition(a) && s.isStill) {
          _samples.clear();
          setState(() => _step = _Step.measure2);
        }
      default:
        break;
    }
  }

  void _next() {
    if (_i + 1 >= widget.faces.length) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _i++;
      _step = _Step.position;
      _first = null;
      _samples.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final second = _step.index >= _Step.rotate.index;
    final (title, body) = switch (_step) {
      _Step.position => (face.label, face.hint),
      _Step.still || _Step.still2 => (tr('Nu atinge telefonul', 'Don\'t touch the phone'), tr('Aștept să stea nemișcat…', 'Waiting for it to hold still…')),
      _Step.measure || _Step.measure2 => (tr('Măsor…', 'Measuring…'), tr('Nu atinge telefonul', 'Don\'t touch the phone')),
      _Step.rotate => (
          tr('Rotește cu 180°', 'Turn it 180°'),
          face.isFlat
              ? tr('Rotește telefonul pe loc, cu 180°, în același loc pe suprafață.', 'Spin the phone 180° on the same spot.')
              : tr('Întoarce telefonul cu ecranul spre partea cealaltă, pe aceeași muchie, în același loc.',
                  'Turn the phone to face the other way, on the same edge and the same spot.')
        ),
      _Step.done => (tr('Gata', 'Done'), tr('${face.label} e calibrată.', '${face.label} is calibrated.')),
    };
    final measuring = _step == _Step.measure || _step == _Step.measure2;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Poziția ${_i + 1} din ${widget.faces.length}', 'Position ${_i + 1} of ${widget.faces.length}')),
        actions: [
          if (_step != _Step.done) TextButton(onPressed: _next, child: Text(tr('Sari peste', 'Skip'))),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            LinearProgressIndicator(
              value: (_i + (_step == _Step.done ? 1 : (second ? 0.5 : 0))) / widget.faces.length,
              borderRadius: BorderRadius.circular(4),
            ),
            const Spacer(),
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: _step == _Step.done ? cs.primaryContainer : cs.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _step == _Step.done
                    ? Icon(Icons.check, size: 72, color: cs.onPrimaryContainer)
                    : AnimatedRotation(
                        turns: _step == _Step.rotate ? 0.5 : 0,
                        duration: const Duration(milliseconds: 600),
                        child: _FaceIcon(face, size: 76),
                      ),
              ),
            ),
            const SizedBox(height: 28),
            Text(title, style: t.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(body, style: t.bodyLarge?.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
            const SizedBox(height: 22),
            SizedBox(
              height: 6,
              child: measuring
                  ? LinearProgressIndicator(value: _samples.length / _needed, borderRadius: BorderRadius.circular(4))
                  : null,
            ),
            const SizedBox(height: 10),
            if (_step != _Step.done)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _Dot(on: second || _step == _Step.measure, done: second),
                const SizedBox(width: 8),
                _Dot(on: second, done: false),
                const SizedBox(width: 10),
                Text(second ? tr('Măsurarea 2 din 2', 'Reading 2 of 2') : tr('Măsurarea 1 din 2', 'Reading 1 of 2'),
                    style: t.bodySmall),
              ]),
            const Spacer(),
            if (_step == _Step.done)
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _next,
                child: Text(_i + 1 >= widget.faces.length ? tr('Termină', 'Finish') : tr('Următoarea poziție', 'Next position')),
              ),
          ]),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.on, required this.done});
  final bool on, done;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(shape: BoxShape.circle, color: done ? cs.primary : (on ? cs.primary.withValues(alpha: 0.5) : cs.outlineVariant)),
    );
  }
}
