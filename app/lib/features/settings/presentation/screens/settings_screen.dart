import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/miigho_avatar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: ListView(
        children: [
          // Carte Profil Utilisateur
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6B21A8), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6B21A8).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const MiighoAvatar(
                  name: 'Utilisateur MÏÏghO',
                  size: MiighoAvatarSize.lg,
                  isOnline: true,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Mamadou Koné',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '+225 07 00 00 00 00',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Disponible sur MÏÏghO',
                        style: TextStyle(
                          color: Color(0xFFFDE68A),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_rounded, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // Section MÏÏghO Pay
          _buildSectionHeader('MÏÏghO PAY & SERVICES'),
          _buildSettingsTile(
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFFF59E0B),
            title: 'Portefeuille & Mobile Money',
            subtitle: 'Solde: 45 000 FCFA • Wave, Orange, MTN',
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: Icons.storefront_rounded,
            color: const Color(0xFF10B981),
            title: 'MÏÏghO Market',
            subtitle: 'Gérer ma boutique et mes annonces',
            onTap: () {},
          ),

          const Divider(height: 24, thickness: 4, color: Color(0x0A000000)),

          // Section Sécurité & Compte
          _buildSectionHeader('COMPTE & SÉCURITÉ'),
          _buildSettingsTile(
            icon: Icons.lock_outline_rounded,
            color: const Color(0xFF3B82F6),
            title: 'Confidentialité & Chiffrement',
            subtitle: 'Chiffrement de bout en bout actif (Signal Protocol)',
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: Icons.notifications_none_rounded,
            color: const Color(0xFFEC4899),
            title: 'Notifications & Sons',
            subtitle: 'Messages, groupes et appels',
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: Icons.language_rounded,
            color: const Color(0xFF8B5CF6),
            title: 'Langue de l\'application',
            subtitle: 'Français (Swahili, Wolof, Yoruba disponibles)',
            onTap: () {},
          ),

          const Divider(height: 24, thickness: 4, color: Color(0x0A000000)),

          // Section À propos
          _buildSectionHeader('À PROPOS'),
          _buildSettingsTile(
            icon: Icons.info_outline_rounded,
            color: Colors.grey,
            title: 'MÏÏghO OS v1.0',
            subtitle: 'Écosystème Numérique Panafricain • Horizon 2036',
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: Icons.logout_rounded,
            color: Colors.red,
            title: 'Déconnexion',
            subtitle: 'Se déconnecter de ce compte',
            onTap: () {
              context.go('/welcome');
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        selectedItemColor: MiighoColors.primary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_rounded), label: 'Discussions'),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Contacts'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Paramètres'),
        ],
        onTap: (index) {
          if (index == 0) context.go('/conversations');
          if (index == 1) context.go('/contacts');
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
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
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      onTap: onTap,
    );
  }
}
