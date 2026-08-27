import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final String userId;

  AuthResponse({required this.accessToken, required this.refreshToken, required this.userId});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // Backend returns: {access_token, refresh_token, expires_at, user: {id, phone_number, ...}}
    final user = json['user'];
    final userId = user is Map<String, dynamic> ? (user['id'] ?? '').toString() : '';
    return AuthResponse(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
      userId: userId,
    );
  }
}

class AuthRepository {
  final ApiClient apiClient;
  final SecureStorageService secureStorage;

  AuthRepository(this.apiClient, this.secureStorage);

  Future<void> sendOTP(String phone) async {
    await apiClient.post('/auth/otp/send', data: {'phone_number': phone});
  }

  Future<AuthResponse> verifyOTP(String phone, String code, String deviceId) async {
    final response = await apiClient.post('/auth/otp/verify', data: {
      'phone_number': phone,
      'code': code,
      'device_info': deviceId,
    });
    
    // Backend wraps response: {"success": true, "data": {...auth fields...}}
    final raw = response.data;
    final innerData = (raw is Map<String, dynamic> && raw.containsKey('data'))
        ? raw['data'] as Map<String, dynamic>
        : raw as Map<String, dynamic>;
    
    final authData = AuthResponse.fromJson(innerData);
    await secureStorage.saveTokens(
      accessToken: authData.accessToken,
      refreshToken: authData.refreshToken,
    );
    await secureStorage.saveUser(authData.userId, phone);
    
    return authData;
  }
  
  Future<String?> getAccessToken() => secureStorage.getAccessToken();

  Future<void> logout() async {
    await secureStorage.clearTokens();
  }
}

