import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/config/router.dart';
import 'core/theme/app_theme.dart';
import 'core/network/api_client.dart';
import 'core/storage/local_database.dart';
import 'core/storage/secure_storage.dart';
import 'core/network/connectivity_service.dart';
import 'core/network/ws_client.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/chat/data/chat_repository.dart';
import 'features/chat/presentation/bloc/chat_bloc.dart';

import 'features/contacts/data/contacts_repository.dart';
import 'features/contacts/presentation/bloc/contacts_bloc.dart';

class MiighoApp extends StatelessWidget {
  final SecureStorageService secureStorage;
  final MiighoDatabase database;
  final ApiClient apiClient;
  final WsClient wsClient;
  final ConnectivityService connectivityService;

  const MiighoApp({
    super.key,
    required this.secureStorage,
    required this.database,
    required this.apiClient,
    required this.wsClient,
    required this.connectivityService,
  });

  @override
  Widget build(BuildContext context) {
    final authRepository = AuthRepository(apiClient, secureStorage);
    final chatRepository = ChatRepository(
      apiClient: apiClient,
      wsClient: wsClient,
      secureStorage: secureStorage,
    );
    final contactsRepository = ContactsRepository(
      apiClient: apiClient,
      database: database,
    );
    final router = createRouter(authRepository);

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => AuthBloc(authRepository: authRepository)..add(AuthCheckRequested()),
        ),
        BlocProvider(
          create: (_) => ChatBloc(chatRepository: chatRepository)..add(LoadConversations()),
        ),
        BlocProvider(
          create: (_) => ContactsBloc(repository: contactsRepository)..add(const LoadContacts()),
        ),
      ],
      child: MaterialApp.router(
        title: 'MÏÏghO',
        theme: MiighoTheme.lightTheme,
        darkTheme: MiighoTheme.darkTheme,
        themeMode: ThemeMode.system,
        routerConfig: router,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('fr', ''),
          Locale('en', ''),
          Locale('sw', ''),
          Locale('ar', ''),
        ],
      ),
    );
  }
}
