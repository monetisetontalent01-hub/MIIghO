import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../../models/pay_models.dart';

class TransactionDetailScreen extends StatelessWidget {
  final DetailedJournalEntry detail;

  const TransactionDetailScreen({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final entry = detail.entry;
    final dateFormat = DateFormat('dd MMMM yyyy à HH:mm');

    return Scaffold(
      backgroundColor: isDark ? MiighoColors.canvas : MiighoColors.lightCanvas,
      appBar: AppBar(
        title: const Text('Détail de l\'opération'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Partager le reçu',
            onPressed: () {
              Clipboard.setData(ClipboardData(
                text: 'MÏÏghO Pay Reçu\nOpération: ${entry.description}\nRef: ${entry.referenceId}\nMontant: ${detail.totalDebit} FCFA\nDate: ${dateFormat.format(entry.createdAt)}\nStatut: ${detail.status.label}',
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reçu copié dans le presse-papiers (Sandbox)')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface1,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: detail.status.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle_outline_rounded, color: detail.status.color, size: 36),
                ),
                const SizedBox(height: 12),
                Text(
                  '${detail.totalDebit} FCFA',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  entry.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: detail.status.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    detail.status.label,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: detail.status.color),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Informations générales
          Text(
            'Informations de transaction',
            style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary),
          ),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface1,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle),
            ),
            child: Column(
              children: [
                _buildInfoRow('Type d\'opération', entry.transactionType.label, isDark),
                const Divider(height: 1),
                _buildInfoRow('Référence unique', entry.referenceId, isDark),
                const Divider(height: 1),
                _buildInfoRow('Horodatage', dateFormat.format(entry.createdAt), isDark),
                const Divider(height: 1),
                _buildInfoRow('Journal Entry ID', entry.id, isDark, isCode: true),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section Audit Ledger Double-Entry
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Écritures Comptables (Ledger)',
                style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.shield_outlined, size: 12, color: Color(0xFF10B981)),
                    SizedBox(width: 4),
                    Text('ÉQUILIBRÉ Σ DR = Σ CR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ...detail.postings.map((p) => _buildPostingCard(p, isDark)),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark, {bool isCode = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: isCode ? 'monospace' : null,
                color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostingCard(DetailedLedgerPosting p, bool isDark) {
    final isDebit = p.direction == 'DEBIT';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: (isDebit ? const Color(0xFF3B82F6) : const Color(0xFF10B981)).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isDebit ? 'DÉBIT' : 'CRÉDIT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isDebit ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.accountName,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary),
                ),
                Text(
                  'Compte ${p.accountType.label} • ${p.accountId.substring(0, 12)}...',
                  style: TextStyle(fontSize: 11, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
                ),
              ],
            ),
          ),
          Text(
            '${p.amount} ${p.currency}',
            style: const TextStyle(fontFamily: 'Space Grotesk', fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
