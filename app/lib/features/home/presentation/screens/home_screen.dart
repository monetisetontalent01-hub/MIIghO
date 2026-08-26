import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/demo_data.dart';
import '../../../../core/models/module_status.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/l10n/miigho_strings.dart';
import '../../../../shared/widgets/miigho_avatar.dart';
import '../../../../shared/widgets/miigho_logo.dart';
import '../../../../shared/widgets/miigho_module_card.dart';
import '../../../../shared/widgets/miigho_status_badge.dart';
import '../../../pay/presentation/bloc/pay_bloc.dart';
import '../../../pay/models/pay_models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isBalanceVisible = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final strings = MiighoStrings.of(context);
    final user = DemoDataProvider.currentUser;
    final transactions = DemoDataProvider.getRecentTransactions();

    return Scaffold(
      backgroundColor: isDark ? MiighoColors.canvas : MiighoColors.lightCanvas,
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            const MiighoLogo(
              size: 32,
              variant: MiighoLogoVariant.markOnly,
            ),
            const SizedBox(width: 10),
            Text(
              'MÏÏghO OS',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: MiighoColors.primaryAlpha,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: MiighoColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'DEMO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: MiighoColors.primaryLight,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Basculer Thème',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 22,
              color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
            ),
            onPressed: () => context.read<ThemeCubit>().toggleTheme(),
          ),
          IconButton(
            tooltip: 'Recherche Globale',
            icon: Icon(
              Icons.search_rounded,
              size: 22,
              color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Recherche globale MÏÏghO (Bientôt disponible)'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: InkWell(
              onTap: () => context.push('/identity'),
              borderRadius: BorderRadius.circular(20),
              child: MiighoAvatar(
                name: user.displayName,
                size: MiighoAvatarSize.sm,
                isOnline: true,
                showPresenceIndicator: true,
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final crossAxisCount = constraints.maxWidth > 1100 ? 3 : (constraints.maxWidth > 650 ? 2 : 1);

          return RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 600));
            },
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 32 : 16,
                    vertical: 20,
                  ),
                  children: [
                // Section Bienvenue
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${strings.greeting}, ${user.displayName.split(' ').first}',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: isWide ? 28 : 22,
                            fontWeight: FontWeight.w800,
                            color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              user.miighoId,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: MiighoColors.gold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('•', style: TextStyle(color: Colors.grey)),
                            const SizedBox(width: 8),
                            Text(
                              user.kycLevel,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => context.push('/identity'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface2,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.qr_code_rounded, size: 16, color: MiighoColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Mon QR',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Carte Portefeuille & Solde (SANDBOX)
                _buildWalletCard(context, isDark, strings),

                const SizedBox(height: 20),

                // Raccourcis Activité & Messages
                _buildOverviewTiles(context, isDark, strings),

                const SizedBox(height: 28),

                // Section "Votre écosystème MÏÏghO"
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      strings.ecosystemTitle,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                      ),
                    ),
                    const MiighoStatusBadge(
                      status: ModuleStatus.active,
                      fontSize: 10,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Grille des Modules de l'écosystème
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 185,
                  ),
                  itemCount: MiighoModuleInfo.allModules.length,
                  itemBuilder: (context, index) {
                    final mod = MiighoModuleInfo.allModules[index];
                    String desc = '';
                    switch (mod.id) {
                      case 'chat': desc = strings.moduleChatDesc; break;
                      case 'pay': desc = strings.modulePayDesc; break;
                      case 'business': desc = strings.moduleBusinessDesc; break;
                      case 'market': desc = strings.moduleMarketDesc; break;
                      case 'cloud': desc = strings.moduleCloudDesc; break;
                      case 'media': desc = strings.moduleMediaAIDesc; break;
                      case 'dev': desc = strings.moduleDevDesc; break;
                    }
                    return MiighoModuleCard(
                      module: mod,
                      description: desc,
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Activité récente (Sandbox Transactions)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      strings.recentActivityTitle,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/pay'),
                      child: const Text('Voir tout'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ...transactions.map((tx) => _buildTransactionTile(context, tx, isDark)),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      );
    },
      ),
    );
  }

  Widget _buildWalletCard(BuildContext context, bool isDark, MiighoStrings strings) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1F1235), const Color(0xFF121B2F)]
              : [const Color(0xFFFAF5FF), const Color(0xFFF0F9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MiighoColors.primary.withValues(alpha: isDark ? 0.3 : 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: MiighoColors.primary.withValues(alpha: isDark ? 0.15 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
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
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: MiighoColors.goldAlpha,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: MiighoColors.gold,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    strings.walletBalanceTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  _isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                  color: isDark ? MiighoColors.textMuted : MiighoColors.lightTextMuted,
                ),
                onPressed: () {
                  setState(() {
                    _isBalanceVisible = !_isBalanceVisible;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          BlocBuilder<PayBloc, PayState>(
            builder: (context, payState) {
              int balance = 45000;
              String currency = 'FCFA';
              if (payState is PayLoaded) {
                balance = payState.wallet.availableBalance;
                currency = payState.wallet.currency;
              } else if (payState is PayActionInProgress && payState.currentWallet != null) {
                balance = payState.currentWallet!.availableBalance;
                currency = payState.currentWallet!.currency;
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _isBalanceVisible
                        ? balance.toString()
                        : '••••••',
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: MiighoColors.gold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currency,
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: MiighoColors.goldLight,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Actions rapides
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickActionBtn(
                context,
                icon: Icons.arrow_upward_rounded,
                label: strings.actionSend,
                color: MiighoColors.primary,
                onTap: () => context.push('/pay'),
              ),
              _buildQuickActionBtn(
                context,
                icon: Icons.arrow_downward_rounded,
                label: strings.actionReceive,
                color: const Color(0xFF10B981),
                onTap: () => context.push('/pay'),
              ),
              _buildQuickActionBtn(
                context,
                icon: Icons.add_card_rounded,
                label: strings.actionReload,
                color: MiighoColors.gold,
                onTap: () => context.push('/pay'),
              ),
              _buildQuickActionBtn(
                context,
                icon: Icons.qr_code_scanner_rounded,
                label: strings.actionScan,
                color: const Color(0xFF3B82F6),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Scanner QR Code (Sandbox Démo)'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.18 : 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTiles(BuildContext context, bool isDark, MiighoStrings strings) {
    return Row(
      children: [
        // Discussions non lues
        Expanded(
          child: InkWell(
            onTap: () => context.push('/conversations'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface1,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: MiighoColors.primaryAlpha,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: MiighoColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${DemoDataProvider.unreadMessageCount} ${strings.unreadMessages}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                          ),
                        ),
                        Text(
                          'Ouvrir Chat →',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: MiighoColors.primaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Contacts & Communauté
        Expanded(
          child: InkWell(
            onTap: () => context.push('/contacts'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface1,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0x1F10B981),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.people_outline_rounded,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contacts MÏÏghO',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                          ),
                        ),
                        const Text(
                          'Synchronisés ✓',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionTile(BuildContext context, DemoTransaction tx, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: tx.iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(tx.icon, color: tx.iconColor, size: 20),
        ),
        title: Text(
          tx.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
          ),
        ),
        subtitle: Text(
          tx.subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${tx.isCredit ? '+' : '-'}${tx.amount} ${tx.currency}',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: tx.isCredit ? const Color(0xFF10B981) : MiighoColors.error,
              ),
            ),
            Text(
              tx.status,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? MiighoColors.textMuted : MiighoColors.lightTextMuted,
              ),
            ),
          ],
        ),
        onTap: () => context.push('/pay'),
      ),
    );
  }
}
