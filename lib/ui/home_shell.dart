import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../services/store.dart';
import 'camera_page.dart';
import 'level_page.dart';
import 'saved_page.dart';
import 'settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = 0, this.cameraPreview = true});
  final int initialTab;

  /// False in tests/screenshots: no real camera.
  final bool cameraPreview;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final page = switch (_tab) {
      0 => const LevelPage(),
      1 => CameraPage(usePreview: widget.cameraPreview),
      2 => SavedPage(onMeasure: () => setState(() => _tab = 0)),
      _ => const SettingsPage(),
    };
    return Scaffold(
      body: page,
      bottomNavigationBar: ListenableBuilder(
        listenable: store,
        builder: (context, _) => NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.straighten_outlined),
              selectedIcon: const Icon(Icons.straighten),
              label: tr('Nivelă', 'Level')),
          NavigationDestination(
              icon: const Icon(Icons.photo_camera_outlined),
              selectedIcon: const Icon(Icons.photo_camera),
              label: tr('Cameră', 'Camera')),
          NavigationDestination(
              icon: Badge(
                isLabelVisible: store.measurements.isNotEmpty,
                label: Text('${store.measurements.length}'),
                child: const Icon(Icons.bookmarks_outlined),
              ),
              selectedIcon: const Icon(Icons.bookmarks),
              label: tr('Salvate', 'Saved')),
          NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: tr('Setări', 'Settings')),
        ],
      ),
      ),
    );
  }
}
