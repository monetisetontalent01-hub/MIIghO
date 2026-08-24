import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUserId = 'user_id';
  static const _keyPhone = 'phone';
  static const _keyThemeMode = 'theme_mode';
  static const _keyLocale = 'app_locale';

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  Future<String?> getAccessToken() => _storage.read(key: _keyAccessToken);
  Future<String?> getRefreshToken() => _storage.read(key: _keyRefreshToken);

  Future<void> saveUser(String id, String phone) async {
    await _storage.write(key: _keyUserId, value: id);
    await _storage.write(key: _keyPhone, value: phone);
  }

  Future<String?> getUserId() => _storage.read(key: _keyUserId);
  Future<String?> getPhone() => _storage.read(key: _keyPhone);

  Future<void> saveThemeMode(String mode) async {
    await _storage.write(key: _keyThemeMode, value: mode);
  }

  Future<String?> getThemeMode() => _storage.read(key: _keyThemeMode);

  Future<void> saveLocale(String localeCode) async {
    await _storage.write(key: _keyLocale, value: localeCode);
  }

  Future<String?> getLocale() => _storage.read(key: _keyLocale);

  Future<void> clearTokens() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyPhone);
  }
}
