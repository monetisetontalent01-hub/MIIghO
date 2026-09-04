import 'package:equatable/equatable.dart';

/// Contact model representing a phone book entry synchronized with MÏÏghO backend.
class Contact extends Equatable {
  final String id;
  final String? userId;
  final String displayName;
  final String phoneNumber;
  final String? avatarUrl;
  final String? bio;
  final String? miighoId;
  final String relationshipStatus; // 'none', 'pending_sent', 'pending_received', 'accepted', 'rejected'
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
    this.miighoId,
    this.relationshipStatus = 'none',
    this.isMiighoUser = false,
    this.isFavorite = false,
    this.isBlocked = false,
    this.isOnline = false,
    this.lastSeen,
  });

  bool get isRegistered => isMiighoUser;
  String? get statusMessage => bio;

  bool get isMutualContact => relationshipStatus == 'accepted';
  bool get isPendingSent => relationshipStatus == 'pending_sent';
  bool get isPendingReceived => relationshipStatus == 'pending_received';

  /// Factory from JSON map (from MÏÏghO backend API)
  factory Contact.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] as String? ?? json['user_id'] as String? ?? '';
    final phone = json['phone_number'] as String? ?? json['phone'] as String? ?? '';
    final rawName = json['display_name'] as String? ?? json['name'] as String? ?? '';
    final mId = json['miigho_id'] as String?;
    final relStatus = json['relationship_status'] as String? ?? 'none';

    return Contact(
      id: rawId,
      userId: json['user_id'] as String? ?? rawId,
      // STRICT IDENTITY: Never use phone number as displayName
      displayName: rawName.isNotEmpty ? rawName : 'Utilisateur MÏÏghO',
      phoneNumber: phone,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['status_message'] as String? ?? json['bio'] as String?,
      miighoId: mId,
      relationshipStatus: relStatus,
      isMiighoUser: json['is_miigho_user'] as bool? ?? (rawId.isNotEmpty),
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
      'miigho_id': miighoId,
      'relationship_status': relationshipStatus,
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
    String? miighoId,
    String? relationshipStatus,
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
      miighoId: miighoId ?? this.miighoId,
      relationshipStatus: relationshipStatus ?? this.relationshipStatus,
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
        miighoId,
        relationshipStatus,
        isMiighoUser,
        isFavorite,
        isBlocked,
        isOnline,
        lastSeen,
      ];
}

/// Model representing a mutual contact authorization request.
class ContactRequest extends Equatable {
  final String id;
  final String senderId;
  final String recipientId;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime createdAt;
  final String senderName;
  final String recipientName;
  final String? senderAvatar;

  const ContactRequest({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.status,
    required this.createdAt,
    required this.senderName,
    required this.recipientName,
    this.senderAvatar,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';

  factory ContactRequest.fromJson(Map<String, dynamic> json) {
    final rawSenderName = json['sender_name'] as String? ?? '';
    final rawRecipientName = json['recipient_name'] as String? ?? '';

    return ContactRequest(
      id: json['id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      recipientId: json['recipient_id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      senderName: rawSenderName.isNotEmpty ? rawSenderName : 'Utilisateur MÏÏghO',
      recipientName: rawRecipientName.isNotEmpty ? rawRecipientName : 'Utilisateur MÏÏghO',
      senderAvatar: json['sender_avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'recipient_id': recipientId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'sender_name': senderName,
      'recipient_name': recipientName,
      'sender_avatar': senderAvatar,
    };
  }

  @override
  List<Object?> get props => [
        id,
        senderId,
        recipientId,
        status,
        createdAt,
        senderName,
        recipientName,
        senderAvatar,
      ];
}
