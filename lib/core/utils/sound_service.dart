import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../data/hive_database.dart';

class SoundService {
  static const String _soundKey = 'sound_effects_enabled';

  static bool isSoundEnabled() {
    return HiveDatabase.settingsBox.get(_soundKey, defaultValue: true) as bool;
  }

  static Future<void> setSoundEnabled(bool enabled) async {
    await HiveDatabase.settingsBox.put(_soundKey, enabled);
  }

  /// Play POS barcode scan beep and light haptic feedback
  static Future<void> playScanBeep() async {
    if (!isSoundEnabled()) {
      Vibration.vibrate(duration: 30);
      return;
    }
    try {
      SystemSound.play(SystemSoundType.click);
      Vibration.vibrate(duration: 40);
    } catch (_) {}
  }

  /// Play cash register checkout ding / success sound
  static Future<void> playCheckoutSuccess() async {
    if (!isSoundEnabled()) {
      Vibration.vibrate(duration: 80);
      return;
    }
    try {
      SystemSound.play(SystemSoundType.click);
      Vibration.vibrate(pattern: [0, 60, 40, 90]);
    } catch (_) {}
  }

  /// Play trash / cart empty sound
  static Future<void> playDeleteSound() async {
    if (!isSoundEnabled()) {
      Vibration.vibrate(duration: 50);
      return;
    }
    try {
      SystemSound.play(SystemSoundType.click);
      Vibration.vibrate(duration: 60);
    } catch (_) {}
  }

  /// Alias for item removed from cart
  static Future<void> playItemRemoved() => playDeleteSound();

  /// Play error / warning alert tone
  static Future<void> playWarningSound() async {
    if (!isSoundEnabled()) {
      Vibration.vibrate(duration: 100);
      return;
    }
    try {
      SystemSound.play(SystemSoundType.alert);
      Vibration.vibrate(pattern: [0, 80, 50, 80]);
    } catch (_) {}
  }
}
