import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/auth/presentation/screens/phone_input_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/profile_setup_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/chat/presentation/screens/chat_master_detail_screen.dart';
import '../../features/contacts/presentation/screens/contacts_screen.dart';
import '../../features/pay/presentation/screens/pay_screen.dart';
import '../../features/identity/presentation/screens/identity_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/modules/presentation/screens/module_screen.dart';
import '../../shared/widgets/miigho_navigation_shell.dart';

GoRouter createRouter(AuthRepository authRepository) {
  return GoRouter(
    initialLocation: '/welcome',
    redirect: (BuildContext context, GoRouterState state) async {
      final token = await authRepository.getAccessToken();
      final isAuthenticated = token != null;

      final isAuthRoute = state.matchedLocation.startsWith('/auth') || state.matchedLocation == '/welcome';

      if (!isAuthenticated && !isAuthRoute) {
        return '/welcome';
      }

      if (isAuthenticated && isAuthRoute) {
        return '/home';
      }

      return null;
    },
    routes: [
      // Routes d'authentification et d'accueil
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/auth/phone',
        builder: (context, state) => const PhoneInputScreen(),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (context, state) {
          final phone = state.extra as String? ?? '';
          return OtpVerificationScreen(phone: phone);
        },
      ),
      GoRoute(
        path: '/auth/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),

      // Routes authentifiées avec Navigation Shell MÏÏghO OS (Sidebar Desktop / BottomNav Mobile)
      ShellRoute(
        builder: (context, state, child) {
          return MiighoNavigationShell(state: state, child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/conversations',
            builder: (context, state) => const ChatMasterDetailScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return ChatMasterDetailScreen(initialConversationId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/contacts',
            builder: (context, state) => const ContactsScreen(),
          ),
          GoRoute(
            path: '/pay',
            builder: (context, state) => const PayScreen(),
          ),
          GoRoute(
            path: '/identity',
            builder: (context, state) => const IdentityScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/business',
            builder: (context, state) => const ModuleScreen(moduleId: 'business'),
          ),
          GoRoute(
            path: '/market',
            builder: (context, state) => const ModuleScreen(moduleId: 'market'),
          ),
          GoRoute(
            path: '/cloud',
            builder: (context, state) => const ModuleScreen(moduleId: 'cloud'),
          ),
          GoRoute(
            path: '/media',
            builder: (context, state) => const ModuleScreen(moduleId: 'media'),
          ),
          GoRoute(
            path: '/dev',
            builder: (context, state) => const ModuleScreen(moduleId: 'dev'),
          ),
        ],
      ),
    ],
  );
}
