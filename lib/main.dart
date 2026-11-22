import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/i18n.dart';
import 'services/native.dart';
import 'services/store.dart';
import 'ui/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The UI turns itself to follow the phone; the system must not rotate it too.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await store.load();
  Native.keepScreenOn(store.keepOn);
  runApp(const NivelaApp());
}

class NivelaApp extends StatelessWidget {
  const NivelaApp({super.key});

  static ThemeData theme(Brightness b, {int? seed}) {
    final scheme = ColorScheme.fromSeed(seedColor: Color(seed ?? store.seed), brightness: b);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      bottomSheetTheme: const BottomSheetThemeData(showDragHandle: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => MaterialApp(
        key: ValueKey(currentLang),
        title: 'Nivela',
        debugShowCheckedModeBanner: false,
        themeMode: store.themeMode,
        theme: theme(Brightness.light),
        darkTheme: theme(Brightness.dark),
        home: const HomeShell(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: child!,
        ),
      ),
    );
  }
}
