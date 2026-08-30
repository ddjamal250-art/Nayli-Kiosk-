import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../data/hive_database.dart';

class SoundThemeItem {
  final int id;
  final String name;
  final String icon;
  final String description;

  const SoundThemeItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
  });
}

class SoundService {
  static const String _soundKey = 'sound_effects_enabled';
  static const String _soundThemeKey = 'selected_sound_theme_id';
  static const String _volumeKey = 'sound_effects_volume';

  static final AudioPlayer _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  static const List<SoundThemeItem> themes = [
    SoundThemeItem(id: 1, name: 'الكلاسيكي (Beep POS Classic)', icon: '🔔', description: 'صافرة كاشير السوبرماركت العالمية السريعة'),
    SoundThemeItem(id: 2, name: 'الكريستال الرقمي (Digital Crystal)', icon: '💎', description: 'نغمة رنانة كريستالية ناعمة وفخمة'),
    SoundThemeItem(id: 3, name: 'الليزر الحديث (Modern Laser Scan)', icon: '⚡', description: 'صوت مسح ليزري حاد وسريع جداً'),
    SoundThemeItem(id: 4, name: 'صوت النقود والكاش (Cha-Ching)', icon: '🪙', description: 'رنين فتح الدرج والقطع النقدية'),
    SoundThemeItem(id: 5, name: 'النغمة الموسيقية (Melodic Chime)', icon: '🎵', description: 'نغمات موسيقية صاعدة للنجاح'),
    SoundThemeItem(id: 6, name: 'الريترو الخفيف (Retro 8-Bit)', icon: '🎮', description: 'نغمة إلكترونية مرحة وفائقة الوضوح'),
    SoundThemeItem(id: 7, name: 'المتجر الاحترافي (Pro Retail Blip)', icon: '🏢', description: 'صوت أجهزة Honeywell و Zebra'),
    SoundThemeItem(id: 8, name: 'الراديو النبضي (Pulse Tech Tone)', icon: '📻', description: 'نغمة رقمية نبضية ناعمة'),
    SoundThemeItem(id: 9, name: 'التأكيد الهادئ (Subtle Soft Click)', icon: '🛡️', description: 'صوت هادئ مريح للأذن في المسح الكثيف'),
    SoundThemeItem(id: 10, name: 'الانتصار المزدوج (Double Victory)', icon: '🎺', description: 'نغمة ثنائية عند إتمام البيع'),
  ];

  static bool isSoundEnabled() {
    return HiveDatabase.settingsBox.get(_soundKey, defaultValue: true) as bool;
  }

  static Future<void> setSoundEnabled(bool enabled) async {
    await HiveDatabase.settingsBox.put(_soundKey, enabled);
  }

  static int getSelectedThemeId() {
    return HiveDatabase.settingsBox.get(_soundThemeKey, defaultValue: 1) as int;
  }

  static Future<void> setSelectedThemeId(int themeId) async {
    await HiveDatabase.settingsBox.put(_soundThemeKey, themeId);
  }

  static double getVolume() {
    return (HiveDatabase.settingsBox.get(_volumeKey, defaultValue: 1.0) as num).toDouble();
  }

  static Future<void> setVolume(double vol) async {
    await HiveDatabase.settingsBox.put(_volumeKey, vol.clamp(0.0, 1.0));
    await _player.setVolume(vol.clamp(0.0, 1.0));
  }

  /// Synthesize custom PCM WAV audio bytes for high-fidelity interactive playback
  static Uint8List _generateWavBytes(int soundType, int themeId) {
    const int sampleRate = 22050;
    int durationMs = 80;
    double freq1 = 2000.0;
    double freq2 = 2000.0;
    bool isDoubleTone = false;

    // Configure frequencies based on Theme ID (1..10)
    switch (themeId) {
      case 1: // Classic Beep POS
        freq1 = 2200;
        durationMs = 60;
        break;
      case 2: // Digital Crystal
        freq1 = 2600;
        freq2 = 3400;
        durationMs = 85;
        isDoubleTone = true;
        break;
      case 3: // Modern Laser
        freq1 = 3600;
        freq2 = 1400;
        durationMs = 50;
        break;
      case 4: // Cha-Ching Cash
        freq1 = 1200;
        freq2 = 2400;
        durationMs = 120;
        isDoubleTone = true;
        break;
      case 5: // Melodic Chime
        freq1 = 1046; // C6
        freq2 = 1318; // E6
        durationMs = 110;
        isDoubleTone = true;
        break;
      case 6: // Retro 8-Bit
        freq1 = 1500;
        durationMs = 70;
        break;
      case 7: // Pro Retail Blip
        freq1 = 2400;
        durationMs = 45;
        break;
      case 8: // Pulse Tech
        freq1 = 1800;
        freq2 = 2200;
        durationMs = 75;
        isDoubleTone = true;
        break;
      case 9: // Subtle Soft Click
        freq1 = 1600;
        durationMs = 35;
        break;
      case 10: // Double Victory
        freq1 = 1760;
        freq2 = 2640;
        durationMs = 130;
        isDoubleTone = true;
        break;
      default:
        freq1 = 2200;
        durationMs = 60;
    }

    // Adjust for Action Type: 0 = Scan, 1 = Checkout Success, 2 = Delete, 3 = Warning
    if (soundType == 1) {
      // Checkout Success (Celebratory)
      freq1 = freq1 * 0.8;
      freq2 = freq1 * 1.5;
      durationMs = max(durationMs, 140);
      isDoubleTone = true;
    } else if (soundType == 2) {
      // Delete (Low tone drop)
      freq1 = 700;
      freq2 = 400;
      durationMs = 90;
    } else if (soundType == 3) {
      // Warning
      freq1 = 450;
      freq2 = 350;
      durationMs = 160;
      isDoubleTone = true;
    }

    final int numSamples = (sampleRate * (durationMs / 1000.0)).toInt();
    final int dataSize = numSamples * 2; // 16-bit mono
    final Uint8List bytes = Uint8List(44 + dataSize);
    final ByteData bd = ByteData.sublistView(bytes);

    // RIFF Header
    bd.setUint8(0, 0x52); // 'R'
    bd.setUint8(1, 0x49); // 'I'
    bd.setUint8(2, 0x46); // 'F'
    bd.setUint8(3, 0x46); // 'F'
    bd.setUint32(4, 36 + dataSize, Endian.little);
    bd.setUint8(8, 0x57); // 'W'
    bd.setUint8(9, 0x41); // 'A'
    bd.setUint8(10, 0x56); // 'V'
    bd.setUint8(11, 0x45); // 'E'

    // fmt Chunk
    bd.setUint8(12, 0x66); // 'f'
    bd.setUint8(13, 0x6D); // 'm'
    bd.setUint8(14, 0x74); // 't'
    bd.setUint8(15, 0x20); // ' '
    bd.setUint32(16, 16, Endian.little); // Chunk size
    bd.setUint16(20, 1, Endian.little); // PCM Format
    bd.setUint16(22, 1, Endian.little); // Mono
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, sampleRate * 2, Endian.little); // Byte rate
    bd.setUint16(32, 2, Endian.little); // Block align
    bd.setUint16(34, 16, Endian.little); // Bits per sample

    // data Chunk
    bd.setUint8(36, 0x64); // 'd'
    bd.setUint8(37, 0x61); // 'a'
    bd.setUint8(38, 0x74); // 't'
    bd.setUint8(39, 0x61); // 'a'
    bd.setUint32(40, dataSize, Endian.little);

    // Generate Audio Sine Wave Samples with Smooth Envelope
    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double progress = i / numSamples;
      final double currentFreq = isDoubleTone
          ? (progress < 0.5 ? freq1 : freq2)
          : (freq1 + (freq2 - freq1) * progress);

      // Smooth attack & exponential decay envelope
      final double envelope = progress < 0.1
          ? (progress / 0.1)
          : exp(-4.0 * (progress - 0.1));

      final double sampleVal = sin(2 * pi * currentFreq * t) * envelope;
      final int intSample = (sampleVal * 28000).clamp(-32768, 32767).toInt();
      bd.setInt16(44 + (i * 2), intSample, Endian.little);
    }

    return bytes;
  }

  static Future<void> _playSound(int soundType, {int? specificThemeId}) async {
    if (!isSoundEnabled()) return;
    try {
      final int themeId = specificThemeId ?? getSelectedThemeId();
      final double vol = getVolume();
      final Uint8List wavBytes = _generateWavBytes(soundType, themeId);
      
      await _player.setVolume(vol);
      await _player.play(BytesSource(wavBytes));
    } catch (_) {
      // Graceful fallback to SystemSound
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// Play POS barcode scan beep and light haptic feedback
  static Future<void> playScanBeep({int? themeId}) async {
    try {
      HapticFeedback.selectionClick();
      _playSound(0, specificThemeId: themeId);
      final hasVib = await Vibration.hasVibrator();
      if (hasVib == true) {
        Vibration.vibrate(duration: 40);
      }
    } catch (_) {}
  }

  /// Play cash register checkout ding / success sound
  static Future<void> playCheckoutSuccess({int? themeId}) async {
    try {
      HapticFeedback.heavyImpact();
      _playSound(1, specificThemeId: themeId);
      final hasVib = await Vibration.hasVibrator();
      if (hasVib == true) {
        Vibration.vibrate(pattern: [0, 50, 40, 80]);
      }
    } catch (_) {}
  }

  /// Play item removed or trash sound
  static Future<void> playDeleteSound({int? themeId}) async {
    try {
      HapticFeedback.mediumImpact();
      _playSound(2, specificThemeId: themeId);
      final hasVib = await Vibration.hasVibrator();
      if (hasVib == true) {
        Vibration.vibrate(duration: 65);
      }
    } catch (_) {}
  }

  static Future<void> playItemRemoved() => playDeleteSound();

  /// Play error / warning alert tone
  static Future<void> playWarningSound({int? themeId}) async {
    try {
      HapticFeedback.vibrate();
      _playSound(3, specificThemeId: themeId);
      final hasVib = await Vibration.hasVibrator();
      if (hasVib == true) {
        Vibration.vibrate(pattern: [0, 80, 50, 80]);
      }
    } catch (_) {}
  }
}
