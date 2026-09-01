import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/demo_data.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/l10n/locale_cubit.dart';
import '../../../../shared/widgets/miigho_avatar.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = DemoDataProvider.currentUser;
    final themeCubit = context.watch<ThemeCubit>();
    final localeCubit = context.watch<LocaleCubit>();

    return Scaffold(
      backgroundColor: isDark ? MiighoColors.canvas : MiighoColors.lightCanvas,
      appBar: AppBar(
        title: const Text('Paramètres MÏÏghO'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Carte Profil Utilisateur / Identity
          InkWell(
            onTap: () => context.push('/identity'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF581C87), const Color(0xFF3B0764)]
                      : [const Color(0xFF7C3AED), const Color(0xFF6D28D9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: MiighoColors.primary.withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  MiighoAvatar(
                    name: user.displayName,
                    size: MiighoAvatarSize.lg,
                    isOnline: true,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user.miighoId,
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            color: MiighoColors.goldLight,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user.phoneNumber,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.qr_code_rounded, color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Section Apparence & Thème
          _buildSectionHeader('APPARENCE & THÈME'),
          Container(
            decoration: BoxDecoration(
              color: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface1,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined, color: MiighoColors.primary),
                  title: const Text('Mode du thème', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    themeCubit.state == ThemeMode.dark
                        ? 'Mode Sombre Panafricain (Actif)'
                        : (themeCubit.state == ThemeMode.light ? 'Mode Clair' : 'Système automatique'),
                    style: TextStyle(fontSize: 12, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
                  ),
                  trailing: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined, size: 16),
                      ),
                    ],
                    selected: {themeCubit.state == ThemeMode.light ? ThemeMode.light : ThemeMode.dark},
                    onSelectionChanged: (newSelection) {
                      themeCubit.setTheme(newSelection.first);
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                Divider(height: 1, color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle),
                ListTile(
                  leading: const Icon(Icons.language_rounded, color: Color(0xFF3B82F6)),
                  title: const Text('Langue de l\'application', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    _getLocaleDisplayName(localeCubit.state.languageCode),
                    style: TextStyle(fontSize: 12, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
                  ),
                  trailing: DropdownButton<String>(
                    value: localeCubit.state.languageCode,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'fr', child: Text('Français 🇫🇷')),
                      DropdownMenuItem(value: 'en', child: Text('English 🇬🇧')),
                      DropdownMenuItem(value: 'sw', child: Text('Kiswahili 🇹🇿')),
                      DropdownMenuItem(value: 'ar', child: Text('العربية 🇸🇦')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        localeCubit.setLocale(Locale(val, ''));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section MÏÏghO Pay & Services
          _buildSectionHeader('SERVICES & ÉCOSYSTÈME'),
          _buildSettingsTile(
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFFF59E0B),
            title: 'MÏÏghO Pay (Sandbox)',
            subtitle: 'Solde: 45 000 FCFA • Mobile Money & P2P',
            isDark: isDark,
            onTap: () => context.push('/pay'),
          ),
          _buildSettingsTile(
            icon: Icons.badge_outlined,
            color: MiighoColors.primary,
            title: 'MÏÏghO Identity',
            subtitle: 'Gérer mon identité, KYC et sessions actives',
            isDark: isDark,
            onTap: () => context.push('/identity'),
          ),

          const SizedBox(height: 20),

          // Section Sécurité & Compte
          _buildSectionHeader('COMPTE & SÉCURITÉ'),
          _buildSettingsTile(
            icon: Icons.lock_outline_rounded,
            color: const Color(0xFF10B981),
            title: 'Confidentialité & Chiffrement',
            subtitle: 'Signal Protocol & E2E Security',
            isDark: isDark,
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: Icons.notifications_none_rounded,
            color: const Color(0xFFEC4899),
            title: 'Notifications & Sons',
            subtitle: 'Messages, alertes et tontines',
            isDark: isDark,
            onTap: () {},
          ),

          const SizedBox(height: 20),

          // Section À propos
          _buildSectionHeader('À PROPOS'),
          _buildSettingsTile(
            icon: Icons.info_outline_rounded,
            color: Colors.grey,
            title: 'MÏÏghO OS v2.0',
            subtitle: 'Écosystème Numérique Panafricain • Horizon 2036',
            isDark: isDark,
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: Icons.logout_rounded,
            color: MiighoColors.error,
            title: 'Déconnexion',
            subtitle: 'Se déconnecter de ce compte',
            isDark: isDark,
            onTap: () {
              context.read<AuthBloc>().add(LogoutRequested());
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _getLocaleDisplayName(String code) {
    switch (code) {
      case 'fr': return 'Français';
      case 'en': return 'English';
      case 'sw': return 'Kiswahili';
      case 'ar': return 'العربية (RTL)';
      default: return 'Français';
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: MiighoColors.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary)),
        trailing: Icon(Icons.chevron_right_rounded, color: isDark ? MiighoColors.textMuted : MiighoColors.lightTextMuted),
        onTap: onTap,
      ),
    );
  }
}
