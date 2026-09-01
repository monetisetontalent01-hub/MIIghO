import 'package:flutter_test/flutter_test.dart';
import 'package:miigho/core/network/api_client.dart';
import 'package:miigho/core/storage/secure_storage.dart';
import 'package:miigho/features/auth/data/auth_repository.dart';
import 'package:miigho/features/auth/presentation/bloc/auth_bloc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureStorageService secureStorage;
  late ApiClient apiClient;
  late AuthRepository authRepository;

  setUp(() {
    secureStorage = SecureStorageService.inMemory();
    apiClient = ApiClient('http://localhost:8080/api/v1', secureStorage);
    authRepository = AuthRepository(apiClient, secureStorage);
  });

  test('AuthBloc starts unauthenticated when storage is empty', () async {
    final bloc = AuthBloc(authRepository: authRepository);
    expect(bloc.state, isA<AuthInitial>());

    bloc.add(AuthCheckRequested());
    await expectLater(
      bloc.stream,
      emits(isA<AuthUnauthenticated>()),
    );
  });

  test('Logout clears all tokens and emits AuthUnauthenticated', () async {
    await secureStorage.saveTokens(
      accessToken: 'sample_access_token',
      refreshToken: 'sample_refresh_token',
    );
    await secureStorage.saveUser('sample_user_id', '+2250506169325');

    final bloc = AuthBloc(authRepository: authRepository);
    bloc.add(LogoutRequested());

    await expectLater(
      bloc.stream,
      emits(isA<AuthUnauthenticated>()),
    );

    expect(await secureStorage.getAccessToken(), isNull);
    expect(await secureStorage.getRefreshToken(), isNull);
    expect(await secureStorage.getUserId(), isNull);
    expect(await secureStorage.getPhone(), isNull);
  });
}
