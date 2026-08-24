import 'package:equatable/equatable.dart';

/// Contact model representing a phone book entry synchronized with MÏÏghO backend.
class Contact extends Equatable {
  final String id;
  final String? userId;
  final String displayName;
  final String phoneNumber;
  final String? avatarUrl;
  final String? bio;
  final bool isMiighoUser;
  final bool isFavorite;
  final bool isBlocked;
  final bool isOnline;
  final DateTime? lastSeen;

  const Contact({
    required this.id,
    this.userId,
    required this.displayName,
    required this.phoneNumber,
    this.avatarUrl,
    this.bio,
    this.isMiighoUser = false,
    this.isFavorite = false,
    this.isBlocked = false,
    this.isOnline = false,
    this.lastSeen,
  });

  /// Factory from JSON map (from MÏÏghO backend API)
  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as String? ?? json['user_id'] as String? ?? '',
      userId: json['user_id'] as String?,
      displayName: json['display_name'] as String? ?? json['name'] as String? ?? 'Inconnu',
      phoneNumber: json['phone_number'] as String? ?? json['phone'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      isMiighoUser: json['is_miigho_user'] as bool? ?? (json['user_id'] != null),
      isFavorite: json['is_favorite'] as bool? ?? false,
      isBlocked: json['is_blocked'] as bool? ?? false,
      isOnline: json['is_online'] as bool? ?? false,
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'] as String)
          : null,
    );
  }

  /// Convert Contact to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'display_name': displayName,
      'phone_number': phoneNumber,
      'avatar_url': avatarUrl,
      'bio': bio,
      'is_miigho_user': isMiighoUser,
      'is_favorite': isFavorite,
      'is_blocked': isBlocked,
      'is_online': isOnline,
      'last_seen': lastSeen?.toIso8601String(),
    };
  }

  /// Create a copy of Contact with updated fields
  Contact copyWith({
    String? id,
    String? userId,
    String? displayName,
    String? phoneNumber,
    String? avatarUrl,
    String? bio,
    bool? isMiighoUser,
    bool? isFavorite,
    bool? isBlocked,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return Contact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      isMiighoUser: isMiighoUser ?? this.isMiighoUser,
      isFavorite: isFavorite ?? this.isFavorite,
      isBlocked: isBlocked ?? this.isBlocked,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        displayName,
        phoneNumber,
        avatarUrl,
        bio,
        isMiighoUser,
        isFavorite,
        isBlocked,
        isOnline,
        lastSeen,
      ];
}
