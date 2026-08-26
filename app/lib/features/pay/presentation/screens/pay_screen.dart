import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/module_status.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/miigho_status_badge.dart';
import '../bloc/pay_bloc.dart';
import '../../models/pay_models.dart';
import '../widgets/send_money_sheet.dart';
import '../widgets/cash_in_sheet.dart';
import '../widgets/cash_out_sheet.dart';
import '../widgets/pay_qr_sheet.dart';
import 'transaction_detail_screen.dart';

class PayScreen extends StatefulWidget {
  const PayScreen({super.key});

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  bool _isBalanceVisible = true;

  @override
  void initState() {
    super.initState();
    context.read<PayBloc>().add(LoadPayWallet());
  }

  void _openSendSheet(BuildContext context, WalletSummary wallet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SendMoneySheet(wallet: wallet),
    );
  }

  void _openCashInSheet(BuildContext context, WalletSummary wallet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CashInSheet(wallet: wallet),
    );
  }

  void _openCashOutSheet(BuildContext context, WalletSummary wallet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CashOutSheet(wallet: wallet),
    );
  }

  void _openQRSheet(BuildContext context, WalletSummary wallet, {int initialTab = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PayQRSheet(wallet: wallet, initialTabIndex: initialTab),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final numberFormat = NumberFormat('#,###', 'fr_FR');

    return BlocConsumer<PayBloc, PayState>(
      listener: (context, state) {
        if (state is PayLoaded && state.actionSuccessMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.actionSuccessMessage!)),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 4),
            ),
          );
        } else if (state is PayError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.message)),
                ],
              ),
              backgroundColor: MiighoColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      builder: (context, state) {
        WalletSummary? wallet;
        List<UserTransactionItem> transactions = [];
        bool isLoading = (state is PayLoading);
        bool isProcessing = (state is PayActionInProgress);

        if (state is PayLoaded) {
          wallet = state.wallet;
          transactions = state.transactions;
        } else if (state is PayActionInProgress) {
          wallet = state.currentWallet;
          transactions = state.currentTransactions ?? [];
        } else if (state is PayError) {
          wallet = state.currentWallet;
          transactions = state.currentTransactions ?? [];
        }

        // Fallback placeholder wallet while initial loading
        wallet ??= WalletSummary(
          accountId: 'loading',
          userId: 'loading',
          miighoId: 'MG-9824-CIV',
          currency: 'FCFA',
          availableBalance: 0,
          pendingBalance: 0,
          totalIncoming: 0,
          totalOutgoing: 0,
          isSandbox: true,
          lastUpdated: DateTime.now(),
        );

        final currentWallet = wallet;

        return Scaffold(
          backgroundColor: isDark ? MiighoColors.canvas : MiighoColors.lightCanvas,
          appBar: AppBar(
            title: Row(
              children: [
                const Text('MÏÏghO Pay'),
                const SizedBox(width: 8),
                const MiighoStatusBadge(status: ModuleStatus.prototype, fontSize: 10),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.history_edu_rounded),
                tooltip: 'Journal d\'audit (Ledger)',
                onPressed: () => context.push('/pay/journal'),
              ),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded),
                tooltip: 'Scanner pour payer',
                onPressed: () => _openQRSheet(context, currentWallet, initialTab: 1),
              ),
            ],
          ),
          body: Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  context.read<PayBloc>().add(LoadPayWallet(refresh: true));
                },
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                    // Bannière d'avertissement PROTOTYPE / SANDBOX
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MiighoColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: MiighoColors.gold.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: MiighoColors.gold, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ENVIRONNEMENT DE DÉMONSTRATION SANDBOX',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: MiighoColors.gold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Toutes les transactions sont simulées et auditables en partie double (Double-Entry Ledger). Aucun PSP réel n\'est débité.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Carte Solde Portefeuille Dynamique
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                              : [const Color(0xFF7C3AED), const Color(0xFF6D28D9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: MiighoColors.primary.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'COMPTE PRINCIPAL (${currentWallet.currency})',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  letterSpacing: 0.6,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      color: Colors.white70,
                                      size: 18,
                                    ),
                                    onPressed: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'ACTIF',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isBalanceVisible
                                ? '${numberFormat.format(currentWallet.availableBalance)} ${currentWallet.currency}'
                                : '•••••• ${currentWallet.currency}',
                            style: const TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Équivalent ~${(currentWallet.availableBalance / 655.957).toStringAsFixed(2)} EUR • Ledger: ${currentWallet.accountId}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 16),

                          // Boutons d'actions financières interactifs
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildPayAction(
                                context,
                                Icons.arrow_upward_rounded,
                                'Envoyer',
                                Colors.white,
                                () => _openSendSheet(context, currentWallet!),
                              ),
                              _buildPayAction(
                                context,
                                Icons.arrow_downward_rounded,
                                'Recevoir',
                                Colors.white,
                                () => _openQRSheet(context, currentWallet!, initialTab: 0),
                              ),
                              _buildPayAction(
                                context,
                                Icons.add_card_rounded,
                                'Recharger',
                                Colors.white,
                                () => _openCashInSheet(context, currentWallet!),
                              ),
                              _buildPayAction(
                                context,
                                Icons.account_balance_rounded,
                                'Retirer',
                                Colors.white,
                                () => _openCashOutSheet(context, currentWallet!),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Carte Information Architecture Double-Entry
                    InkWell(
                      onTap: () => context.push('/pay/journal'),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
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
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: MiighoColors.primaryAlpha,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.history_edu_rounded, color: MiighoColors.primary, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Journal d\'audit comptable',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: MiighoColors.primary),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Consultez les écritures brutes Débit/Crédit et vérifiez l\'équilibre du système.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Historique des opérations
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Historique des opérations',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                          ),
                        ),
                        Text(
                          '${transactions.length} écritures',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? MiighoColors.textMuted : MiighoColors.lightTextMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (transactions.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Aucune transaction enregistrée.',
                            style: TextStyle(color: isDark ? MiighoColors.textMuted : MiighoColors.lightTextMuted),
                          ),
                        ),
                      )
                    else
                      ...transactions.map((tx) => _buildTransactionItem(context, tx, isDark)),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

              // Overlay indicateur de traitement en cours
              if (isProcessing)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      decoration: BoxDecoration(
                        color: isDark ? MiighoColors.surface1 : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            (state as PayActionInProgress).actionLabel,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPayAction(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, UserTransactionItem tx, bool isDark) {
    final dateFormat = DateFormat('dd MMM à HH:mm');

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
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: tx.iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
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
          '${dateFormat.format(tx.createdAt)} • ${tx.subtitle}',
          style: TextStyle(
            fontSize: 11,
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
            const SizedBox(height: 2),
            Text(
              tx.status.label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: tx.status.color,
              ),
            ),
          ],
        ),
        onTap: () async {
          final repo = context.read<PayBloc>().repository;
          final detail = await repo.getTransactionDetail(tx.journalEntryId);
          if (context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TransactionDetailScreen(detail: detail),
              ),
            );
          }
        },
      ),
    );
  }
}
