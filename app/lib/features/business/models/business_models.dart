/// Statut d'une entreprise MÏÏghO Business
enum BusinessStatus {
  pending,
  active,
  suspended,
  closed;

  static BusinessStatus fromString(String val) {
    switch (val.toUpperCase()) {
      case 'PENDING':
        return BusinessStatus.pending;
      case 'SUSPENDED':
        return BusinessStatus.suspended;
      case 'CLOSED':
        return BusinessStatus.closed;
      case 'ACTIVE':
      default:
        return BusinessStatus.active;
    }
  }

  String get label {
    switch (this) {
      case BusinessStatus.pending:
        return 'En attente';
      case BusinessStatus.active:
        return 'Actif';
      case BusinessStatus.suspended:
        return 'Suspendu';
      case BusinessStatus.closed:
        return 'Fermé';
    }
  }
}

/// Rôle d'un membre au sein de l'entreprise
enum MemberRole {
  owner,
  admin,
  manager,
  cashier;

  static MemberRole fromString(String val) {
    switch (val.toUpperCase()) {
      case 'OWNER':
        return MemberRole.owner;
      case 'ADMIN':
        return MemberRole.admin;
      case 'MANAGER':
        return MemberRole.manager;
      case 'CASHIER':
      default:
        return MemberRole.cashier;
    }
  }

  String get label {
    switch (this) {
      case MemberRole.owner:
        return 'Propriétaire';
      case MemberRole.admin:
        return 'Administrateur';
      case MemberRole.manager:
        return 'Gestionnaire';
      case MemberRole.cashier:
        return 'Caissier';
    }
  }
}

/// Modèle d'une entreprise MÏÏghO Business
class BusinessModel {
  final String id;
  final String ownerUserId;
  final String legalName;
  final String displayName;
  final String businessType;
  final BusinessStatus status;
  final String? phone;
  final String? email;
  final String country;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;

  BusinessModel({
    required this.id,
    required this.ownerUserId,
    required this.legalName,
    required this.displayName,
    required this.businessType,
    required this.status,
    this.phone,
    this.email,
    required this.country,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
      id: json['id'] ?? '',
      ownerUserId: json['owner_user_id'] ?? '',
      legalName: json['legal_name'] ?? '',
      displayName: json['display_name'] ?? '',
      businessType: json['business_type'] ?? 'RETAIL',
      status: BusinessStatus.fromString(json['status'] ?? 'ACTIVE'),
      phone: json['phone'],
      email: json['email'],
      country: json['country'] ?? 'CI',
      currency: json['currency'] ?? 'FCFA',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_user_id': ownerUserId,
    'legal_name': legalName,
    'display_name': displayName,
    'business_type': businessType,
    'status': status.name.toUpperCase(),
    'phone': phone,
    'email': email,
    'country': country,
    'currency': currency,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

/// Modèle d'un membre d'entreprise
class BusinessMemberModel {
  final String id;
  final String businessId;
  final String userId;
  final MemberRole role;
  final String status;
  final DateTime createdAt;
  final String? userDisplayName;
  final String? userMiighoId;

  BusinessMemberModel({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.role,
    required this.status,
    required this.createdAt,
    this.userDisplayName,
    this.userMiighoId,
  });

  factory BusinessMemberModel.fromJson(Map<String, dynamic> json) {
    return BusinessMemberModel(
      id: json['id'] ?? '',
      businessId: json['business_id'] ?? '',
      userId: json['user_id'] ?? '',
      role: MemberRole.fromString(json['role'] ?? 'CASHIER'),
      status: json['status'] ?? 'ACTIVE',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      userDisplayName: json['user_display_name'],
      userMiighoId: json['user_miigho_id'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'business_id': businessId,
    'user_id': userId,
    'role': role.name.toUpperCase(),
    'status': status,
    'created_at': createdAt.toIso8601String(),
  };
}

/// Modèle de compte financier d'une entreprise (lié au Ledger)
class BusinessAccountModel {
  final String id;
  final String businessId;
  final String ledgerAccountId;
  final String currency;
  final String status;
  final int availableBalance; // Dérivé du Ledger, non stocké

  BusinessAccountModel({
    required this.id,
    required this.businessId,
    required this.ledgerAccountId,
    required this.currency,
    required this.status,
    this.availableBalance = 0,
  });

  factory BusinessAccountModel.fromJson(Map<String, dynamic> json) {
    return BusinessAccountModel(
      id: json['id'] ?? '',
      businessId: json['business_id'] ?? '',
      ledgerAccountId: json['ledger_account_id'] ?? '',
      currency: json['currency'] ?? 'FCFA',
      status: json['status'] ?? 'ACTIVE',
      availableBalance: (json['available_balance'] as num?)?.toInt() ?? 0,
    );
  }
}
