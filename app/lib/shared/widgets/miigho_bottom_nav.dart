import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/module_status.dart';
import '../../core/theme/colors.dart';
import '../../core/l10n/miigho_strings.dart';
import '../../features/chat/presentation/bloc/chat_bloc.dart';
import 'miigho_status_badge.dart';

class MiighoBottomNav extends StatelessWidget {
  final String currentRoute;

  const MiighoBottomNav({
    super.key,
    required this.currentRoute,
  });

  int _calculateIndex() {
    if (currentRoute == '/home') return 0;
    if (currentRoute.startsWith('/conversations')) return 1;
    if (currentRoute == '/pay') return 2;
    return 3; // Plus or other
  }

  void _showMoreBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? MiighoColors.surface1 : MiighoColors.lightSurface1,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark ? MiighoColors.borderMedium : MiighoColors.lightBorderMedium,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? MiighoColors.borderStrong : MiighoColors.lightBorderMedium,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Écosystème MÏÏghO',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: MiighoColors.primaryAlpha,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'OS v2.0',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: MiighoColors.primaryLight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Accédez aux autres modules et outils de l\'écosystème.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Modules grid / list
              _buildMoreTile(
                context,
                title: 'MÏÏghO Identity',
                subtitle: 'Profil souverain, MÏÏghO ID, sécurité & sessions',
                icon: Icons.badge_outlined,
                route: '/identity',
                status: ModuleStatus.active,
                isDark: isDark,
              ),
              _buildMoreTile(
                context,
                title: 'MÏÏghO Contacts',
                subtitle: 'Carnet d\'adresses, favoris et invitations',
                icon: Icons.people_outline_rounded,
                route: '/contacts',
                status: ModuleStatus.active,
                isDark: isDark,
              ),
              _buildMoreTile(
                context,
                title: 'MÏÏghO Business',
                subtitle: 'Factures, gestion clients & QR d\'encaissement',
                icon: Icons.business_center_outlined,
                route: '/business',
                status: ModuleStatus.development,
                isDark: isDark,
              ),
              _buildMoreTile(
                context,
                title: 'MÏÏghO Market',
                subtitle: 'Place de marché & achats sécurisés Escrow',
                icon: Icons.storefront_outlined,
                route: '/market',
                status: ModuleStatus.comingSoon,
                isDark: isDark,
              ),
              _buildMoreTile(
                context,
                title: 'MÏÏghO Cloud',
                subtitle: 'Stockage souverain de fichiers & documents',
                icon: Icons.cloud_outlined,
                route: '/cloud',
                status: ModuleStatus.comingSoon,
                isDark: isDark,
              ),
              _buildMoreTile(
                context,
                title: 'MÏÏghO AI / MédIA',
                subtitle: 'Assistant intelligent panafricain',
                icon: Icons.auto_awesome_outlined,
                route: '/media',
                status: ModuleStatus.comingSoon,
                isDark: isDark,
              ),
              _buildMoreTile(
                context,
                title: 'MÏÏghO Dev Platform',
                subtitle: 'Documentation, APIs, SDKs et Webhooks',
                icon: Icons.code_rounded,
                route: '/dev',
                status: ModuleStatus.comingSoon,
                isDark: isDark,
              ),
              _buildMoreTile(
                context,
                title: 'Paramètres & Préférences',
                subtitle: 'Thème sombre/clair, langue, sécurité',
                icon: Icons.settings_outlined,
                route: '/settings',
                status: ModuleStatus.active,
                isDark: isDark,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMoreTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String route,
    required ModuleStatus status,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          context.push(route);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: status.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              MiighoStatusBadge(status: status, fontSize: 9),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _calculateIndex();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final strings = MiighoStrings.of(context);
    final chatState = context.watch<ChatBloc>().state;
    final unreadCount = chatState is ConversationsLoaded
        ? chatState.conversations.fold<int>(0, (sum, c) => sum + c.unreadCount)
        : 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? MiighoColors.surface1 : MiighoColors.lightSurface1,
        border: Border(
          top: BorderSide(
            color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          elevation: 0,
          backgroundColor: Colors.transparent,
          selectedItemColor: MiighoColors.primary,
          unselectedItemColor: isDark ? MiighoColors.textMuted : MiighoColors.lightTextMuted,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.dashboard_outlined),
              activeIcon: const Icon(Icons.dashboard_rounded),
              label: strings.navHome,
            ),
            BottomNavigationBarItem(
              icon: unreadCount > 0
                  ? Badge(
                      label: Text('$unreadCount'),
                      backgroundColor: MiighoColors.primary,
                      child: const Icon(Icons.chat_bubble_outline_rounded),
                    )
                  : const Icon(Icons.chat_bubble_outline_rounded),
              activeIcon: unreadCount > 0
                  ? Badge(
                      label: Text('$unreadCount'),
                      backgroundColor: MiighoColors.primary,
                      child: const Icon(Icons.chat_bubble_rounded),
                    )
                  : const Icon(Icons.chat_bubble_rounded),
              label: strings.navChat,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              activeIcon: const Icon(Icons.account_balance_wallet_rounded),
              label: strings.navPay,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.grid_view_outlined),
              activeIcon: const Icon(Icons.grid_view_rounded),
              label: strings.navMore,
            ),
          ],
          onTap: (index) {
            switch (index) {
              case 0:
                context.go('/home');
                break;
              case 1:
                context.go('/conversations');
                break;
              case 2:
                context.go('/pay');
                break;
              case 3:
                _showMoreBottomSheet(context);
                break;
            }
          },
        ),
      ),
    );
  }
}
