import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final String userId;

  AuthResponse({required this.accessToken, required this.refreshToken, required this.userId});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
      userId: json['user_id'],
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
      'device_id': deviceId,
    });
    
    final authData = AuthResponse.fromJson(response.data);
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
