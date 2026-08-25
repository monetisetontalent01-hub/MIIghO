/// PSP Gateway Models — Phase 3A.6
/// MÏÏghO PSP Gateway Abstraction & Sandbox Provider
/// 100% Sandbox — Zero Real PSP Connection
library;

/// Normalized PSP status values, independent of any provider-specific vocabulary.
enum PSPStatus {
  pending,
  processing,
  succeeded,
  failed,
  cancelled,
  expired,
  unknown;

  static PSPStatus fromString(String val) {
    switch (val.toUpperCase()) {
      case 'PENDING':
        return PSPStatus.pending;
      case 'PROCESSING':
        return PSPStatus.processing;
      case 'SUCCEEDED':
        return PSPStatus.succeeded;
      case 'FAILED':
        return PSPStatus.failed;
      case 'CANCELLED':
        return PSPStatus.cancelled;
      case 'EXPIRED':
        return PSPStatus.expired;
      default:
        return PSPStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case PSPStatus.pending:
        return 'En attente';
      case PSPStatus.processing:
        return 'En cours';
      case PSPStatus.succeeded:
        return 'Réussi';
      case PSPStatus.failed:
        return 'Échoué';
      case PSPStatus.cancelled:
        return 'Annulé';
      case PSPStatus.expired:
        return 'Expiré';
      case PSPStatus.unknown:
        return 'Inconnu';
    }
  }
}

/// Represents a PSP transaction record for audit and correlation.
class PSPTransactionModel {
  final String id;
  final String provider;
  final String operationType;
  final String internalReference;
  final String pspTransactionId;
  final String? paymentIntentId;
  final String? refundId;
  final String? settlementId;
  final int amount;
  final String currency;
  final PSPStatus status;
  final String? idempotencyKey;
  final String? requestReference;
  final String? responseReference;
  final String? failureCode;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final bool isSandbox;

  const PSPTransactionModel({
    required this.id,
    required this.provider,
    required this.operationType,
    required this.internalReference,
    required this.pspTransactionId,
    this.paymentIntentId,
    this.refundId,
    this.settlementId,
    required this.amount,
    required this.currency,
    required this.status,
    this.idempotencyKey,
    this.requestReference,
    this.responseReference,
    this.failureCode,
    this.failureReason,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.isSandbox = true,
  });

  factory PSPTransactionModel.fromJson(Map<String, dynamic> json) {
    return PSPTransactionModel(
      id: json['id'] as String,
      provider: json['provider'] as String,
      operationType: json['operation_type'] as String,
      internalReference: json['internal_reference'] as String,
      pspTransactionId: json['psp_transaction_id'] as String,
      paymentIntentId: json['payment_intent_id'] as String?,
      refundId: json['refund_id'] as String?,
      settlementId: json['settlement_id'] as String?,
      amount: json['amount'] as int,
      currency: json['currency'] as String,
      status: PSPStatus.fromString(json['status'] as String),
      idempotencyKey: json['idempotency_key'] as String?,
      requestReference: json['request_reference'] as String?,
      responseReference: json['response_reference'] as String?,
      failureCode: json['failure_code'] as String?,
      failureReason: json['failure_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      isSandbox: true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': provider,
        'operation_type': operationType,
        'internal_reference': internalReference,
        'psp_transaction_id': pspTransactionId,
        'payment_intent_id': paymentIntentId,
        'refund_id': refundId,
        'settlement_id': settlementId,
        'amount': amount,
        'currency': currency,
        'status': status.name.toUpperCase(),
        'idempotency_key': idempotencyKey,
        'request_reference': requestReference,
        'response_reference': responseReference,
        'failure_code': failureCode,
        'failure_reason': failureReason,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'is_sandbox': isSandbox,
      };
}

/// Represents a PSP webhook event for de-duplication and audit.
class PSPWebhookRecordModel {
  final String id;
  final String provider;
  final String eventId;
  final String eventType;
  final String payload;
  final String status;
  final DateTime receivedAt;
  final DateTime? processedAt;
  final String? errorMessage;
  final bool isSandbox;

  const PSPWebhookRecordModel({
    required this.id,
    required this.provider,
    required this.eventId,
    required this.eventType,
    required this.payload,
    required this.status,
    required this.receivedAt,
    this.processedAt,
    this.errorMessage,
    this.isSandbox = true,
  });

  factory PSPWebhookRecordModel.fromJson(Map<String, dynamic> json) {
    return PSPWebhookRecordModel(
      id: json['id'] as String,
      provider: json['provider'] as String,
      eventId: json['event_id'] as String,
      eventType: json['event_type'] as String,
      payload: json['payload'] as String,
      status: json['status'] as String,
      receivedAt: DateTime.parse(json['received_at'] as String),
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'] as String)
          : null,
      errorMessage: json['error_message'] as String?,
      isSandbox: true,
    );
  }
}
