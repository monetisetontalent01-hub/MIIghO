import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../storage/secure_storage.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  final SecureStorageService _storage;

  ThemeCubit(this._storage) : super(ThemeMode.dark) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final savedMode = await _storage.getThemeMode();
      if (savedMode != null) {
        switch (savedMode) {
          case 'light':
            emit(ThemeMode.light);
            break;
          case 'dark':
            emit(ThemeMode.dark);
            break;
          case 'system':
            emit(ThemeMode.system);
            break;
        }
      }
    } catch (_) {}
  }

  Future<void> setTheme(ThemeMode mode) async {
    emit(mode);
    String modeString = 'dark';
    if (mode == ThemeMode.light) modeString = 'light';
    if (mode == ThemeMode.system) modeString = 'system';
    try {
      await _storage.saveThemeMode(modeString);
    } catch (_) {}
  }

  void toggleTheme() {
    if (state == ThemeMode.dark) {
      setTheme(ThemeMode.light);
    } else {
      setTheme(ThemeMode.dark);
    }
  }
}
