import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../bloc/pay_bloc.dart';
import '../../models/pay_models.dart';

class LedgerJournalScreen extends StatefulWidget {
  const LedgerJournalScreen({super.key});

  @override
  State<LedgerJournalScreen> createState() => _LedgerJournalScreenState();
}

class _LedgerJournalScreenState extends State<LedgerJournalScreen> {
  TransactionType? _selectedFilter;

  @override
  void initState() {
    super.initState();
    context.read<PayBloc>().add(LoadJournalEvent());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');

    return Scaffold(
      backgroundColor: isDark ? MiighoColors.canvas : MiighoColors.lightCanvas,
      appBar: AppBar(
        title: const Text('Journal des Écritures (Ledger)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: () => context.read<PayBloc>().add(LoadJournalEvent()),
          ),
        ],
      ),
      body: BlocBuilder<PayBloc, PayState>(
        builder: (context, state) {
          List<DetailedJournalEntry> journal = [];
          if (state is PayLoaded) {
            journal = state.journal;
          }

          final filtered = _selectedFilter == null
              ? journal
              : journal.where((j) => j.entry.transactionType == _selectedFilter).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Explication technique
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface1,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_tree_outlined, color: MiighoColors.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AUDIT DE COMPTABILITÉ EN PARTIE DOUBLE',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: MiighoColors.primaryLight, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Chaque écriture contient au moins deux écritures élémentaires (Débit & Crédit) respectant strictement l\'invariant Σ Débits = Σ Crédits.',
                            style: TextStyle(fontSize: 12, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Toutes'),
                      selected: _selectedFilter == null,
                      onSelected: (val) => setState(() => _selectedFilter = null),
                      backgroundColor: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface2,
                      selectedColor: MiighoColors.primary.withValues(alpha: 0.2),
                    ),
                    const SizedBox(width: 8),
                    ...TransactionType.values.map((type) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(type.label),
                          selected: _selectedFilter == type,
                          onSelected: (val) => setState(() => _selectedFilter = val ? type : null),
                          backgroundColor: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface2,
                          selectedColor: MiighoColors.primary.withValues(alpha: 0.2),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Aucune écriture comptable enregistrée pour ce filtre.',
                      style: TextStyle(color: isDark ? MiighoColors.textMuted : MiighoColors.lightTextMuted),
                    ),
                  ),
                )
              else
                ...filtered.map((j) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface1,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle),
                    ),
                    child: ExpansionTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 20),
                      ),
                      title: Text(
                        j.entry.description,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary),
                      ),
                      subtitle: Text(
                        'Ref: ${j.entry.referenceId} • ${dateFormat.format(j.entry.createdAt)}',
                        style: TextStyle(fontSize: 11, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
                      ),
                      trailing: Text(
                        '${j.totalDebit} FCFA',
                        style: const TextStyle(fontFamily: 'Space Grotesk', fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                      children: [
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Détail des Postings',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
                                  ),
                                  Text(
                                    'Invariant: Σ DR = Σ CR ✓',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...j.postings.map((p) {
                                final isDebit = p.direction == 'DEBIT';
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? MiighoColors.surface3 : MiighoColors.lightSurface2,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDebit ? const Color(0xFF3B82F6).withValues(alpha: 0.15) : const Color(0xFF10B981).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isDebit ? 'DR' : 'CR',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isDebit ? const Color(0xFF3B82F6) : const Color(0xFF10B981)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p.accountName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                            Text(p.accountType.label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${p.amount} ${p.currency}',
                                        style: const TextStyle(fontFamily: 'Space Grotesk', fontSize: 12, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}
