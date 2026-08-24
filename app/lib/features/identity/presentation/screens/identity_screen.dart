import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/miigho_avatar.dart';
import '../bloc/identity_bloc.dart';
import '../data/identity_repository.dart';

class IdentityScreen extends StatelessWidget {
  const IdentityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? MiighoColors.canvas : MiighoColors.lightCanvas,
      appBar: AppBar(
        title: const Text('MÏÏghO Identity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier mon profil',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _EditProfileWrapper()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Partager mon MÏÏghO ID',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Partage de votre MÏÏghO ID')),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<IdentityBloc, IdentityState>(
        builder: (context, state) {
          if (state is IdentityLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          UserProfile profile;
          List<UserSession> sessions = [];

          if (state is IdentityLoaded) {
            profile = state.profile;
            sessions = state.sessions;
          } else {
            profile = const UserProfile(
              id: 'usr_demo_01',
              miighoId: 'MG-9824-CIV',
              displayName: 'Mamadou Koné',
              phoneNumber: '+225 07 00 00 00 00',
              email: 'mamadou.kone@miigho.africa',
              bio: 'Pionnier MÏÏghO • Construisons l\'écosystème numérique africain.',
              country: 'Côte d\'Ivoire 🇨🇮',
              kycLevel: 'Niveau 2 (Vérifié)',
              isVerified: true,
              createdAt: null as dynamic,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Carte d'Identité Souveraine MÏÏghO
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF4C1D95), const Color(0xFF1E1B4B)]
                        : [const Color(0xFF7C3AED), const Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'IDENTITÉ NUMÉRIQUE PANAFRICAINE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(alpha: 0.85),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: MiighoColors.gold,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'VÉRIFIÉ',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        MiighoAvatar(
                          name: profile.displayName,
                          size: MiighoAvatarSize.lg,
                          isOnline: true,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profile.miighoId,
                                style: const TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  color: MiighoColors.goldLight,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                profile.country,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 36),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '"${profile.bio}"',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Une Identité • Un Écosystème',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                        Text(
                          profile.kycLevel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              _buildSectionHeader('INFORMATIONS DU COMPTE'),
              _buildInfoTile(
                context,
                icon: Icons.phone_outlined,
                title: 'Numéro de téléphone souverain',
                value: profile.phoneNumber,
                isDark: isDark,
              ),
              _buildInfoTile(
                context,
                icon: Icons.email_outlined,
                title: 'Adresse email',
                value: profile.email,
                isDark: isDark,
              ),
              _buildInfoTile(
                context,
                icon: Icons.location_on_outlined,
                title: 'Pays de rattachement',
                value: profile.country,
                isDark: isDark,
              ),

              const SizedBox(height: 20),

              _buildSectionHeader('SERVICES ÉCOSYSTÈME AUTORISÉS AVEC CE MÏÏghO ID'),
              _buildServiceTile('MÏÏghO Chat', 'Messagerie & Appels sécurisés', Icons.chat_bubble_outline, true, isDark),
              _buildServiceTile('MÏÏghO Pay', 'Portefeuille Sandbox & Ledger', Icons.account_balance_wallet_outlined, true, isDark),
              _buildServiceTile('MÏÏghO Business', 'Suite SaaS Entreprise', Icons.business_center_outlined, false, isDark),
              _buildServiceTile('MÏÏghO Market', 'Profil Marketplace & Escrow', Icons.storefront_outlined, false, isDark),

              const SizedBox(height: 20),

              _buildSectionHeader('SÉCURITÉ & SESSIONS ACTIVES (${sessions.length})'),
              ...sessions.map((s) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface1,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle,
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        s.platform.contains('iOS') ? Icons.phone_iphone_rounded : Icons.laptop_mac_rounded,
                        color: s.isCurrent ? const Color(0xFF10B981) : MiighoColors.primary,
                        size: 24,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.deviceName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                              ),
                            ),
                          ),
                          if (s.isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0x1F10B981),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ACTIF',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        '${s.platform} • IP: ${s.ipAddress}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                        ),
                      ),
                      trailing: s.isCurrent
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: MiighoColors.error, size: 18),
                              tooltip: 'Révoquer session',
                              onPressed: () {
                                context.read<IdentityBloc>().add(RevokeSessionEvent(s.id));
                              },
                            ),
                    ),
                  )),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
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

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    Widget? trailing,
    required bool isDark,
    VoidCallback? onTap,
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
        leading: Icon(icon, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary, size: 20),
        title: Text(title, style: TextStyle(fontSize: 12, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary)),
        subtitle: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary)),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Widget _buildServiceTile(String name, String desc, IconData icon, bool isGranted, bool isDark) {
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
        leading: Icon(icon, color: isGranted ? MiighoColors.primary : Colors.grey, size: 22),
        title: Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary)),
        subtitle: Text(desc, style: TextStyle(fontSize: 12, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary)),
        trailing: Icon(
          isGranted ? Icons.check_circle_rounded : Icons.pending_outlined,
          color: isGranted ? const Color(0xFF10B981) : Colors.grey,
          size: 20,
        ),
      ),
    );
  }
}

class _EditProfileWrapper extends StatelessWidget {
  const _EditProfileWrapper();

  @override
  Widget build(BuildContext context) {
    return const EditProfileScreen();
  }
}
