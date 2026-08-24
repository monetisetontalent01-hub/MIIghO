import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'app.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/storage/local_database.dart';
import 'core/storage/secure_storage.dart';
import 'core/network/connectivity_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  final secureStorage = SecureStorageService();
  final database = MiighoDatabase();
  final config = AppConfig.dev();
  final apiClient = ApiClient(config.baseUrl, secureStorage);
  final wsClient = WsClient(config.wsUrl);
  final connectivityService = ConnectivityService();

  // BLoC observer for debugging
  Bloc.observer = AppBlocObserver();

  runApp(MiighoApp(
    secureStorage: secureStorage,
    database: database,
    apiClient: apiClient,
    wsClient: wsClient,
    connectivityService: connectivityService,
  ));
}

class AppBlocObserver extends BlocObserver {
  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    debugPrint('${bloc.runtimeType} $change');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    debugPrint('${bloc.runtimeType} $error $stackTrace');
    super.onError(bloc, error, stackTrace);
  }
}
