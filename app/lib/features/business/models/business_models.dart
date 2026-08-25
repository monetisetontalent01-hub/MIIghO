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

/// Modèle d'un QR Marchand MÏÏghO
class MerchantQrModel {
  final String id;
  final String businessId;
  final String code;
  final String status; // ACTIVE, DISABLED, REVOKED
  final DateTime createdAt;
  final DateTime updatedAt;

  MerchantQrModel({
    required this.id,
    required this.businessId,
    required this.code,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MerchantQrModel.fromJson(Map<String, dynamic> json) {
    return MerchantQrModel(
      id: json['id'] ?? '',
      businessId: json['business_id'] ?? '',
      code: json['code'] ?? '',
      status: json['status'] ?? 'ACTIVE',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'business_id': businessId,
    'code': code,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  bool get isActive => status == 'ACTIVE';
}

/// Information publique issue de la résolution d'un QR Code Marchand
class PublicMerchantInfoModel {
  final String businessId;
  final String displayName;
  final String businessType;
  final String country;
  final String currency;
  final String status;
  final String qrCode;

  PublicMerchantInfoModel({
    required this.businessId,
    required this.displayName,
    required this.businessType,
    required this.country,
    required this.currency,
    required this.status,
    required this.qrCode,
  });

  factory PublicMerchantInfoModel.fromJson(Map<String, dynamic> json) {
    return PublicMerchantInfoModel(
      businessId: json['business_id'] ?? '',
      displayName: json['display_name'] ?? '',
      businessType: json['business_type'] ?? '',
      country: json['country'] ?? '',
      currency: json['currency'] ?? 'FCFA',
      status: json['status'] ?? 'ACTIVE',
      qrCode: json['qr_code'] ?? '',
    );
  }
}

/// Modèle d'intention de paiement Marchand (Payment Intent)
class PaymentIntentModel {
  final String id;
  final String businessId;
  final String payerUserId;
  final String? merchantQrId;
  final int amount;
  final String currency;
  final String status; // CREATED, CONFIRMED, SUCCEEDED, FAILED, CANCELLED, EXPIRED
  final String? idempotencyKey;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? confirmedAt;
  final String? journalEntryId;

  PaymentIntentModel({
    required this.id,
    required this.businessId,
    required this.payerUserId,
    this.merchantQrId,
    required this.amount,
    required this.currency,
    required this.status,
    this.idempotencyKey,
    required this.createdAt,
    required this.expiresAt,
    this.confirmedAt,
    this.journalEntryId,
  });

  factory PaymentIntentModel.fromJson(Map<String, dynamic> json) {
    return PaymentIntentModel(
      id: json['id'] ?? '',
      businessId: json['business_id'] ?? '',
      payerUserId: json['payer_user_id'] ?? '',
      merchantQrId: json['merchant_qr_id'],
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] ?? 'FCFA',
      status: json['status'] ?? 'CREATED',
      idempotencyKey: json['idempotency_key'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at']) : DateTime.now(),
      confirmedAt: json['confirmed_at'] != null ? DateTime.parse(json['confirmed_at']) : null,
      journalEntryId: json['journal_entry_id'],
    );
  }

  bool get isSucceeded => status == 'SUCCEEDED';
  bool get isFailed => status == 'FAILED';
  bool get isExpired => status == 'EXPIRED';
}

/// Modèle de reçu de paiement Marchand
class MerchantPaymentReceiptModel {
  final String paymentIntentId;
  final String businessId;
  final String businessName;
  final String payerUserId;
  final int amount;
  final String currency;
  final String status;
  final String? journalEntryId;
  final DateTime confirmedAt;
  final bool isSandbox;

  MerchantPaymentReceiptModel({
    required this.paymentIntentId,
    required this.businessId,
    required this.businessName,
    required this.payerUserId,
    required this.amount,
    required this.currency,
    required this.status,
    this.journalEntryId,
    required this.confirmedAt,
    this.isSandbox = true,
  });

  factory MerchantPaymentReceiptModel.fromJson(Map<String, dynamic> json) {
    return MerchantPaymentReceiptModel(
      paymentIntentId: json['payment_intent_id'] ?? '',
      businessId: json['business_id'] ?? '',
      businessName: json['business_name'] ?? '',
      payerUserId: json['payer_user_id'] ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] ?? 'FCFA',
      status: json['status'] ?? 'SUCCEEDED',
      journalEntryId: json['journal_entry_id'],
      confirmedAt: json['confirmed_at'] != null ? DateTime.parse(json['confirmed_at']) : DateTime.now(),
      isSandbox: json['is_sandbox'] ?? true,
    );
  }
}

/// Modèle d'un remboursement marchand MÏÏghO
class RefundModel {
  final String id;
  final String paymentIntentId;
  final String businessId;
  final String payerUserId;
  final int amount;
  final String currency;
  final String status; // REQUESTED, SUCCEEDED, FAILED, CANCELLED
  final String? reason;
  final String? idempotencyKey;
  final String? journalEntryId;
  final DateTime createdAt;
  final DateTime? completedAt;

  RefundModel({
    required this.id,
    required this.paymentIntentId,
    required this.businessId,
    required this.payerUserId,
    required this.amount,
    required this.currency,
    required this.status,
    this.reason,
    this.idempotencyKey,
    this.journalEntryId,
    required this.createdAt,
    this.completedAt,
  });

  factory RefundModel.fromJson(Map<String, dynamic> json) {
    return RefundModel(
      id: json['id'] ?? '',
      paymentIntentId: json['payment_intent_id'] ?? '',
      businessId: json['business_id'] ?? '',
      payerUserId: json['payer_user_id'] ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] ?? 'FCFA',
      status: json['status'] ?? 'REQUESTED',
      reason: json['reason'],
      idempotencyKey: json['idempotency_key'],
      journalEntryId: json['journal_entry_id'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
    );
  }

  bool get isSucceeded => status == 'SUCCEEDED';
}

/// Modèle de reçu de remboursement marchand (Audit-proof)
class RefundReceiptModel {
  final String refundId;
  final String paymentIntentId;
  final String businessId;
  final String businessName;
  final String payerUserId;
  final int originalAmount;
  final int refundAmount;
  final int totalRefunded;
  final int remainingRefundable;
  final String currency;
  final String status;
  final String? reason;
  final String? journalEntryId;
  final DateTime createdAt;
  final DateTime completedAt;
  final bool isSandbox;

  RefundReceiptModel({
    required this.refundId,
    required this.paymentIntentId,
    required this.businessId,
    required this.businessName,
    required this.payerUserId,
    required this.originalAmount,
    required this.refundAmount,
    required this.totalRefunded,
    required this.remainingRefundable,
    required this.currency,
    required this.status,
    this.reason,
    this.journalEntryId,
    required this.createdAt,
    required this.completedAt,
    this.isSandbox = true,
  });

  factory RefundReceiptModel.fromJson(Map<String, dynamic> json) {
    return RefundReceiptModel(
      refundId: json['refund_id'] ?? '',
      paymentIntentId: json['payment_intent_id'] ?? '',
      businessId: json['business_id'] ?? '',
      businessName: json['business_name'] ?? '',
      payerUserId: json['payer_user_id'] ?? '',
      originalAmount: (json['original_amount'] as num?)?.toInt() ?? 0,
      refundAmount: (json['refund_amount'] as num?)?.toInt() ?? 0,
      totalRefunded: (json['total_refunded'] as num?)?.toInt() ?? 0,
      remainingRefundable: (json['remaining_refundable'] as num?)?.toInt() ?? 0,
      currency: json['currency'] ?? 'FCFA',
      status: json['status'] ?? 'SUCCEEDED',
      reason: json['reason'],
      journalEntryId: json['journal_entry_id'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : DateTime.now(),
      isSandbox: json['is_sandbox'] ?? true,
    );
  }
}

/// Modèle d'un Règlement Marchand (Settlement - Phase 3A.4)
class SettlementModel {
  final String id;
  final String businessId;
  final int totalAmount;
  final String currency;
  final String status; // PENDING, PROCESSING, SUCCEEDED, FAILED, CANCELLED
  final String? idempotencyKey;
  final String? journalEntryId;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime? processedAt;

  SettlementModel({
    required this.id,
    required this.businessId,
    required this.totalAmount,
    required this.currency,
    required this.status,
    this.idempotencyKey,
    this.journalEntryId,
    this.failureReason,
    required this.createdAt,
    this.processedAt,
  });

  factory SettlementModel.fromJson(Map<String, dynamic> json) {
    return SettlementModel(
      id: json['id'] ?? '',
      businessId: json['business_id'] ?? '',
      totalAmount: (json['total_amount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] ?? 'FCFA',
      status: json['status'] ?? 'PENDING',
      idempotencyKey: json['idempotency_key'],
      journalEntryId: json['journal_entry_id'],
      failureReason: json['failure_reason'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      processedAt: json['processed_at'] != null ? DateTime.parse(json['processed_at']) : null,
    );
  }

  bool get isSucceeded => status == 'SUCCEEDED';
  bool get isPending => status == 'PENDING';
  bool get isProcessing => status == 'PROCESSING';
}

/// Modèle d'un élément composant un lot de Settlement
class SettlementItemModel {
  final String id;
  final String settlementId;
  final String paymentIntentId;
  final int grossAmount;
  final int refundAmount;
  final int netAmount;
  final String currency;
  final DateTime createdAt;

  SettlementItemModel({
    required this.id,
    required this.settlementId,
    required this.paymentIntentId,
    required this.grossAmount,
    required this.refundAmount,
    required this.netAmount,
    required this.currency,
    required this.createdAt,
  });

  factory SettlementItemModel.fromJson(Map<String, dynamic> json) {
    return SettlementItemModel(
      id: json['id'] ?? '',
      settlementId: json['settlement_id'] ?? '',
      paymentIntentId: json['payment_intent_id'] ?? '',
      grossAmount: (json['gross_amount'] as num?)?.toInt() ?? 0,
      refundAmount: (json['refund_amount'] as num?)?.toInt() ?? 0,
      netAmount: (json['net_amount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] ?? 'FCFA',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }
}

/// Modèle du reçu de Règlement Marchand émis
class SettlementReceiptModel {
  final String settlementId;
  final String businessId;
  final String businessName;
  final int totalAmount;
  final String currency;
  final String status;
  final String? idempotencyKey;
  final String? journalEntryId;
  final String? failureReason;
  final List<SettlementItemModel> items;
  final int itemCount;
  final DateTime createdAt;
  final DateTime? processedAt;
  final bool isSandbox;

  SettlementReceiptModel({
    required this.settlementId,
    required this.businessId,
    required this.businessName,
    required this.totalAmount,
    required this.currency,
    required this.status,
    this.idempotencyKey,
    this.journalEntryId,
    this.failureReason,
    required this.items,
    required this.itemCount,
    required this.createdAt,
    this.processedAt,
    this.isSandbox = true,
  });

  factory SettlementReceiptModel.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List<dynamic>? ?? [];
    List<SettlementItemModel> parsedItems = rawItems
        .map((i) => SettlementItemModel.fromJson(i as Map<String, dynamic>))
        .toList();

    return SettlementReceiptModel(
      settlementId: json['settlement_id'] ?? '',
      businessId: json['business_id'] ?? '',
      businessName: json['business_name'] ?? '',
      totalAmount: (json['total_amount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] ?? 'FCFA',
      status: json['status'] ?? 'PENDING',
      idempotencyKey: json['idempotency_key'],
      journalEntryId: json['journal_entry_id'],
      failureReason: json['failure_reason'],
      items: parsedItems,
      itemCount: (json['item_count'] as num?)?.toInt() ?? parsedItems.length,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      processedAt: json['processed_at'] != null ? DateTime.parse(json['processed_at']) : null,
      isSandbox: json['is_sandbox'] ?? true,
    );
  }
}



