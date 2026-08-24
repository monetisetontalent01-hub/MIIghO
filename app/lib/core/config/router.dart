import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/auth/presentation/screens/phone_input_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/profile_setup_screen.dart';
import '../../features/chat/presentation/screens/conversations_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/contacts/presentation/screens/contacts_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

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
        return '/conversations';
      }
      
      return null;
    },
    routes: [
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
      GoRoute(
        path: '/conversations',
        builder: (context, state) => const ConversationsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return ChatScreen(conversationId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/contacts',
        builder: (context, state) => const ContactsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}
