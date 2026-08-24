import 'package:flutter/material.dart';
import '../../../../core/config/demo_data.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';

class UserSession {
  final String id;
  final String deviceName;
  final String platform;
  final String ipAddress;
  final DateTime lastActive;
  final bool isCurrent;

  const UserSession({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.ipAddress,
    required this.lastActive,
    required this.isCurrent,
  });
}

class UserProfile {
  final String id;
  final String miighoId;
  final String displayName;
  final String phoneNumber;
  final String email;
  final String bio;
  final String? avatarUrl;
  final String country;
  final String kycLevel;
  final bool isVerified;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.miighoId,
    required this.displayName,
    required this.phoneNumber,
    required this.email,
    required this.bio,
    this.avatarUrl,
    required this.country,
    required this.kycLevel,
    required this.isVerified,
    required this.createdAt,
  });

  UserProfile copyWith({
    String? displayName,
    String? email,
    String? bio,
    String? avatarUrl,
    String? country,
  }) {
    return UserProfile(
      id: id,
      miighoId: miighoId,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      country: country ?? this.country,
      kycLevel: kycLevel,
      isVerified: isVerified,
      createdAt: createdAt,
    );
  }
}

class IdentityRepository {
  final ApiClient apiClient;
  final SecureStorageService secureStorage;

  UserProfile _cachedProfile = UserProfile(
    id: DemoDataProvider.currentUser.id,
    miighoId: DemoDataProvider.currentUser.miighoId,
    displayName: DemoDataProvider.currentUser.displayName,
    phoneNumber: DemoDataProvider.currentUser.phoneNumber,
    email: DemoDataProvider.currentUser.email,
    bio: 'Pionnier MÏÏghO • Construisons l\'écosystème numérique africain.',
    country: DemoDataProvider.currentUser.country,
    kycLevel: DemoDataProvider.currentUser.kycLevel,
    isVerified: DemoDataProvider.currentUser.isVerified,
    createdAt: DateTime(2026, 1, 15),
  );

  final List<UserSession> _sessions = [
    UserSession(
      id: 'sess_01',
      deviceName: 'iPhone 15 Pro (Cet appareil)',
      platform: 'iOS • MÏÏghO Mobile',
      ipAddress: '197.234.221.14 (Abidjan, CI)',
      lastActive: DateTime.now(),
      isCurrent: true,
    ),
    UserSession(
      id: 'sess_02',
      deviceName: 'MacBook Pro M3 Max',
      platform: 'macOS • MÏÏghO Web / Desktop',
      ipAddress: '197.234.221.14 (Abidjan, CI)',
      lastActive: DateTime.now().subtract(const Duration(hours: 2)),
      isCurrent: false,
    ),
  ];

  IdentityRepository({
    required this.apiClient,
    required this.secureStorage,
  });

  Future<UserProfile> getProfile() async {
    try {
      final response = await apiClient.get('/user/profile');
      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] != null) {
        final d = data['data'] as Map<String, dynamic>;
        _cachedProfile = UserProfile(
          id: d['id'] as String? ?? _cachedProfile.id,
          miighoId: d['miigho_id'] as String? ?? _cachedProfile.miighoId,
          displayName: '${d['first_name'] ?? ''} ${d['last_name'] ?? ''}'.trim(),
          phoneNumber: d['phone_number'] as String? ?? _cachedProfile.phoneNumber,
          email: d['email'] as String? ?? _cachedProfile.email,
          bio: d['status_message'] as String? ?? _cachedProfile.bio,
          avatarUrl: d['avatar_url'] as String?,
          country: _cachedProfile.country,
          kycLevel: _cachedProfile.kycLevel,
          isVerified: _cachedProfile.isVerified,
          createdAt: _cachedProfile.createdAt,
        );
      }
      return _cachedProfile;
    } catch (_) {
      return _cachedProfile;
    }
  }

  Future<UserProfile> updateProfile({
    required String displayName,
    required String email,
    required String bio,
    String? avatarUrl,
  }) async {
    try {
      final parts = displayName.split(' ');
      final firstName = parts.first;
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      await apiClient.put('/user/profile', data: {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'status_message': bio,
        'avatar_url': avatarUrl,
      });
    } catch (_) {}

    _cachedProfile = _cachedProfile.copyWith(
      displayName: displayName,
      email: email,
      bio: bio,
      avatarUrl: avatarUrl,
    );
    return _cachedProfile;
  }

  Future<List<UserSession>> getSessions() async {
    return List.unmodifiable(_sessions);
  }

  Future<void> revokeSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId && !s.isCurrent);
  }
}
