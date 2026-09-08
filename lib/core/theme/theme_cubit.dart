import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/hive_database.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  static const String themeKey = 'app_theme_mode';

  ThemeCubit() : super(ThemeMode.light);

  bool get isAmoledDark => false;

  void toggleTheme() {
    emit(ThemeMode.light);
  }

  void setTheme(ThemeMode mode) {
    emit(ThemeMode.light);
  }
}
