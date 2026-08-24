import 'package:flutter_test/flutter_test.dart';
import 'package:miigho/core/network/api_client.dart';
import 'package:miigho/core/storage/secure_storage.dart';
import 'package:miigho/features/pay/data/pay_repository.dart';
import 'package:miigho/features/pay/presentation/bloc/pay_bloc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PayRepository repository;
  late PayBloc bloc;

  setUp(() {
    final storage = SecureStorageService();
    final apiClient = ApiClient('http://localhost:8080', storage);
    repository = PayRepository(apiClient: apiClient);
    bloc = PayBloc(repository: repository);
  });

  tearDown(() {
    bloc.close();
  });

  group('PayBloc State Management Tests', () {
    test('Initial state is PayInitial', () {
      expect(bloc.state, isA<PayInitial>());
    });

    test('LoadPayWallet emits PayLoading then PayLoaded with derived ledger balance', () async {
      final expectedStates = [
        isA<PayLoading>(),
        isA<PayLoaded>().having((s) => s.wallet.availableBalance, 'availableBalance', 45000),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));

      bloc.add(LoadPayWallet());
    });

    test('SendMoneyEvent updates wallet balance and emits success message', () async {
      bloc.add(LoadPayWallet());
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(
        SendMoneyEvent(
          toContact: 'MG-4412-MLI',
          amount: 5000,
          currency: 'FCFA',
          description: 'Cadeau Mali',
        ),
      );

      final state = await bloc.stream.firstWhere((s) => s is PayLoaded && s.actionSuccessMessage != null) as PayLoaded;
      expect(state.wallet.availableBalance, 40000);
      expect(state.actionSuccessMessage, contains('succès'));
    });

    test('CashInEvent increments balance and emits success', () async {
      bloc.add(LoadPayWallet());
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(
        CashInEvent(
          provider: 'wave',
          phoneNumber: '+22507000000',
          amount: 20000,
          currency: 'FCFA',
        ),
      );

      final state = await bloc.stream.firstWhere((s) => s is PayLoaded && s.actionSuccessMessage != null) as PayLoaded;
      expect(state.wallet.availableBalance, 65000);
    });

    test('QRPayEvent decrements balance and emits success', () async {
      bloc.add(LoadPayWallet());
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(
        QRPayEvent(
          qrData: 'miigho://pay?to=Pharmacie_Centrale',
          amount: 3000,
          currency: 'FCFA',
        ),
      );

      final state = await bloc.stream.firstWhere((s) => s is PayLoaded && s.actionSuccessMessage != null) as PayLoaded;
      expect(state.wallet.availableBalance, 42000);
    });
  });
}
