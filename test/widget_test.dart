import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivela/core/i18n.dart';
import 'package:nivela/main.dart';
import 'package:nivela/services/sensor.dart';
import 'package:nivela/core/level_math.dart';
import 'package:nivela/ui/home_shell.dart';

void main() {
  testWidgets('app opens on the level screen and switches tabs', (t) async {
    setLanguage('ro');
    Sensor.instance.debugSet(vecForEdge(Edge.bottom, 1));
    await t.pumpWidget(MaterialApp(theme: NivelaApp.theme(Brightness.light), home: const HomeShell(cameraPreview: false)));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Nivel'), findsWidgets);
    await t.tap(find.text('Setări'));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Calibrare ghidată'), findsOneWidget);
  });
}
