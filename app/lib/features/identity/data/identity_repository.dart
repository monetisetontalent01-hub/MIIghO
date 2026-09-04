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
    id: '',
    miighoId: '@miigho',
    displayName: 'Nom à définir',
    phoneNumber: '',
    email: '',
    bio: '',
    country: 'Afrique 🌍',
    kycLevel: 'Niveau 1 (Actif)',
    isVerified: true,
    createdAt: DateTime.now(),
  );

  final List<UserSession> _sessions = [];

  IdentityRepository({
    required this.apiClient,
    required this.secureStorage,
  });

  Future<UserProfile> getProfile() async {
    final storedPhone = await secureStorage.getPhone() ?? '';
    final storedUserId = await secureStorage.getUserId() ?? '';

    try {
      final response = await apiClient.get('/users/me');
      final data = response.data;
      if (data is Map<String, dynamic> && data['data'] != null) {
        final d = data['data'] as Map<String, dynamic>;
        final firstName = d['first_name'] as String? ?? '';
        final lastName = d['last_name'] as String? ?? '';
        final fullName = '$firstName $lastName'.trim();
        final phone = d['phone_number'] as String? ?? storedPhone;
        final id = d['id'] as String? ?? storedUserId;

        // Display Name: Real user name, or explicit placeholder
        final displayName = fullName.isNotEmpty ? fullName : 'Nom à définir';

        // MÏÏghO ID: Canonical backend value if present, otherwise derived from UUID (@MG-XXXXXXXX)
        final rawMiighoId = (d['miigho_id'] as String?)?.trim() ?? '';
        final miighoId = rawMiighoId.isNotEmpty
            ? (rawMiighoId.startsWith('@') ? rawMiighoId : '@$rawMiighoId')
            : (id.isNotEmpty
                ? '@MG-${id.substring(0, id.length >= 8 ? 8 : id.length).toUpperCase()}'
                : '@miigho');

        _cachedProfile = UserProfile(
          id: id,
          miighoId: miighoId,
          displayName: displayName,
          phoneNumber: phone,
          email: d['email'] as String? ?? '',
          bio: d['status_message'] as String? ?? '',
          avatarUrl: (d['avatar_url'] as String?)?.isNotEmpty == true ? d['avatar_url'] as String : null,
          country: phone.startsWith('+243')
              ? 'RD Congo 🇨🇩'
              : (phone.startsWith('+225') ? 'Côte d\'Ivoire 🇨🇮' : 'Afrique 🌍'),
          kycLevel: 'Niveau 1 (Actif)',
          isVerified: true,
          createdAt: d['created_at'] != null
              ? DateTime.tryParse(d['created_at'].toString()) ?? DateTime.now()
              : DateTime.now(),
        );
      }
      return _cachedProfile;
    } catch (_) {
      if (storedPhone.isNotEmpty || storedUserId.isNotEmpty) {
        final miighoId = storedUserId.isNotEmpty
            ? '@MG-${storedUserId.substring(0, storedUserId.length >= 8 ? 8 : storedUserId.length).toUpperCase()}'
            : '@miigho';

        _cachedProfile = UserProfile(
          id: storedUserId,
          miighoId: miighoId,
          displayName: 'Nom à définir',
          phoneNumber: storedPhone,
          email: '',
          bio: '',
          country: storedPhone.startsWith('+243')
              ? 'RD Congo 🇨🇩'
              : (storedPhone.startsWith('+225') ? 'Côte d\'Ivoire 🇨🇮' : 'Afrique 🌍'),
          kycLevel: 'Niveau 1 (Actif)',
          isVerified: true,
          createdAt: DateTime.now(),
        );
      }
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
      await apiClient.put('/users/me', data: {
        'first_name': firstName,
        'last_name': lastName,
        'status_message': bio,
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
    if (_sessions.isEmpty) {
      _sessions.add(
        UserSession(
          id: 'sess_current',
          deviceName: 'Navigateur Web (Cet appareil)',
          platform: 'Web • MÏÏghO Staging',
          ipAddress: 'Session active',
          lastActive: DateTime.now(),
          isCurrent: true,
        ),
      );
    }
    return List.unmodifiable(_sessions);
  }

  Future<void> revokeSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId && !s.isCurrent);
  }
}
