import 'package:flutter/material.dart';

/// Type de compte dans le système en partie double.
enum AccountType {
  asset,
  liability,
  revenue,
  expense,
  equity;

  static AccountType fromString(String val) {
    switch (val.toLowerCase()) {
      case 'liability':
        return AccountType.liability;
      case 'revenue':
        return AccountType.revenue;
      case 'expense':
        return AccountType.expense;
      case 'equity':
        return AccountType.equity;
      case 'asset':
      default:
        return AccountType.asset;
    }
  }

  String get label {
    switch (this) {
      case AccountType.asset:
        return 'Actif';
      case AccountType.liability:
        return 'Passif';
      case AccountType.revenue:
        return 'Produit';
      case AccountType.expense:
        return 'Charge';
      case AccountType.equity:
        return 'Capitaux Propres';
    }
  }
}

/// Type d'opération financière.
enum TransactionType {
  p2pTransfer,
  momoCashIn,
  momoCashOut,
  marketplaceEscrow,
  marketplaceRelease,
  fee;

  static TransactionType fromString(String val) {
    switch (val) {
      case 'p2p_transfer':
        return TransactionType.p2pTransfer;
      case 'momo_cash_in':
        return TransactionType.momoCashIn;
      case 'momo_cash_out':
        return TransactionType.momoCashOut;
      case 'marketplace_escrow':
        return TransactionType.marketplaceEscrow;
      case 'marketplace_release':
        return TransactionType.marketplaceRelease;
      case 'fee':
        return TransactionType.fee;
      default:
        return TransactionType.p2pTransfer;
    }
  }

  String get label {
    switch (this) {
      case TransactionType.p2pTransfer:
        return 'Transfert P2P';
      case TransactionType.momoCashIn:
        return 'Recharge Mobile Money';
      case TransactionType.momoCashOut:
        return 'Retrait Mobile Money';
      case TransactionType.marketplaceEscrow:
        return 'Séquestre Escrow';
      case TransactionType.marketplaceRelease:
        return 'Paiement Libéré';
      case TransactionType.fee:
        return 'Frais de Réseau';
    }
  }
}

/// Statut de l'écriture financière.
enum TransactionStatus {
  pending,
  posted,
  failed,
  cancelled,
  reversed;

  static TransactionStatus fromString(String val) {
    switch (val.toUpperCase()) {
      case 'PENDING':
        return TransactionStatus.pending;
      case 'POSTED':
        return TransactionStatus.posted;
      case 'FAILED':
        return TransactionStatus.failed;
      case 'CANCELLED':
        return TransactionStatus.cancelled;
      case 'REVERSED':
        return TransactionStatus.reversed;
      default:
        return TransactionStatus.posted;
    }
  }

  String get label {
    switch (this) {
      case TransactionStatus.pending:
        return 'EN ATTENTE';
      case TransactionStatus.posted:
        return 'COMPLÉTÉ (SANDBOX)';
      case TransactionStatus.failed:
        return 'ÉCHEC';
      case TransactionStatus.cancelled:
        return 'ANNULÉ';
      case TransactionStatus.reversed:
        return 'RÉVERSIBILISÉ';
    }
  }

  Color get color {
    switch (this) {
      case TransactionStatus.pending:
        return const Color(0xFFF59E0B);
      case TransactionStatus.posted:
        return const Color(0xFF10B981);
      case TransactionStatus.failed:
      case TransactionStatus.cancelled:
        return const Color(0xFFEF4444);
      case TransactionStatus.reversed:
        return const Color(0xFF8B5CF6);
    }
  }
}

/// Représente un compte dans le système en partie double.
class LedgerAccount {
  final String id;
  final String? userId;
  final String currency;
  final AccountType accountType;
  final String name;
  final DateTime createdAt;

  const LedgerAccount({
    required this.id,
    this.userId,
    required this.currency,
    required this.accountType,
    required this.name,
    required this.createdAt,
  });

  factory LedgerAccount.fromJson(Map<String, dynamic> json) {
    return LedgerAccount(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      currency: json['currency'] as String? ?? 'FCFA',
      accountType: AccountType.fromString(json['account_type'] as String? ?? 'asset'),
      name: json['name'] as String? ?? 'Compte',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }
}

/// Représente une transaction métier parente (JournalEntry).
class JournalEntry {
  final String id;
  final TransactionType transactionType;
  final String referenceId;
  final String description;
  final DateTime createdAt;

  const JournalEntry({
    required this.id,
    required this.transactionType,
    required this.referenceId,
    required this.description,
    required this.createdAt,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      transactionType: TransactionType.fromString(json['transaction_type'] as String? ?? 'p2p_transfer'),
      referenceId: json['reference_id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }
}

/// Écriture individuelle débit ou crédit.
class DetailedLedgerPosting {
  final String id;
  final String journalEntryId;
  final String accountId;
  final String accountName;
  final AccountType accountType;
  final int amount;
  final String currency;
  final bool isCredit;
  final String direction; // 'DEBIT' ou 'CREDIT'
  final DateTime createdAt;

  const DetailedLedgerPosting({
    required this.id,
    required this.journalEntryId,
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.amount,
    required this.currency,
    required this.isCredit,
    required this.direction,
    required this.createdAt,
  });

  factory DetailedLedgerPosting.fromJson(Map<String, dynamic> json) {
    return DetailedLedgerPosting(
      id: json['id'] as String,
      journalEntryId: json['journal_entry_id'] as String,
      accountId: json['account_id'] as String,
      accountName: json['account_name'] as String? ?? 'Compte',
      accountType: AccountType.fromString(json['account_type'] as String? ?? 'asset'),
      amount: (json['amount'] as num).toInt(),
      currency: json['currency'] as String? ?? 'FCFA',
      isCredit: json['is_credit'] as bool? ?? false,
      direction: json['direction'] as String? ?? (json['is_credit'] == true ? 'CREDIT' : 'DEBIT'),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }
}

/// Écriture complète avec postings et validation d'équilibre.
class DetailedJournalEntry {
  final JournalEntry entry;
  final TransactionStatus status;
  final List<DetailedLedgerPosting> postings;
  final int totalDebit;
  final int totalCredit;
  final bool isBalanced;

  const DetailedJournalEntry({
    required this.entry,
    required this.status,
    required this.postings,
    required this.totalDebit,
    required this.totalCredit,
    required this.isBalanced,
  });

  factory DetailedJournalEntry.fromJson(Map<String, dynamic> json) {
    final entryJson = json['entry'] as Map<String, dynamic>;
    final postingsJson = (json['postings'] as List<dynamic>?) ?? [];
    return DetailedJournalEntry(
      entry: JournalEntry.fromJson(entryJson),
      status: TransactionStatus.fromString(json['status'] as String? ?? 'POSTED'),
      postings: postingsJson.map((p) => DetailedLedgerPosting.fromJson(p as Map<String, dynamic>)).toList(),
      totalDebit: (json['total_debit'] as num?)?.toInt() ?? 0,
      totalCredit: (json['total_credit'] as num?)?.toInt() ?? 0,
      isBalanced: json['is_balanced'] as bool? ?? true,
    );
  }
}

/// Synthèse du portefeuille dérivée du Ledger.
class WalletSummary {
  final String accountId;
  final String userId;
  final String miighoId;
  final String currency;
  final int availableBalance;
  final int pendingBalance;
  final int totalIncoming;
  final int totalOutgoing;
  final bool isSandbox;
  final DateTime lastUpdated;

  const WalletSummary({
    required this.accountId,
    required this.userId,
    required this.miighoId,
    required this.currency,
    required this.availableBalance,
    required this.pendingBalance,
    required this.totalIncoming,
    required this.totalOutgoing,
    required this.isSandbox,
    required this.lastUpdated,
  });

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    return WalletSummary(
      accountId: json['account_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      miighoId: json['miigho_id'] as String? ?? 'MG-9824-CIV',
      currency: json['currency'] as String? ?? 'FCFA',
      availableBalance: (json['available_balance'] as num?)?.toInt() ?? 0,
      pendingBalance: (json['pending_balance'] as num?)?.toInt() ?? 0,
      totalIncoming: (json['total_incoming'] as num?)?.toInt() ?? 0,
      totalOutgoing: (json['total_outgoing'] as num?)?.toInt() ?? 0,
      isSandbox: json['is_sandbox'] as bool? ?? true,
      lastUpdated: json['last_updated'] != null ? DateTime.parse(json['last_updated'] as String) : DateTime.now(),
    );
  }
}

/// Transaction formatée pour la vue utilisateur standard.
class UserTransactionItem {
  final String id;
  final String journalEntryId;
  final String title;
  final String subtitle;
  final int amount;
  final String currency;
  final bool isCredit;
  final TransactionType type;
  final TransactionStatus status;
  final String referenceId;
  final DateTime createdAt;
  final String? counterparty;

  const UserTransactionItem({
    required this.id,
    required this.journalEntryId,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.currency,
    required this.isCredit,
    required this.type,
    required this.status,
    required this.referenceId,
    required this.createdAt,
    this.counterparty,
  });

  factory UserTransactionItem.fromJson(Map<String, dynamic> json) {
    return UserTransactionItem(
      id: json['id'] as String,
      journalEntryId: json['journal_entry_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Transaction',
      subtitle: json['subtitle'] as String? ?? '',
      amount: (json['amount'] as num).toInt(),
      currency: json['currency'] as String? ?? 'FCFA',
      isCredit: json['is_credit'] as bool? ?? false,
      type: TransactionType.fromString(json['type'] as String? ?? 'p2p_transfer'),
      status: TransactionStatus.fromString(json['status'] as String? ?? 'POSTED'),
      referenceId: json['reference_id'] as String? ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      counterparty: json['counterparty'] as String?,
    );
  }

  IconData get icon {
    switch (type) {
      case TransactionType.momoCashIn:
        return Icons.add_card_rounded;
      case TransactionType.momoCashOut:
        return Icons.account_balance_rounded;
      case TransactionType.p2pTransfer:
        return isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
      case TransactionType.marketplaceEscrow:
      case TransactionType.marketplaceRelease:
        return Icons.storefront_rounded;
      case TransactionType.fee:
        return Icons.receipt_long_rounded;
    }
  }

  Color get iconColor {
    if (type == TransactionType.marketplaceEscrow) {
      return const Color(0xFFF59E0B);
    }
    return isCredit ? const Color(0xFF10B981) : (type == TransactionType.momoCashOut ? const Color(0xFFEF4444) : const Color(0xFF7C3AED));
  }
}
