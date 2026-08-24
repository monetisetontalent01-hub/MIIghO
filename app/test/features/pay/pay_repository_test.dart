import 'package:flutter_test/flutter_test.dart';
import 'package:miigho/core/network/api_client.dart';
import 'package:miigho/core/storage/secure_storage.dart';
import 'package:miigho/features/pay/data/pay_repository.dart';
import 'package:miigho/features/pay/models/pay_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PayRepository repository;

  setUp(() {
    final storage = SecureStorageService();
    final apiClient = ApiClient('http://localhost:8080', storage);
    repository = PayRepository(apiClient: apiClient);
  });

  group('PayRepository Double-Entry Sandbox Tests', () {
    test('Initial wallet balance derived from seeded double-entry transactions is 45,000 FCFA', () async {
      final wallet = await repository.getWallet();
      expect(wallet.availableBalance, 45000);
      expect(wallet.currency, 'FCFA');
      expect(wallet.isSandbox, true);
    });

    test('Initial journal entries all respect the double-entry invariant sum(DR) == sum(CR)', () async {
      final journal = await repository.getJournal();
      expect(journal.length, greaterThanOrEqualTo(3));

      for (final entry in journal) {
        expect(entry.isBalanced, true, reason: 'Entry ${entry.entry.id} must be balanced');
        expect(entry.totalDebit, equals(entry.totalCredit));
        expect(entry.postings.length, greaterThanOrEqualTo(2));
      }
    });

    test('SendMoney P2P creates balanced journal entry and decrements sender derived balance', () async {
      final initialWallet = await repository.getWallet();
      final initialBalance = initialWallet.availableBalance;

      final transfer = await repository.sendMoneyP2P(
        toContact: 'MG-7731-SEN',
        amount: 5000,
        currency: 'FCFA',
        description: 'Test Transfert Flutter',
        idempotencyKey: 'test-p2p-001',
      );

      expect(transfer.isBalanced, true);
      expect(transfer.totalDebit, 5000);
      expect(transfer.totalCredit, 5000);
      expect(transfer.entry.transactionType, TransactionType.p2pTransfer);

      final updatedWallet = await repository.getWallet();
      expect(updatedWallet.availableBalance, initialBalance - 5000);
    });

    test('CashIn creates balanced journal entry and increments user derived balance', () async {
      final initialWallet = await repository.getWallet();
      final initialBalance = initialWallet.availableBalance;

      final cashIn = await repository.cashIn(
        provider: 'wave',
        phoneNumber: '+22507000000',
        amount: 15000,
        currency: 'FCFA',
        idempotencyKey: 'test-cashin-001',
      );

      expect(cashIn.isBalanced, true);
      expect(cashIn.totalDebit, 15000);
      expect(cashIn.totalCredit, 15000);
      expect(cashIn.entry.transactionType, TransactionType.momoCashIn);

      final updatedWallet = await repository.getWallet();
      expect(updatedWallet.availableBalance, initialBalance + 15000);
    });

    test('CashOut exceeding available balance throws exception', () async {
      final wallet = await repository.getWallet();

      expect(
        () => repository.cashOut(
          provider: 'orange_money',
          phoneNumber: '+22507000000',
          amount: wallet.availableBalance + 100000,
          currency: 'FCFA',
          idempotencyKey: 'test-fail-cashout',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Idempotent submission returns exact same transaction and does not duplicate postings', () async {
      const idempotencyKey = 'idempotent-unique-key-xyz';

      final tx1 = await repository.cashIn(
        provider: 'mtn_momo',
        phoneNumber: '+22507000000',
        amount: 8000,
        currency: 'FCFA',
        idempotencyKey: idempotencyKey,
      );

      final balAfter1 = (await repository.getWallet()).availableBalance;

      final tx2 = await repository.cashIn(
        provider: 'mtn_momo',
        phoneNumber: '+22507000000',
        amount: 8000,
        currency: 'FCFA',
        idempotencyKey: idempotencyKey,
      );

      final balAfter2 = (await repository.getWallet()).availableBalance;

      expect(tx1.entry.id, equals(tx2.entry.id));
      expect(balAfter1, equals(balAfter2));
    });
  });
}
