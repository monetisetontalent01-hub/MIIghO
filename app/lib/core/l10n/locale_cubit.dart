import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../storage/secure_storage.dart';

class LocaleCubit extends Cubit<Locale> {
  final SecureStorageService _storage;

  static const supportedLocales = [
    Locale('fr', ''), // Français
    Locale('en', ''), // English
    Locale('sw', ''), // Kiswahili
    Locale('ar', ''), // العربية (RTL)
  ];

  LocaleCubit(this._storage) : super(const Locale('fr', '')) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final savedCode = await _storage.getLocale();
      if (savedCode != null) {
        final match = supportedLocales.firstWhere(
          (loc) => loc.languageCode == savedCode,
          orElse: () => const Locale('fr', ''),
        );
        emit(match);
      }
    } catch (_) {}
  }

  Future<void> setLocale(Locale locale) async {
    emit(locale);
    try {
      await _storage.saveLocale(locale.languageCode);
    } catch (_) {}
  }

  bool get isRTL => state.languageCode == 'ar';
}
