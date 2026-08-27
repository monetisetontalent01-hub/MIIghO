import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage? _storage;
  final Map<String, String> _memoryStorage;

  SecureStorageService([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage(),
        _memoryStorage = {};

  SecureStorageService.inMemory()
      : _storage = null,
        _memoryStorage = {};

  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUserId = 'user_id';
  static const _keyPhone = 'phone';
  static const _keyThemeMode = 'theme_mode';
  static const _keyLocale = 'app_locale';

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    _memoryStorage[_keyAccessToken] = accessToken;
    _memoryStorage[_keyRefreshToken] = refreshToken;
    if (_storage != null) {
      try {
        await _storage.write(key: _keyAccessToken, value: accessToken);
        await _storage.write(key: _keyRefreshToken, value: refreshToken);
      } catch (_) {}
    }
  }

  Future<String?> getAccessToken() async {
    if (_memoryStorage.containsKey(_keyAccessToken)) {
      return _memoryStorage[_keyAccessToken];
    }
    if (_storage != null) {
      try {
        final val = await _storage.read(key: _keyAccessToken);
        if (val != null) _memoryStorage[_keyAccessToken] = val;
        return val;
      } catch (_) {}
    }
    return null;
  }

  Future<String?> getRefreshToken() async {
    if (_memoryStorage.containsKey(_keyRefreshToken)) {
      return _memoryStorage[_keyRefreshToken];
    }
    if (_storage != null) {
      try {
        final val = await _storage.read(key: _keyRefreshToken);
        if (val != null) _memoryStorage[_keyRefreshToken] = val;
        return val;
      } catch (_) {}
    }
    return null;
  }

  Future<void> saveUser(String id, String phone) async {
    _memoryStorage[_keyUserId] = id;
    _memoryStorage[_keyPhone] = phone;
    if (_storage != null) {
      try {
        await _storage.write(key: _keyUserId, value: id);
        await _storage.write(key: _keyPhone, value: phone);
      } catch (_) {}
    }
  }

  Future<String?> getUserId() async {
    if (_memoryStorage.containsKey(_keyUserId)) {
      return _memoryStorage[_keyUserId];
    }
    if (_storage != null) {
      try {
        final val = await _storage.read(key: _keyUserId);
        if (val != null) _memoryStorage[_keyUserId] = val;
        return val;
      } catch (_) {}
    }
    return null;
  }

  Future<String?> getPhone() async {
    if (_memoryStorage.containsKey(_keyPhone)) {
      return _memoryStorage[_keyPhone];
    }
    if (_storage != null) {
      try {
        final val = await _storage.read(key: _keyPhone);
        if (val != null) _memoryStorage[_keyPhone] = val;
        return val;
      } catch (_) {}
    }
    return null;
  }

  Future<void> saveThemeMode(String mode) async {
    _memoryStorage[_keyThemeMode] = mode;
    if (_storage != null) {
      try {
        await _storage.write(key: _keyThemeMode, value: mode);
      } catch (_) {}
    }
  }

  Future<String?> getThemeMode() async {
    if (_memoryStorage.containsKey(_keyThemeMode)) {
      return _memoryStorage[_keyThemeMode];
    }
    if (_storage != null) {
      try {
        return await _storage.read(key: _keyThemeMode);
      } catch (_) {}
    }
    return null;
  }

  Future<void> saveLocale(String localeCode) async {
    _memoryStorage[_keyLocale] = localeCode;
    if (_storage != null) {
      try {
        await _storage.write(key: _keyLocale, value: localeCode);
      } catch (_) {}
    }
  }

  Future<String?> getLocale() async {
    if (_memoryStorage.containsKey(_keyLocale)) {
      return _memoryStorage[_keyLocale];
    }
    if (_storage != null) {
      try {
        return await _storage.read(key: _keyLocale);
      } catch (_) {}
    }
    return null;
  }

  Future<void> clearTokens() async {
    _memoryStorage.remove(_keyAccessToken);
    _memoryStorage.remove(_keyRefreshToken);
    _memoryStorage.remove(_keyUserId);
    _memoryStorage.remove(_keyPhone);
    if (_storage != null) {
      try {
        await _storage.delete(key: _keyAccessToken);
        await _storage.delete(key: _keyRefreshToken);
        await _storage.delete(key: _keyUserId);
        await _storage.delete(key: _keyPhone);
      } catch (_) {}
    }
  }
}
