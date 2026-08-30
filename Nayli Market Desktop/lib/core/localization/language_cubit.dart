import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/hive_database.dart';

class LanguageCubit extends Cubit<Locale> {
  static const String languageKey = 'app_language';

  LanguageCubit() : super(_getInitialLocale());

  static Locale _getInitialLocale() {
    try {
      final savedLang = HiveDatabase.settingsBox.get(languageKey) as String?;
      if (savedLang != null && ['ar', 'fr', 'en'].contains(savedLang)) {
        return Locale(savedLang);
      }
    } catch (_) {}
    return const Locale('ar'); // Default to Arabic
  }

  void setLanguage(String languageCode) {
    if (!['ar', 'fr', 'en'].contains(languageCode)) return;
    HiveDatabase.settingsBox.put(languageKey, languageCode);
    emit(Locale(languageCode));
  }
}
