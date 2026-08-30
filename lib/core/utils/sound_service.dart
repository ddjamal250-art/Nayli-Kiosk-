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
    try {
      HapticFeedback.selectionClick();
      if (isSoundEnabled()) {
        SystemSound.play(SystemSoundType.click);
      }
      final hasVib = await Vibration.hasVibrator();
      if (hasVib == true) {
        Vibration.vibrate(duration: 45);
      }
    } catch (_) {}
  }

  /// Play cash register checkout ding / success sound
  static Future<void> playCheckoutSuccess() async {
    try {
      HapticFeedback.heavyImpact();
      if (isSoundEnabled()) {
        SystemSound.play(SystemSoundType.click);
      }
      final hasVib = await Vibration.hasVibrator();
      if (hasVib == true) {
        Vibration.vibrate(pattern: [0, 50, 40, 90]);
      }
    } catch (_) {}
  }

  /// Play trash / cart empty sound
  static Future<void> playDeleteSound() async {
    try {
      HapticFeedback.mediumImpact();
      if (isSoundEnabled()) {
        SystemSound.play(SystemSoundType.click);
      }
      final hasVib = await Vibration.hasVibrator();
      if (hasVib == true) {
        Vibration.vibrate(duration: 70);
      }
    } catch (_) {}
  }

  /// Alias for item removed from cart
  static Future<void> playItemRemoved() => playDeleteSound();

  /// Play error / warning alert tone
  static Future<void> playWarningSound() async {
    try {
      HapticFeedback.vibrate();
      if (isSoundEnabled()) {
        SystemSound.play(SystemSoundType.alert);
      }
      final hasVib = await Vibration.hasVibrator();
      if (hasVib == true) {
        Vibration.vibrate(pattern: [0, 90, 60, 90]);
      }
    } catch (_) {}
  }
}
