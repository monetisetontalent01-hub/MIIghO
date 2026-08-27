import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/demo_data.dart';
import '../../core/models/module_status.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/theme_cubit.dart';
import '../../core/l10n/miigho_strings.dart';
import 'miigho_avatar.dart';
import 'miigho_logo.dart';
import 'miigho_status_badge.dart';

class MiighoSidebar extends StatelessWidget {
  final String currentRoute;

  const MiighoSidebar({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final strings = MiighoStrings.of(context);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: isDark ? MiighoColors.surface1 : MiighoColors.lightSurface1,
        border: Border(
          right: BorderSide(
            color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // En-tête avec Logo MÏÏghO
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                const MiighoLogo(
                  size: 40,
                  variant: MiighoLogoVariant.full,
                  showBadge: true,
                  badgeText: 'OS v2.0',
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Liste des modules avec scroll
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              children: [
                _buildSectionLabel('NAVIGATION PRINCIPALE', isDark),
                _buildNavItem(
                  context,
                  title: strings.navHome,
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                  route: '/home',
                  isSelected: currentRoute == '/home',
                  isDark: isDark,
                ),
                _buildNavItem(
                  context,
                  title: strings.navChat,
                  icon: Icons.chat_bubble_outline_rounded,
                  activeIcon: Icons.chat_bubble_rounded,
                  route: '/conversations',
                  isSelected: currentRoute.startsWith('/conversations'),
                  badgeText: '${DemoDataProvider.unreadMessageCount}',
                  badgeColor: MiighoColors.primary,
                  status: ModuleStatus.active,
                  isDark: isDark,
                ),
                _buildNavItem(
                  context,
                  title: strings.navPay,
                  icon: Icons.account_balance_wallet_outlined,
                  activeIcon: Icons.account_balance_wallet_rounded,
                  route: '/pay',
                  isSelected: currentRoute == '/pay',
                  status: ModuleStatus.prototype,
                  isDark: isDark,
                ),
                _buildNavItem(
                  context,
                  title: strings.navContacts,
                  icon: Icons.people_outline_rounded,
                  activeIcon: Icons.people_rounded,
                  route: '/contacts',
                  isSelected: currentRoute == '/contacts',
                  isDark: isDark,
                ),

                const SizedBox(height: 16),
                _buildSectionLabel('ÉCOSYSTÈME MODULAIRE', isDark),
                _buildNavItem(
                  context,
                  title: 'MÏÏghO Business',
                  icon: Icons.business_center_outlined,
                  activeIcon: Icons.business_center_rounded,
                  route: '/business',
                  isSelected: currentRoute == '/business',
                  status: ModuleStatus.development,
                  isDark: isDark,
                ),
                _buildNavItem(
                  context,
                  title: 'MÏÏghO Market',
                  icon: Icons.storefront_outlined,
                  activeIcon: Icons.storefront_rounded,
                  route: '/market',
                  isSelected: currentRoute == '/market',
                  status: ModuleStatus.comingSoon,
                  isDark: isDark,
                ),
                _buildNavItem(
                  context,
                  title: 'MÏÏghO Cloud',
                  icon: Icons.cloud_outlined,
                  activeIcon: Icons.cloud_rounded,
                  route: '/cloud',
                  isSelected: currentRoute == '/cloud',
                  status: ModuleStatus.comingSoon,
                  isDark: isDark,
                ),
                _buildNavItem(
                  context,
                  title: 'MÏÏghO AI / MédIA',
                  icon: Icons.auto_awesome_outlined,
                  activeIcon: Icons.auto_awesome_rounded,
                  route: '/media',
                  isSelected: currentRoute == '/media',
                  status: ModuleStatus.comingSoon,
                  isDark: isDark,
                ),
                _buildNavItem(
                  context,
                  title: 'MÏÏghO Dev',
                  icon: Icons.code_rounded,
                  activeIcon: Icons.code_rounded,
                  route: '/dev',
                  isSelected: currentRoute == '/dev',
                  status: ModuleStatus.comingSoon,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Bas de la Sidebar (Identity, Thème, Paramètres)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                InkWell(
                  onTap: () => context.push('/identity'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: currentRoute == '/identity'
                          ? (isDark ? MiighoColors.surface2 : MiighoColors.lightSurface2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        MiighoAvatar(
                          name: DemoDataProvider.currentUser.displayName,
                          size: MiighoAvatarSize.sm,
                          isOnline: true,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DemoDataProvider.currentUser.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                                ),
                              ),
                              Text(
                                DemoDataProvider.currentUser.miighoId,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: MiighoColors.gold,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.verified_user_rounded,
                          size: 16,
                          color: MiighoColors.primaryLight,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: isDark ? 'Passer en Mode Clair' : 'Passer en Mode Sombre',
                      icon: Icon(
                        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                        size: 20,
                        color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                      ),
                      onPressed: () => context.read<ThemeCubit>().toggleTheme(),
                    ),
                    IconButton(
                      tooltip: strings.navSettings,
                      icon: Icon(
                        Icons.settings_outlined,
                        size: 20,
                        color: currentRoute == '/settings'
                            ? MiighoColors.primary
                            : (isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
                      ),
                      onPressed: () => context.push('/settings'),
                    ),
                    IconButton(
                      tooltip: 'Déconnexion',
                      icon: const Icon(
                        Icons.logout_rounded,
                        size: 20,
                        color: MiighoColors.error,
                      ),
                      onPressed: () => context.go('/welcome'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: isDark ? MiighoColors.textMuted : MiighoColors.lightTextMuted,
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required IconData activeIcon,
    required String route,
    required bool isSelected,
    required bool isDark,
    String? badgeText,
    Color? badgeColor,
    ModuleStatus? status,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(route),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? MiighoColors.primary.withValues(alpha: isDark ? 0.18 : 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: MiighoColors.primary.withValues(alpha: 0.35), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 20,
                  color: isSelected
                      ? MiighoColors.primary
                      : (isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary)
                          : (isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
                    ),
                  ),
                ),
                if (badgeText != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor ?? MiighoColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ] else if (status != null && status != ModuleStatus.active) ...[
                  MiighoStatusBadge(
                    status: status,
                    fontSize: 9,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
