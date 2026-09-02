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
    SoundThemeItem(id: 11, name: 'نظام كوسكو السريع (Costco Wholesale)', icon: '🛒', description: 'الصوت الأيقوني لمتاجر كوسكو الأمريكية الفائقة السرعة'),
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
    try {
      return HiveDatabase.settingsBox.get(_soundKey, defaultValue: true) as bool;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setSoundEnabled(bool enabled) async {
    await HiveDatabase.settingsBox.put(_soundKey, enabled);
  }

  static int getSelectedThemeId() {
    try {
      return HiveDatabase.settingsBox.get(_soundThemeKey, defaultValue: 11) as int;
    } catch (_) {
      return 11;
    }
  }

  static Future<void> setSelectedThemeId(int themeId) async {
    await HiveDatabase.settingsBox.put(_soundThemeKey, themeId);
  }

  static double getVolume() {
    try {
      return (HiveDatabase.settingsBox.get(_volumeKey, defaultValue: 1.0) as num).toDouble();
    } catch (_) {
      return 1.0;
    }
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
    bool isTripleTone = false;
    double freq3 = 2000.0;

    // Specific Sound Types:
    // 0 = Scan, 1 = Checkout Success, 2 = Delete/Void, 3 = Warning, 4 = Restock, 5 = Print, 6 = Save, 7 = Tick, 8 = MemberScan, 9 = ScaleSettled, 10 = SupervisorOverride, 11 = TpeApproved, 12 = DrawerKick, 13 = BobAlert

    if (soundType == 8) {
      // Member Card Scan (Ascending VIP Chime)
      freq1 = 880; // A5
      freq2 = 1320; // E6
      durationMs = 90;
      isDoubleTone = true;
    } else if (soundType == 9) {
      // Scale Settled (Harmonic C5 -> E5)
      freq1 = 523.25; // C5
      freq2 = 659.25; // E5
      durationMs = 80;
      isDoubleTone = true;
    } else if (soundType == 10) {
      // Supervisor Override (3-Tone Executive Chime)
      freq1 = 880.0;   // A5
      freq2 = 1108.73; // C#6
      freq3 = 1318.51; // E6
      durationMs = 140;
      isTripleTone = true;
    } else if (soundType == 11) {
      // TPE / CIB Payment Approved (Celebration Double Bell)
      freq1 = 1046.50; // C6
      freq2 = 1567.98; // G6
      durationMs = 150;
      isDoubleTone = true;
    } else if (soundType == 12) {
      // Mechanical Drawer Kick Solenoid
      freq1 = 180;
      freq2 = 80;
      durationMs = 70;
    } else if (soundType == 13) {
      // Bottom of Basket (BOB) Alert
      freq1 = 750;
      freq2 = 1000;
      durationMs = 90;
      isDoubleTone = true;
    } else {
      // Standard Themes (1..11)
      switch (themeId) {
        case 11: // Costco Wholesale Fast Acoustic System
          freq1 = 1000; // Iconic 1kHz Costco square/pure pip
          freq2 = 1000;
          durationMs = 35;
          break;
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
          freq1 = 1000;
          durationMs = 35;
      }

      // Adjust for Action Types
      if (soundType == 1) {
        // Checkout Success
        freq1 = freq1 * 0.8;
        freq2 = freq1 * 1.5;
        durationMs = max(durationMs, 140);
        isDoubleTone = true;
      } else if (soundType == 2) {
        // Delete / Void Item (Loss prevention harsh drop)
        freq1 = 400;
        freq2 = 200;
        durationMs = 100;
      } else if (soundType == 3) {
        // Warning
        freq1 = 450;
        freq2 = 350;
        durationMs = 160;
        isDoubleTone = true;
      } else if (soundType == 4) {
        // Restock / Arrivage
        freq1 = 1200;
        freq2 = 1800;
        durationMs = 100;
        isDoubleTone = true;
      } else if (soundType == 5) {
        // Thermal Print Start
        freq1 = 2800;
        freq2 = 3200;
        durationMs = 70;
        isDoubleTone = true;
      } else if (soundType == 6) {
        // Save Success
        freq1 = 2400;
        durationMs = 50;
      } else if (soundType == 7) {
        // Light Tab / Button Tick
        freq1 = 1800;
        durationMs = 25;
      }
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
      
      double currentFreq;
      if (isTripleTone) {
        if (progress < 0.33) {
          currentFreq = freq1;
        } else if (progress < 0.66) {
          currentFreq = freq2;
        } else {
          currentFreq = freq3;
        }
      } else if (isDoubleTone) {
        currentFreq = (progress < 0.5 ? freq1 : freq2);
      } else {
        currentFreq = (freq1 + (freq2 - freq1) * progress);
      }

      // Smooth attack & exponential decay envelope
      final double envelope = progress < 0.08
          ? (progress / 0.08)
          : exp(-4.5 * (progress - 0.08));

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
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  /// Play POS barcode scan beep (Default: Costco fast 1kHz pip)
  static Future<void> playScanBeep({int? themeId}) async {
    try {
      HapticFeedback.selectionClick();
      _playSound(0, specificThemeId: themeId);
      final hasVib = await Vibration.hasVibrator();
      if (hasVib == true) {
        Vibration.vibrate(duration: 35);
      }
    } catch (_) {}
  }

  static Future<void> playBarcodeBeep({int? themeId}) => playScanBeep(themeId: themeId);

  /// Play Costco Member / VIP card recognized chime
  static Future<void> playMemberCardScan() async {
    try {
      HapticFeedback.mediumImpact();
      _playSound(8);
    } catch (_) {}
  }

  /// Play electronic scale weight stabilization sound
  static Future<void> playScaleSettled() async {
    try {
      HapticFeedback.selectionClick();
      _playSound(9);
    } catch (_) {}
  }

  /// Play supervisor override approval chime
  static Future<void> playSupervisorOverride() async {
    try {
      HapticFeedback.heavyImpact();
      _playSound(10);
    } catch (_) {}
  }

  /// Play electronic payment (TPE / CIB / BaridiPay) approved sound
  static Future<void> playTpeApproved() async {
    try {
      HapticFeedback.heavyImpact();
      _playSound(11);
      final hasVib = await Vibration.hasVibrator();
      if (hasVib == true) {
        Vibration.vibrate(pattern: [0, 50, 40, 80]);
      }
    } catch (_) {}
  }

  /// Play cash drawer open mechanical sound
  static Future<void> playDrawerKick() async {
    try {
      HapticFeedback.mediumImpact();
      _playSound(12);
    } catch (_) {}
  }

  /// Play Bottom-of-Basket (BOB) bulk scan reminder
  static Future<void> playBobAlert() async {
    try {
      HapticFeedback.selectionClick();
      _playSound(13);
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

  /// Play item removed or void alert (Costco Loss Prevention Warning)
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
  static Future<void> playVoidWarning() => playDeleteSound();
  static Future<void> playWarning({int? themeId}) => playWarningSound(themeId: themeId);

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

  /// Play restock arrivage positive sound
  static Future<void> playRestockSound() async {
    try {
      HapticFeedback.mediumImpact();
      _playSound(4);
      final hasVib = await Vibration.hasVibrator();
      if (hasVib == true) {
        Vibration.vibrate(pattern: [0, 40, 30, 60]);
      }
    } catch (_) {}
  }

  /// Play thermal print start sound
  static Future<void> playPrintSound() async {
    try {
      HapticFeedback.selectionClick();
      _playSound(5);
    } catch (_) {}
  }

  /// Play save confirmation sound
  static Future<void> playSaveSuccess() async {
    try {
      HapticFeedback.mediumImpact();
      _playSound(6);
      final hasVib = await Vibration.hasVibrator();
      if (hasVib == true) {
        Vibration.vibrate(duration: 45);
      }
    } catch (_) {}
  }

  /// Play light tick on tab / navigation
  static Future<void> playTabSwitch() async {
    try {
      HapticFeedback.selectionClick();
      _playSound(7);
    } catch (_) {}
  }

  /// Play click sound
  static Future<void> playClick() => playTabSwitch();

  /// Play key / button tap sound
  static Future<void> playKeyTap() => playTabSwitch();
}

