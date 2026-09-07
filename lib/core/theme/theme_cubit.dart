import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/hive_database.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  static const String themeKey = 'app_theme_mode';

  ThemeCubit() : super(_getInitialTheme());

  static ThemeMode _getInitialTheme() {
    try {
      final saved = HiveDatabase.settingsBox.get(themeKey) as String?;
      if (saved == 'dark') return ThemeMode.dark;
      if (saved == 'light') return ThemeMode.light;
    } catch (_) {}
    return ThemeMode.light;
  }

  bool get isAmoledDark => state == ThemeMode.dark;

  void toggleTheme() {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    HiveDatabase.settingsBox.put(themeKey, next == ThemeMode.dark ? 'dark' : 'light');
    emit(next);
  }

  void setTheme(ThemeMode mode) {
    HiveDatabase.settingsBox.put(themeKey, mode == ThemeMode.dark ? 'dark' : 'light');
    emit(mode);
  }
}
