import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../../../core/network/api_client.dart';
import '../models/pay_models.dart';

class PayRepository {
  final ApiClient apiClient;
  final _uuid = const Uuid();

  // In-memory Sandbox Ledger fallback state for standalone offline / preview mode
  WalletSummary _sandboxWallet = WalletSummary(
    accountId: 'acc-9824-01',
    userId: 'usr_demo_01',
    miighoId: 'MG-9824-CIV',
    currency: 'FCFA',
    availableBalance: 45000,
    pendingBalance: 0,
    totalIncoming: 1245000,
    totalOutgoing: 850000,
    isSandbox: true,
    lastUpdated: DateTime.now(),
  );

  final List<UserTransactionItem> _sandboxTransactions = [];
  final List<DetailedJournalEntry> _sandboxJournal = [];
  final Map<String, DetailedJournalEntry> _idempotencyCache = {};

  PayRepository({required this.apiClient}) {
    _seedSandboxData();
  }

  void _seedSandboxData() {
    final now = DateTime.now();

    // 1. Recharge Wave CI (+25,000 FCFA)
    final entry1 = JournalEntry(
      id: 'entry-01',
      transactionType: TransactionType.momoCashIn,
      referenceId: 'WAVE-CI-982401',
      description: 'Recharge Wave CI (Sandbox)',
      createdAt: now.subtract(const Duration(hours: 3)),
    );
    final p1 = [
      DetailedLedgerPosting(
        id: 'post-01-dr',
        journalEntryId: entry1.id,
        accountId: 'acc-9824-01',
        accountName: 'Portefeuille Principal (Mamadou Koné)',
        accountType: AccountType.asset,
        amount: 25000,
        currency: 'FCFA',
        isCredit: false,
        direction: 'DEBIT',
        createdAt: entry1.createdAt,
      ),
      DetailedLedgerPosting(
        id: 'post-01-cr',
        journalEntryId: entry1.id,
        accountId: 'sys-momo-pool',
        accountName: 'MoMo Settlement Pool',
        accountType: AccountType.liability,
        amount: 25000,
        currency: 'FCFA',
        isCredit: true,
        direction: 'CREDIT',
        createdAt: entry1.createdAt,
      ),
    ];
    final d1 = DetailedJournalEntry(
      entry: entry1,
      status: TransactionStatus.posted,
      postings: p1,
      totalDebit: 25000,
      totalCredit: 25000,
      isBalanced: true,
    );

    // 2. Transfert reçu de Amina Diallo (+30,000 FCFA)
    final entry2 = JournalEntry(
      id: 'entry-02',
      transactionType: TransactionType.p2pTransfer,
      referenceId: 'P2P-AMINA-982402',
      description: 'Transfert reçu de Amina Diallo',
      createdAt: now.subtract(const Duration(days: 1)),
    );
    final p2 = [
      DetailedLedgerPosting(
        id: 'post-02-dr',
        journalEntryId: entry2.id,
        accountId: 'acc-9824-01',
        accountName: 'Portefeuille Principal (Mamadou Koné)',
        accountType: AccountType.asset,
        amount: 30000,
        currency: 'FCFA',
        isCredit: false,
        direction: 'DEBIT',
        createdAt: entry2.createdAt,
      ),
      DetailedLedgerPosting(
        id: 'post-02-cr',
        journalEntryId: entry2.id,
        accountId: 'acc-amina-01',
        accountName: 'Compte Amina Diallo',
        accountType: AccountType.asset,
        amount: 30000,
        currency: 'FCFA',
        isCredit: true,
        direction: 'CREDIT',
        createdAt: entry2.createdAt,
      ),
    ];
    final d2 = DetailedJournalEntry(
      entry: entry2,
      status: TransactionStatus.posted,
      postings: p2,
      totalDebit: 30000,
      totalCredit: 30000,
      isBalanced: true,
    );

    // 3. Commande Market Escrow (-10,000 FCFA)
    final entry3 = JournalEntry(
      id: 'entry-03',
      transactionType: TransactionType.marketplaceEscrow,
      referenceId: 'MKT-ESCROW-982403',
      description: 'Commande Market (Escrow) - Boutique Artisanat Sahel',
      createdAt: now.subtract(const Duration(days: 2)),
    );
    final p3 = [
      DetailedLedgerPosting(
        id: 'post-03-cr',
        journalEntryId: entry3.id,
        accountId: 'acc-9824-01',
        accountName: 'Portefeuille Principal (Mamadou Koné)',
        accountType: AccountType.asset,
        amount: 10000,
        currency: 'FCFA',
        isCredit: true,
        direction: 'CREDIT',
        createdAt: entry3.createdAt,
      ),
      DetailedLedgerPosting(
        id: 'post-03-dr',
        journalEntryId: entry3.id,
        accountId: 'sys-escrow-pool',
        accountName: 'Marketplace Escrow Account',
        accountType: AccountType.liability,
        amount: 10000,
        currency: 'FCFA',
        isCredit: false,
        direction: 'DEBIT',
        createdAt: entry3.createdAt,
      ),
    ];
    final d3 = DetailedJournalEntry(
      entry: entry3,
      status: TransactionStatus.posted,
      postings: p3,
      totalDebit: 10000,
      totalCredit: 10000,
      isBalanced: true,
    );

    _sandboxJournal.addAll([d1, d2, d3]);

    _sandboxTransactions.addAll([
      UserTransactionItem(
        id: 'tx-01',
        journalEntryId: entry1.id,
        title: entry1.description,
        subtitle: 'Mobile Money • Sandbox',
        amount: 25000,
        currency: 'FCFA',
        isCredit: true,
        type: TransactionType.momoCashIn,
        status: TransactionStatus.posted,
        referenceId: entry1.referenceId,
        createdAt: entry1.createdAt,
        counterparty: 'Wave CI',
      ),
      UserTransactionItem(
        id: 'tx-02',
        journalEntryId: entry2.id,
        title: entry2.description,
        subtitle: 'MÏÏghO Pay P2P • Sandbox',
        amount: 30000,
        currency: 'FCFA',
        isCredit: true,
        type: TransactionType.p2pTransfer,
        status: TransactionStatus.posted,
        referenceId: entry2.referenceId,
        createdAt: entry2.createdAt,
        counterparty: 'Amina Diallo',
      ),
      UserTransactionItem(
        id: 'tx-03',
        journalEntryId: entry3.id,
        title: entry3.description,
        subtitle: 'Boutique Artisanat Sahel • Séquestre Garanti',
        amount: 10000,
        currency: 'FCFA',
        isCredit: false,
        type: TransactionType.marketplaceEscrow,
        status: TransactionStatus.posted,
        referenceId: entry3.referenceId,
        createdAt: entry3.createdAt,
        counterparty: 'Boutique Artisanat Sahel',
      ),
    ]);

    _recalculateSandboxBalance();
  }

  void _recalculateSandboxBalance() {
    int balance = 0;
    for (final tx in _sandboxTransactions) {
      if (tx.isCredit) {
        balance += tx.amount;
      } else {
        balance -= tx.amount;
      }
    }
    _sandboxWallet = WalletSummary(
      accountId: _sandboxWallet.accountId,
      userId: _sandboxWallet.userId,
      miighoId: _sandboxWallet.miighoId,
      currency: _sandboxWallet.currency,
      availableBalance: balance,
      pendingBalance: _sandboxWallet.pendingBalance,
      totalIncoming: _sandboxWallet.totalIncoming,
      totalOutgoing: _sandboxWallet.totalOutgoing,
      isSandbox: true,
      lastUpdated: DateTime.now(),
    );
  }

  Future<WalletSummary> getWallet({String currency = 'FCFA'}) async {
    try {
      final res = await apiClient.get('/api/v1/pay/wallet', queryParameters: {'currency': currency});
      if (res.statusCode == 200 && res.data['success'] == true) {
        return WalletSummary.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {
      // Fallback sandbox
    }
    return _sandboxWallet;
  }

  Future<List<UserTransactionItem>> getTransactions({String currency = 'FCFA', int limit = 20, int offset = 0}) async {
    try {
      final res = await apiClient.get('/api/v1/pay/transactions', queryParameters: {
        'currency': currency,
        'limit': limit,
        'offset': offset,
      });
      if (res.statusCode == 200 && res.data['success'] == true) {
        final list = res.data['data'] as List<dynamic>;
        return list.map((item) => UserTransactionItem.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      // Fallback sandbox
    }
    return List.from(_sandboxTransactions);
  }

  Future<DetailedJournalEntry> getTransactionDetail(String entryId) async {
    try {
      final res = await apiClient.get('/api/v1/pay/transactions/$entryId');
      if (res.statusCode == 200 && res.data['success'] == true) {
        return DetailedJournalEntry.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {
      // Fallback
    }

    final entry = _sandboxJournal.firstWhere(
      (j) => j.entry.id == entryId,
      orElse: () => _sandboxJournal.first,
    );
    return entry;
  }

  Future<List<DetailedJournalEntry>> getJournal({int limit = 50, int offset = 0}) async {
    try {
      final res = await apiClient.get('/api/v1/pay/journal', queryParameters: {
        'limit': limit,
        'offset': offset,
      });
      if (res.statusCode == 200 && res.data['success'] == true) {
        final list = res.data['data'] as List<dynamic>;
        return list.map((item) => DetailedJournalEntry.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      // Fallback
    }
    return List.from(_sandboxJournal);
  }

  Future<DetailedJournalEntry> sendMoneyP2P({
    required String toContact,
    required int amount,
    required String currency,
    String? description,
    required String idempotencyKey,
  }) async {
    if (amount <= 0) {
      throw Exception('Le montant doit être supérieur à zéro.');
    }

    // Check idempotency
    if (_idempotencyCache.containsKey(idempotencyKey)) {
      return _idempotencyCache[idempotencyKey]!;
    }

    try {
      final res = await apiClient.post('/api/v1/pay/transfer', data: {
        'to_miigho_id': toContact,
        'amount': amount,
        'currency': currency,
        'description': description ?? 'Transfert P2P vers $toContact',
        'idempotency_key': idempotencyKey,
      });
      if (res.statusCode == 201 && res.data['success'] == true) {
        return DetailedJournalEntry.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (e) {
      // Check for insufficient funds
      if (_sandboxWallet.availableBalance < amount) {
        throw Exception('Solde insuffisant pour effectuer ce transfert (${_sandboxWallet.availableBalance} $currency disponible).');
      }
    }

    // Local Sandbox Ledger execution
    final entryId = _uuid.v4();
    final now = DateTime.now();
    final entry = JournalEntry(
      id: entryId,
      transactionType: TransactionType.p2pTransfer,
      referenceId: idempotencyKey,
      description: description ?? 'Transfert P2P vers $toContact',
      createdAt: now,
    );

    final postings = [
      DetailedLedgerPosting(
        id: _uuid.v4(),
        journalEntryId: entryId,
        accountId: _sandboxWallet.accountId,
        accountName: 'Portefeuille Principal (Mamadou Koné)',
        accountType: AccountType.asset,
        amount: amount,
        currency: currency,
        isCredit: true, // Credit sender (reduces asset)
        direction: 'CREDIT',
        createdAt: now,
      ),
      DetailedLedgerPosting(
        id: _uuid.v4(),
        journalEntryId: entryId,
        accountId: 'acc-dest-$toContact',
        accountName: 'Bénéficiaire $toContact',
        accountType: AccountType.asset,
        amount: amount,
        currency: currency,
        isCredit: false, // Debit receiver (increases asset)
        direction: 'DEBIT',
        createdAt: now,
      ),
    ];

    final detailed = DetailedJournalEntry(
      entry: entry,
      status: TransactionStatus.posted,
      postings: postings,
      totalDebit: amount,
      totalCredit: amount,
      isBalanced: true,
    );

    _sandboxJournal.insert(0, detailed);
    _sandboxTransactions.insert(
      0,
      UserTransactionItem(
        id: _uuid.v4(),
        journalEntryId: entryId,
        title: entry.description,
        subtitle: 'MÏÏghO Pay P2P • Envoyé',
        amount: amount,
        currency: currency,
        isCredit: false,
        type: TransactionType.p2pTransfer,
        status: TransactionStatus.posted,
        referenceId: idempotencyKey,
        createdAt: now,
        counterparty: toContact,
      ),
    );

    _idempotencyCache[idempotencyKey] = detailed;
    _recalculateSandboxBalance();
    return detailed;
  }

  Future<DetailedJournalEntry> cashIn({
    required String provider,
    required String phoneNumber,
    required int amount,
    required String currency,
    required String idempotencyKey,
  }) async {
    if (amount <= 0) {
      throw Exception('Le montant doit être supérieur à zéro.');
    }

    if (_idempotencyCache.containsKey(idempotencyKey)) {
      return _idempotencyCache[idempotencyKey]!;
    }

    try {
      final res = await apiClient.post('/api/v1/pay/cash-in', data: {
        'provider': provider,
        'phone_number': phoneNumber,
        'amount': amount,
        'currency': currency,
        'idempotency_key': idempotencyKey,
      });
      if (res.statusCode == 201 && res.data['success'] == true) {
        return DetailedJournalEntry.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {
      // Local fallback
    }

    final entryId = _uuid.v4();
    final now = DateTime.now();
    final providerUpper = provider.toUpperCase().replaceAll('_', ' ');

    final entry = JournalEntry(
      id: entryId,
      transactionType: TransactionType.momoCashIn,
      referenceId: idempotencyKey,
      description: 'Recharge $providerUpper ($phoneNumber)',
      createdAt: now,
    );

    final postings = [
      DetailedLedgerPosting(
        id: _uuid.v4(),
        journalEntryId: entryId,
        accountId: _sandboxWallet.accountId,
        accountName: 'Portefeuille Principal (Mamadou Koné)',
        accountType: AccountType.asset,
        amount: amount,
        currency: currency,
        isCredit: false, // Debit user (increases asset)
        direction: 'DEBIT',
        createdAt: now,
      ),
      DetailedLedgerPosting(
        id: _uuid.v4(),
        journalEntryId: entryId,
        accountId: 'sys-momo-pool',
        accountName: 'MoMo Settlement Pool ($providerUpper)',
        accountType: AccountType.liability,
        amount: amount,
        currency: currency,
        isCredit: true, // Credit momo pool (increases liability)
        direction: 'CREDIT',
        createdAt: now,
      ),
    ];

    final detailed = DetailedJournalEntry(
      entry: entry,
      status: TransactionStatus.posted,
      postings: postings,
      totalDebit: amount,
      totalCredit: amount,
      isBalanced: true,
    );

    _sandboxJournal.insert(0, detailed);
    _sandboxTransactions.insert(
      0,
      UserTransactionItem(
        id: _uuid.v4(),
        journalEntryId: entryId,
        title: entry.description,
        subtitle: 'Mobile Money • Recharge Sandbox',
        amount: amount,
        currency: currency,
        isCredit: true,
        type: TransactionType.momoCashIn,
        status: TransactionStatus.posted,
        referenceId: idempotencyKey,
        createdAt: now,
        counterparty: providerUpper,
      ),
    );

    _idempotencyCache[idempotencyKey] = detailed;
    _recalculateSandboxBalance();
    return detailed;
  }

  Future<DetailedJournalEntry> cashOut({
    required String provider,
    required String phoneNumber,
    required int amount,
    required String currency,
    required String idempotencyKey,
  }) async {
    if (amount <= 0) {
      throw Exception('Le montant doit être supérieur à zéro.');
    }

    if (_sandboxWallet.availableBalance < amount) {
      throw Exception('Solde insuffisant pour ce retrait (${_sandboxWallet.availableBalance} $currency disponible).');
    }

    if (_idempotencyCache.containsKey(idempotencyKey)) {
      return _idempotencyCache[idempotencyKey]!;
    }

    try {
      final res = await apiClient.post('/api/v1/pay/cash-out', data: {
        'provider': provider,
        'phone_number': phoneNumber,
        'amount': amount,
        'currency': currency,
        'idempotency_key': idempotencyKey,
      });
      if (res.statusCode == 201 && res.data['success'] == true) {
        return DetailedJournalEntry.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {
      // Local fallback
    }

    final entryId = _uuid.v4();
    final now = DateTime.now();
    final providerUpper = provider.toUpperCase().replaceAll('_', ' ');

    final entry = JournalEntry(
      id: entryId,
      transactionType: TransactionType.momoCashOut,
      referenceId: idempotencyKey,
      description: 'Retrait vers $providerUpper ($phoneNumber)',
      createdAt: now,
    );

    final postings = [
      DetailedLedgerPosting(
        id: _uuid.v4(),
        journalEntryId: entryId,
        accountId: _sandboxWallet.accountId,
        accountName: 'Portefeuille Principal (Mamadou Koné)',
        accountType: AccountType.asset,
        amount: amount,
        currency: currency,
        isCredit: true, // Credit user (reduces asset)
        direction: 'CREDIT',
        createdAt: now,
      ),
      DetailedLedgerPosting(
        id: _uuid.v4(),
        journalEntryId: entryId,
        accountId: 'sys-momo-pool',
        accountName: 'MoMo Settlement Pool ($providerUpper)',
        accountType: AccountType.liability,
        amount: amount,
        currency: currency,
        isCredit: false, // Debit momo pool (reduces liability)
        direction: 'DEBIT',
        createdAt: now,
      ),
    ];

    final detailed = DetailedJournalEntry(
      entry: entry,
      status: TransactionStatus.posted,
      postings: postings,
      totalDebit: amount,
      totalCredit: amount,
      isBalanced: true,
    );

    _sandboxJournal.insert(0, detailed);
    _sandboxTransactions.insert(
      0,
      UserTransactionItem(
        id: _uuid.v4(),
        journalEntryId: entryId,
        title: entry.description,
        subtitle: 'Mobile Money • Retrait Sandbox',
        amount: amount,
        currency: currency,
        isCredit: false,
        type: TransactionType.momoCashOut,
        status: TransactionStatus.posted,
        referenceId: idempotencyKey,
        createdAt: now,
        counterparty: providerUpper,
      ),
    );

    _idempotencyCache[idempotencyKey] = detailed;
    _recalculateSandboxBalance();
    return detailed;
  }

  Future<DetailedJournalEntry> payQR({
    required String qrData,
    required int amount,
    required String currency,
    String? description,
    required String idempotencyKey,
  }) async {
    if (amount <= 0) {
      throw Exception('Le montant doit être supérieur à zéro.');
    }

    if (_sandboxWallet.availableBalance < amount) {
      throw Exception('Solde insuffisant pour ce paiement QR (${_sandboxWallet.availableBalance} $currency disponible).');
    }

    if (_idempotencyCache.containsKey(idempotencyKey)) {
      return _idempotencyCache[idempotencyKey]!;
    }

    try {
      final res = await apiClient.post('/api/v1/pay/qr-pay', data: {
        'qr_data': qrData,
        'amount': amount,
        'currency': currency,
        'description': description ?? 'Paiement QR Code',
        'idempotency_key': idempotencyKey,
      });
      if (res.statusCode == 201 && res.data['success'] == true) {
        return DetailedJournalEntry.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {
      // Local fallback
    }

    final entryId = _uuid.v4();
    final now = DateTime.now();

    String merchantName = 'Commerçant MÏÏghO';
    if (qrData.contains('to=')) {
      final parts = qrData.split('to=');
      if (parts.length > 1) {
        merchantName = parts[1].split('&')[0];
      }
    }

    final entry = JournalEntry(
      id: entryId,
      transactionType: TransactionType.p2pTransfer,
      referenceId: idempotencyKey,
      description: description ?? 'Paiement QR Code • $merchantName',
      createdAt: now,
    );

    final postings = [
      DetailedLedgerPosting(
        id: _uuid.v4(),
        journalEntryId: entryId,
        accountId: _sandboxWallet.accountId,
        accountName: 'Portefeuille Principal (Mamadou Koné)',
        accountType: AccountType.asset,
        amount: amount,
        currency: currency,
        isCredit: true, // Credit user (reduces asset)
        direction: 'CREDIT',
        createdAt: now,
      ),
      DetailedLedgerPosting(
        id: _uuid.v4(),
        journalEntryId: entryId,
        accountId: 'acc-merchant-$merchantName',
        accountName: 'Boutique $merchantName',
        accountType: AccountType.asset,
        amount: amount,
        currency: currency,
        isCredit: false, // Debit merchant (increases asset)
        direction: 'DEBIT',
        createdAt: now,
      ),
    ];

    final detailed = DetailedJournalEntry(
      entry: entry,
      status: TransactionStatus.posted,
      postings: postings,
      totalDebit: amount,
      totalCredit: amount,
      isBalanced: true,
    );

    _sandboxJournal.insert(0, detailed);
    _sandboxTransactions.insert(
      0,
      UserTransactionItem(
        id: _uuid.v4(),
        journalEntryId: entryId,
        title: entry.description,
        subtitle: 'Paiement QR Code • Sandbox',
        amount: amount,
        currency: currency,
        isCredit: false,
        type: TransactionType.p2pTransfer,
        status: TransactionStatus.posted,
        referenceId: idempotencyKey,
        createdAt: now,
        counterparty: merchantName,
      ),
    );

    _idempotencyCache[idempotencyKey] = detailed;
    _recalculateSandboxBalance();
    return detailed;
  }
}
