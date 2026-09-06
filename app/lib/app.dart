import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'core/config/router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'core/l10n/locale_cubit.dart';
import 'core/network/api_client.dart';
import 'core/storage/local_database.dart';
import 'core/storage/secure_storage.dart';
import 'core/network/connectivity_service.dart';
import 'core/network/ws_client.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/identity/data/identity_repository.dart';
import 'features/identity/presentation/bloc/identity_bloc.dart';
import 'features/chat/data/chat_repository.dart';
import 'features/chat/presentation/bloc/chat_bloc.dart';
import 'features/contacts/data/contacts_repository.dart';
import 'features/contacts/presentation/bloc/contacts_bloc.dart';
import 'features/pay/data/pay_repository.dart';
import 'features/pay/presentation/bloc/pay_bloc.dart';

class MiighoApp extends StatefulWidget {
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
  State<MiighoApp> createState() => _MiighoAppState();
}

class _MiighoAppState extends State<MiighoApp> with WidgetsBindingObserver {
  late final AuthRepository _authRepository;
  late final AuthBloc _authBloc;
  late final IdentityRepository _identityRepository;
  late final IdentityBloc _identityBloc;
  late final ChatRepository _chatRepository;
  late final ChatBloc _chatBloc;
  late final ContactsRepository _contactsRepository;
  late final ContactsBloc _contactsBloc;
  late final PayRepository _payRepository;
  late final PayBloc _payBloc;
  late final ThemeCubit _themeCubit;
  late final LocaleCubit _localeCubit;
  late final GoRouter _router;

  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _authRepository = AuthRepository(widget.apiClient, widget.secureStorage);
    _authBloc = AuthBloc(authRepository: _authRepository)..add(AuthCheckRequested());

    // Connect ApiClient callbacks
    widget.apiClient.onSessionExpired = () {
      _authBloc.add(LogoutRequested());
    };
    widget.apiClient.onTokenRefreshed = (newToken) {
      widget.wsClient.updateToken(newToken);
    };

    _identityRepository = IdentityRepository(
      apiClient: widget.apiClient,
      secureStorage: widget.secureStorage,
    );
    _identityBloc = IdentityBloc(repository: _identityRepository);

    _chatRepository = ChatRepository(
      apiClient: widget.apiClient,
      wsClient: widget.wsClient,
      secureStorage: widget.secureStorage,
    );
    _chatBloc = ChatBloc(chatRepository: _chatRepository);

    _contactsRepository = ContactsRepository(
      apiClient: widget.apiClient,
      secureStorage: widget.secureStorage,
      database: widget.database,
    );
    _contactsBloc = ContactsBloc(repository: _contactsRepository);

    _payRepository = PayRepository(
      apiClient: widget.apiClient,
    );
    _payBloc = PayBloc(repository: _payRepository);

    _themeCubit = ThemeCubit(widget.secureStorage);
    _localeCubit = LocaleCubit(widget.secureStorage);

    _router = createRouter(_authRepository, _authBloc);

    // Coordinate WebSocket & Chat lifecycle with authentication state
    _authSub = _authBloc.stream.listen((state) {
      if (state is AuthAuthenticated) {
        _chatRepository.connectWebSocket();
        _chatBloc.add(LoadConversations());
        _identityBloc.add(LoadIdentity());
        _contactsBloc.add(const LoadContacts());
        _payBloc.add(LoadPayWallet());
      } else if (state is AuthUnauthenticated) {
        widget.wsClient.disconnect();
        _chatBloc.add(ResetChatStateEvent());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Upon returning from Safari iOS background/lock, verify WebSocket state
      if (_authBloc.state is AuthAuthenticated && !widget.wsClient.isConnected) {
        _chatRepository.connectWebSocket();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _authBloc.close();
    _identityBloc.close();
    _chatBloc.close();
    _contactsBloc.close();
    _payBloc.close();
    _themeCubit.close();
    _localeCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _themeCubit),
        BlocProvider.value(value: _localeCubit),
        BlocProvider.value(value: _identityBloc),
        BlocProvider.value(value: _authBloc),
        BlocProvider.value(value: _chatBloc),
        BlocProvider.value(value: _contactsBloc),
        BlocProvider.value(value: _payBloc),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return BlocBuilder<LocaleCubit, Locale>(
            builder: (context, locale) {
              return MaterialApp.router(
                title: 'MÏÏghO OS',
                debugShowCheckedModeBanner: false,
                theme: MiighoTheme.lightTheme,
                darkTheme: MiighoTheme.darkTheme,
                themeMode: themeMode,
                locale: locale,
                routerConfig: _router,
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: LocaleCubit.supportedLocales,
              );
            },
          );
        },
      ),
    );
  }
}
