// Renders every screen to PNG for visual review (CI uploads them).
// Runs only when SCREEN_FONTS points to a folder with Roboto *.ttf files.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivela/core/i18n.dart';
import 'package:nivela/core/level_math.dart';
import 'package:nivela/main.dart';
import 'package:nivela/models/models.dart';
import 'package:nivela/services/sensor.dart';
import 'package:nivela/services/store.dart';
import 'package:nivela/ui/calibration_page.dart';
import 'package:nivela/ui/home_shell.dart';

final fontsDir = Platform.environment['SCREEN_FONTS'];

Future<void> loadFonts() async {
  final roboto = FontLoader('Roboto');
  for (final f in Directory(fontsDir!).listSync(recursive: true)) {
    final n = f.path.toLowerCase();
    if (n.endsWith('.ttf') && n.contains('roboto') && !n.contains('condensed') && !n.contains('mono') && !n.contains('slab')) {
      final bytes = File(f.path).readAsBytesSync();
      roboto.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
  }
  await roboto.load();
  // Material icons ship with the Flutter SDK.
  final root = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final l = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
    await l.load();
  }
}

void seed() {
  store.measurements
    ..clear()
    ..addAll([
      Measurement(id: '1', time: DateTime(2026, 11, 22, 15, 40), mode: Mode.level, angle: 0.2, unit: Unit.degrees, where: Face.bottom.label, note: tr('Raft bucătărie', 'Kitchen shelf')),
      Measurement(id: '2', time: DateTime(2026, 11, 22, 15, 12), mode: Mode.flat, angle: 1.4, x: 0.9, y: -1.1, unit: Unit.percent, where: Face.back.label),
      Measurement(id: '3', time: DateTime(2026, 11, 21, 18, 3), mode: Mode.plumb, angle: 0.6, unit: Unit.mmPerM, where: Face.left.label, note: tr('Toc ușă', 'Door frame')),
      Measurement(id: '4', time: DateTime(2026, 11, 20, 10, 30), mode: Mode.level, angle: 2.35, unit: Unit.degrees, relative: true, where: Face.right.label),
    ]);
  store.profiles.first.offsets
    ..clear()
    ..[Face.back] = [0.21, -0.08]
    ..[Face.bottom] = [0.34]
    ..[Face.left] = [-0.12];
}

Widget app(Widget home, Brightness b) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NivelaApp.theme(b),
      home: home,
    );

Future<void> shot(WidgetTester t, String name, Widget home, {Brightness b = Brightness.light, Vec3? v}) async {
  Sensor.instance.debugSet(v ?? vecForEdge(Edge.bottom, 1.6, forward: 8));
  await t.pumpWidget(const SizedBox());
  await t.pumpWidget(app(home, b));
  await t.pump(const Duration(milliseconds: 300));
  Sensor.instance.debugSet(v ?? vecForEdge(Edge.bottom, 1.6, forward: 8));
  await t.pump(const Duration(milliseconds: 300));
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('screens/$name.png'));
}

void main() {
  final skip = fontsDir == null;

  setUpAll(() async {
    if (skip) return;
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadFonts();
  });

  for (final lang in ['ro', 'en']) {
    testWidgets('screens $lang', (t) async {
      debugDisableShadows = false;
      addTearDown(() => debugDisableShadows = true);
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.625;
      addTearDown(t.view.reset);
      setLanguage(lang);
      seed();
      final pre = lang == 'ro' ? '' : 'en_';
      const shell = HomeShell(cameraPreview: false);

      store.lastMode = Mode.level;
      await shot(t, '${pre}01_level', shell);
      store.lastMode = Mode.flat;
      await shot(t, '${pre}02_flat', shell, v: vecForFlat(1.2, -0.7));
      store.lastMode = Mode.plumb;
      await shot(t, '${pre}03_plumb', shell, v: vecForEdge(Edge.bottom, -2.2, forward: 4));
      if (lang == 'en') return;
      store.lastMode = Mode.level;
      await shot(t, '04_level_ok_dark', shell, b: Brightness.dark, v: vecForEdge(Edge.bottom, 0.1));
      await shot(t, '05_level_landscape', shell, v: vecForEdge(Edge.right, -3.4));
      store.lastMode = Mode.flat;
      await shot(t, '06_flat_dark', shell, b: Brightness.dark, v: vecForFlat(0.1, 0.05));
      store.lastMode = Mode.plumb;
      await shot(t, '07_plumb_dark', shell, b: Brightness.dark, v: vecForEdge(Edge.bottom, 0.9));
      await shot(t, '08_camera', const HomeShell(cameraPreview: false, initialTab: 1), v: vecForEdge(Edge.bottom, 4.5, forward: 3));
      await shot(t, '09_saved', const HomeShell(cameraPreview: false, initialTab: 2));
      await shot(t, '10_saved_dark', const HomeShell(cameraPreview: false, initialTab: 2), b: Brightness.dark);
      await shot(t, '11_settings', const HomeShell(cameraPreview: false, initialTab: 3));
      await shot(t, '12_settings_dark', const HomeShell(cameraPreview: false, initialTab: 3), b: Brightness.dark);
      await shot(t, '13_calibration', const CalibrationPage());
      await shot(t, '14_wizard', const CalibrationWizard(faces: [Face.bottom, Face.back]), v: vecForFlat(0, 0));
      store.lastMode = Mode.level;
      await shot(t, '15_level_lying', shell, v: vecForFlat(0.5, 0.5));
      store.measurements.clear();
      await shot(t, '16_saved_empty', const HomeShell(cameraPreview: false, initialTab: 2));
    }, skip: skip);
  }
}
