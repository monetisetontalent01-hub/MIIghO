import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../data/pay_repository.dart';
import '../../models/pay_models.dart';

// === EVENTS ===
abstract class PayEvent {}

class LoadPayWallet extends PayEvent {
  final String currency;
  final bool refresh;
  LoadPayWallet({this.currency = 'FCFA', this.refresh = false});
}

class SendMoneyEvent extends PayEvent {
  final String toContact;
  final int amount;
  final String currency;
  final String? description;

  SendMoneyEvent({
    required this.toContact,
    required this.amount,
    this.currency = 'FCFA',
    this.description,
  });
}

class CashInEvent extends PayEvent {
  final String provider;
  final String phoneNumber;
  final int amount;
  final String currency;

  CashInEvent({
    required this.provider,
    required this.phoneNumber,
    required this.amount,
    this.currency = 'FCFA',
  });
}

class CashOutEvent extends PayEvent {
  final String provider;
  final String phoneNumber;
  final int amount;
  final String currency;

  CashOutEvent({
    required this.provider,
    required this.phoneNumber,
    required this.amount,
    this.currency = 'FCFA',
  });
}

class QRPayEvent extends PayEvent {
  final String qrData;
  final int amount;
  final String currency;
  final String? description;

  QRPayEvent({
    required this.qrData,
    required this.amount,
    this.currency = 'FCFA',
    this.description,
  });
}

class LoadJournalEvent extends PayEvent {}

class LoadTransactionDetailEvent extends PayEvent {
  final String entryId;
  LoadTransactionDetailEvent(this.entryId);
}

// === STATES ===
abstract class PayState {}

class PayInitial extends PayState {}

class PayLoading extends PayState {}

class PayActionInProgress extends PayState {
  final String actionLabel;
  final WalletSummary? currentWallet;
  final List<UserTransactionItem>? currentTransactions;

  PayActionInProgress(this.actionLabel, {this.currentWallet, this.currentTransactions});
}

class PayLoaded extends PayState {
  final WalletSummary wallet;
  final List<UserTransactionItem> transactions;
  final List<DetailedJournalEntry> journal;
  final DetailedJournalEntry? selectedTransaction;
  final String? actionSuccessMessage;

  PayLoaded({
    required this.wallet,
    required this.transactions,
    this.journal = const [],
    this.selectedTransaction,
    this.actionSuccessMessage,
  });

  PayLoaded copyWith({
    WalletSummary? wallet,
    List<UserTransactionItem>? transactions,
    List<DetailedJournalEntry>? journal,
    DetailedJournalEntry? selectedTransaction,
    String? actionSuccessMessage,
  }) {
    return PayLoaded(
      wallet: wallet ?? this.wallet,
      transactions: transactions ?? this.transactions,
      journal: journal ?? this.journal,
      selectedTransaction: selectedTransaction ?? this.selectedTransaction,
      actionSuccessMessage: actionSuccessMessage,
    );
  }
}

class PayError extends PayState {
  final String message;
  final WalletSummary? currentWallet;
  final List<UserTransactionItem>? currentTransactions;

  PayError(this.message, {this.currentWallet, this.currentTransactions});
}

// === BLOC ===
class PayBloc extends Bloc<PayEvent, PayState> {
  final PayRepository repository;
  final _uuid = const Uuid();

  PayBloc({required this.repository}) : super(PayInitial()) {
    on<LoadPayWallet>(_onLoadPayWallet);
    on<SendMoneyEvent>(_onSendMoney);
    on<CashInEvent>(_onCashIn);
    on<CashOutEvent>(_onCashOut);
    on<QRPayEvent>(_onQRPay);
    on<LoadJournalEvent>(_onLoadJournal);
    on<LoadTransactionDetailEvent>(_onLoadTransactionDetail);
  }

  Future<void> _onLoadPayWallet(LoadPayWallet event, Emitter<PayState> emit) async {
    if (state is! PayLoaded || event.refresh) {
      emit(PayLoading());
    }
    try {
      final wallet = await repository.getWallet(currency: event.currency);
      final txs = await repository.getTransactions(currency: event.currency);
      emit(PayLoaded(wallet: wallet, transactions: txs));
    } catch (e) {
      emit(PayError(e.toString()));
    }
  }

  Future<void> _onSendMoney(SendMoneyEvent event, Emitter<PayState> emit) async {
    WalletSummary? currentWallet;
    List<UserTransactionItem>? currentTxs;
    if (state is PayLoaded) {
      currentWallet = (state as PayLoaded).wallet;
      currentTxs = (state as PayLoaded).transactions;
    }

    emit(PayActionInProgress('Envoi du transfert...', currentWallet: currentWallet, currentTransactions: currentTxs));

    try {
      final idempotencyKey = 'p2p-${_uuid.v4()}';
      final detail = await repository.sendMoneyP2P(
        toContact: event.toContact,
        amount: event.amount,
        currency: event.currency,
        description: event.description,
        idempotencyKey: idempotencyKey,
      );

      final wallet = await repository.getWallet(currency: event.currency);
      final txs = await repository.getTransactions(currency: event.currency);
      emit(PayLoaded(
        wallet: wallet,
        transactions: txs,
        selectedTransaction: detail,
        actionSuccessMessage: 'Transfert de ${event.amount} ${event.currency} envoyé avec succès à ${event.toContact} (Sandbox).',
      ));
    } catch (e) {
      emit(PayError(e.toString().replaceAll('Exception: ', ''), currentWallet: currentWallet, currentTransactions: currentTxs));
    }
  }

  Future<void> _onCashIn(CashInEvent event, Emitter<PayState> emit) async {
    WalletSummary? currentWallet;
    List<UserTransactionItem>? currentTxs;
    if (state is PayLoaded) {
      currentWallet = (state as PayLoaded).wallet;
      currentTxs = (state as PayLoaded).transactions;
    }

    emit(PayActionInProgress('Recharge en cours...', currentWallet: currentWallet, currentTransactions: currentTxs));

    try {
      final idempotencyKey = 'cashin-${_uuid.v4()}';
      final detail = await repository.cashIn(
        provider: event.provider,
        phoneNumber: event.phoneNumber,
        amount: event.amount,
        currency: event.currency,
        idempotencyKey: idempotencyKey,
      );

      final wallet = await repository.getWallet(currency: event.currency);
      final txs = await repository.getTransactions(currency: event.currency);
      emit(PayLoaded(
        wallet: wallet,
        transactions: txs,
        selectedTransaction: detail,
        actionSuccessMessage: 'Recharge de ${event.amount} ${event.currency} via ${event.provider.toUpperCase()} effectuée avec succès (Sandbox).',
      ));
    } catch (e) {
      emit(PayError(e.toString().replaceAll('Exception: ', ''), currentWallet: currentWallet, currentTransactions: currentTxs));
    }
  }

  Future<void> _onCashOut(CashOutEvent event, Emitter<PayState> emit) async {
    WalletSummary? currentWallet;
    List<UserTransactionItem>? currentTxs;
    if (state is PayLoaded) {
      currentWallet = (state as PayLoaded).wallet;
      currentTxs = (state as PayLoaded).transactions;
    }

    emit(PayActionInProgress('Retrait en cours...', currentWallet: currentWallet, currentTransactions: currentTxs));

    try {
      final idempotencyKey = 'cashout-${_uuid.v4()}';
      final detail = await repository.cashOut(
        provider: event.provider,
        phoneNumber: event.phoneNumber,
        amount: event.amount,
        currency: event.currency,
        idempotencyKey: idempotencyKey,
      );

      final wallet = await repository.getWallet(currency: event.currency);
      final txs = await repository.getTransactions(currency: event.currency);
      emit(PayLoaded(
        wallet: wallet,
        transactions: txs,
        selectedTransaction: detail,
        actionSuccessMessage: 'Retrait de ${event.amount} ${event.currency} vers ${event.phoneNumber} confirmé (Sandbox).',
      ));
    } catch (e) {
      emit(PayError(e.toString().replaceAll('Exception: ', ''), currentWallet: currentWallet, currentTransactions: currentTxs));
    }
  }

  Future<void> _onQRPay(QRPayEvent event, Emitter<PayState> emit) async {
    WalletSummary? currentWallet;
    List<UserTransactionItem>? currentTxs;
    if (state is PayLoaded) {
      currentWallet = (state as PayLoaded).wallet;
      currentTxs = (state as PayLoaded).transactions;
    }

    emit(PayActionInProgress('Paiement QR en cours...', currentWallet: currentWallet, currentTransactions: currentTxs));

    try {
      final idempotencyKey = 'qrpay-${_uuid.v4()}';
      final detail = await repository.payQR(
        qrData: event.qrData,
        amount: event.amount,
        currency: event.currency,
        description: event.description,
        idempotencyKey: idempotencyKey,
      );

      final wallet = await repository.getWallet(currency: event.currency);
      final txs = await repository.getTransactions(currency: event.currency);
      emit(PayLoaded(
        wallet: wallet,
        transactions: txs,
        selectedTransaction: detail,
        actionSuccessMessage: 'Paiement QR de ${event.amount} ${event.currency} validé avec succès (Sandbox).',
      ));
    } catch (e) {
      emit(PayError(e.toString().replaceAll('Exception: ', ''), currentWallet: currentWallet, currentTransactions: currentTxs));
    }
  }

  Future<void> _onLoadJournal(LoadJournalEvent event, Emitter<PayState> emit) async {
    if (state is PayLoaded) {
      final cur = state as PayLoaded;
      try {
        final journal = await repository.getJournal();
        emit(cur.copyWith(journal: journal));
      } catch (_) {}
    }
  }

  Future<void> _onLoadTransactionDetail(LoadTransactionDetailEvent event, Emitter<PayState> emit) async {
    if (state is PayLoaded) {
      final cur = state as PayLoaded;
      try {
        final detail = await repository.getTransactionDetail(event.entryId);
        emit(cur.copyWith(selectedTransaction: detail));
      } catch (_) {}
    }
  }
}
