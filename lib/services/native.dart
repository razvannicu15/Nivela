import 'package:flutter/services.dart';

/// Bridge to MainActivity.kt: vibration, beeps, screen-on and sharing.
class Native {
  static const _ch = MethodChannel('nivela/native');

  static Future<void> _call(String m, [Object? a]) async {
    try {
      await _ch.invokeMethod(m, a);
    } catch (_) {}
  }

  static Future<void> keepScreenOn(bool on) => _call('keepOn', on);
  static Future<void> vibrate([int ms = 40]) => _call('vibrate', ms);

  /// kind: 'level' (reached), 'lock' (reading locked), 'tick' (short click).
  static Future<void> beep(String kind) => _call('beep', kind);
  static Future<void> share(String text) => _call('share', text);
}
