import 'package:flutter/material.dart';
import '../../../../core/config/demo_data.dart';
import '../../../../core/models/module_status.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/miigho_status_badge.dart';

class PayScreen extends StatelessWidget {
  const PayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final transactions = DemoDataProvider.getRecentTransactions();

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
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Journal des écritures',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scanner pour payer',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Scanner QR MÏÏghO Pay (Sandbox)')),
              );
            },
          ),
        ],
      ),
      body: ListView(
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
                        'Toutes les transactions affichées sont simulées. Le système s\'appuie sur une architecture de comptabilité en partie double (Ledger).',
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

          // Carte Solde Portefeuille
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
                      'COMPTE PRINCIPAL (XOF / FCFA)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.8),
                        letterSpacing: 0.6,
                      ),
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
                const SizedBox(height: 12),
                const Text(
                  '45 000 FCFA',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Équivalent ~68.60 EUR • Ledger ID: ACC-9824-01',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 16),

                // Boutons d'actions financières simulées
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPayAction(context, Icons.arrow_upward_rounded, 'Envoyer', Colors.white),
                    _buildPayAction(context, Icons.arrow_downward_rounded, 'Recevoir', Colors.white),
                    _buildPayAction(context, Icons.add_card_rounded, 'Recharger', Colors.white),
                    _buildPayAction(context, Icons.account_balance_rounded, 'Retirer', Colors.white),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Architecture Ledger Information
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface1,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_tree_outlined, color: MiighoColors.primaryLight, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Architecture Double-Entry Ledger (Phase 2)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Le solde n\'est jamais incrémenté directement (pas de wallet.balance += x). Toutes les écritures sont traçables, immuables et auditables (Comptes Actifs, Passifs, Produits, Charges).',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Historique des écritures simulées
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
                'Sandbox Data',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? MiighoColors.textMuted : MiighoColors.lightTextMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ...transactions.map((tx) => _buildTransactionItem(context, tx, isDark)),
        ],
      ),
    );
  }

  Widget _buildPayAction(BuildContext context, IconData icon, String label, Color color) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action "$label" en mode démonstration Sandbox.'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
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
    );
  }

  Widget _buildTransactionItem(BuildContext context, DemoTransaction tx, bool isDark) {
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
          '${tx.subtitle} • ${tx.status}',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
          ),
        ),
        trailing: Text(
          '${tx.isCredit ? '+' : '-'}${tx.amount} ${tx.currency}',
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: tx.isCredit ? const Color(0xFF10B981) : MiighoColors.error,
          ),
        ),
      ),
    );
  }
}
