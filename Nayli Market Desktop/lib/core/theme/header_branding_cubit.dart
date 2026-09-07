import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/hive_database.dart';

class HeaderThemePreset {
  final String id;
  final String nameAr;
  final String nameFr;
  final String nameEn;
  final Color headerColor;
  final Color accentColor;
  final Color logoContainerColor;

  const HeaderThemePreset({
    required this.id,
    required this.nameAr,
    required this.nameFr,
    required this.nameEn,
    required this.headerColor,
    required this.accentColor,
    required this.logoContainerColor,
  });
}

class HeaderBrandingState {
  final Color headerColor;
  final Color accentColor;
  final Color logoContainerColor;
  final String presetId;
  final bool isDarkHeader;

  const HeaderBrandingState({
    required this.headerColor,
    required this.accentColor,
    required this.logoContainerColor,
    required this.presetId,
    required this.isDarkHeader,
  });

  HeaderBrandingState copyWith({
    Color? headerColor,
    Color? accentColor,
    Color? logoContainerColor,
    String? presetId,
    bool? isDarkHeader,
  }) {
    final newHeader = headerColor ?? this.headerColor;
    return HeaderBrandingState(
      headerColor: newHeader,
      accentColor: accentColor ?? this.accentColor,
      logoContainerColor: logoContainerColor ?? this.logoContainerColor,
      presetId: presetId ?? this.presetId,
      isDarkHeader: isDarkHeader ?? (newHeader.computeLuminance() < 0.5),
    );
  }
}

class HeaderBrandingCubit extends Cubit<HeaderBrandingState> {
  static const String headerColorKey = 'pos_header_color_hex';
  static const String accentColorKey = 'pos_header_accent_hex';
  static const String presetKey = 'pos_header_preset_id';

  static const List<HeaderThemePreset> presets = [
    HeaderThemePreset(
      id: 'nayli_royal',
      nameAr: 'الأزرق الكحلي الملكي (نايلي)',
      nameFr: 'Bleu Royal Nayli',
      nameEn: 'Nayli Royal Navy',
      headerColor: Color(0xFF06325C),
      accentColor: Color(0xFFFF6600),
      logoContainerColor: Colors.white,
    ),
    HeaderThemePreset(
      id: 'emerald_market',
      nameAr: 'الأخضر الزمردي (سوبرماركت)',
      nameFr: 'Vert Émeraude Superette',
      nameEn: 'Emerald Market',
      headerColor: Color(0xFF065F46),
      accentColor: Color(0xFF34D399),
      logoContainerColor: Colors.white,
    ),
    HeaderThemePreset(
      id: 'modern_indigo',
      nameAr: 'البنفسجي العصري',
      nameFr: 'Indigo Moderne',
      nameEn: 'Modern Indigo',
      headerColor: Color(0xFF312E81),
      accentColor: Color(0xFF818CF8),
      logoContainerColor: Colors.white,
    ),
    HeaderThemePreset(
      id: 'ruby_crimson',
      nameAr: 'العنابي الراقي',
      nameFr: 'Pourpre Rubis',
      nameEn: 'Ruby Crimson',
      headerColor: Color(0xFF881337),
      accentColor: Color(0xFFFB7185),
      logoContainerColor: Colors.white,
    ),
    HeaderThemePreset(
      id: 'amber_gold',
      nameAr: 'الذهبي والعنبري',
      nameFr: 'Or Ambré',
      nameEn: 'Amber Gold',
      headerColor: Color(0xFF78350F),
      accentColor: Color(0xFFFBBF24),
      logoContainerColor: Colors.white,
    ),
    HeaderThemePreset(
      id: 'amoled_black',
      nameAr: 'الأسود الفاحم AMOLED',
      nameFr: 'Noir Pur AMOLED',
      nameEn: 'Pure Black AMOLED',
      headerColor: Color(0xFF000000),
      accentColor: Color(0xFF38BDF8),
      logoContainerColor: Color(0xFF111827),
    ),
    HeaderThemePreset(
      id: 'classic_white',
      nameAr: 'الأبيض الكلاسيكي الصافي',
      nameFr: 'Blanc Pur Classique',
      nameEn: 'Pure White Classic',
      headerColor: Color(0xFFFFFFFF),
      accentColor: Color(0xFF06325C),
      logoContainerColor: Color(0xFFF8FAFC),
    ),
  ];

  HeaderBrandingCubit() : super(_getInitialState());

  static HeaderBrandingState _getInitialState() {
    try {
      final savedPresetId = HiveDatabase.settingsBox.get(presetKey) as String?;
      final savedHeaderHex = HiveDatabase.settingsBox.get(headerColorKey) as int?;
      final savedAccentHex = HiveDatabase.settingsBox.get(accentColorKey) as int?;

      if (savedPresetId != null) {
        final found = presets.where((p) => p.id == savedPresetId);
        if (found.isNotEmpty) {
          final p = found.first;
          return HeaderBrandingState(
            headerColor: p.headerColor,
            accentColor: p.accentColor,
            logoContainerColor: p.logoContainerColor,
            presetId: p.id,
            isDarkHeader: p.headerColor.computeLuminance() < 0.5,
          );
        }
      }

      if (savedHeaderHex != null) {
        final hCol = Color(savedHeaderHex);
        final aCol = savedAccentHex != null ? Color(savedAccentHex) : const Color(0xFFFF6600);
        return HeaderBrandingState(
          headerColor: hCol,
          accentColor: aCol,
          logoContainerColor: Colors.white,
          presetId: 'custom',
          isDarkHeader: hCol.computeLuminance() < 0.5,
        );
      }
    } catch (_) {}

    // Default to Nayli Royal Navy (preset 0)
    final def = presets.first;
    return HeaderBrandingState(
      headerColor: def.headerColor,
      accentColor: def.accentColor,
      logoContainerColor: def.logoContainerColor,
      presetId: def.id,
      isDarkHeader: true,
    );
  }

  void selectPreset(String id) {
    final found = presets.where((p) => p.id == id);
    if (found.isEmpty) return;
    final p = found.first;
    HiveDatabase.settingsBox.put(presetKey, p.id);
    HiveDatabase.settingsBox.put(headerColorKey, p.headerColor.value);
    HiveDatabase.settingsBox.put(accentColorKey, p.accentColor.value);

    emit(HeaderBrandingState(
      headerColor: p.headerColor,
      accentColor: p.accentColor,
      logoContainerColor: p.logoContainerColor,
      presetId: p.id,
      isDarkHeader: p.headerColor.computeLuminance() < 0.5,
    ));
  }

  void setCustomColors({required Color headerColor, Color? accentColor}) {
    final aColor = accentColor ?? const Color(0xFFFF6600);
    HiveDatabase.settingsBox.put(presetKey, 'custom');
    HiveDatabase.settingsBox.put(headerColorKey, headerColor.value);
    HiveDatabase.settingsBox.put(accentColorKey, aColor.value);

    emit(HeaderBrandingState(
      headerColor: headerColor,
      accentColor: aColor,
      logoContainerColor: headerColor.computeLuminance() < 0.5 ? Colors.white : const Color(0xFFF1F5F9),
      presetId: 'custom',
      isDarkHeader: headerColor.computeLuminance() < 0.5,
    ));
  }
}
