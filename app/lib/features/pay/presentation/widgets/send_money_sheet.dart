import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/colors.dart';
import '../bloc/pay_bloc.dart';
import '../../models/pay_models.dart';

class SendMoneySheet extends StatefulWidget {
  final WalletSummary wallet;

  const SendMoneySheet({super.key, required this.wallet});

  @override
  State<SendMoneySheet> createState() => _SendMoneySheetState();
}

class _SendMoneySheetState extends State<SendMoneySheet> {
  final _contactController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();

  int _step = 1; // 1: Saisie, 2: Confirmation
  String? _errorMessage;

  final List<Map<String, String>> _suggestedContacts = [
    {'name': 'Amina Diallo', 'id': 'MG-7731-SEN', 'phone': '+221 77 123 45 67'},
    {'name': 'Moussa Traoré', 'id': 'MG-4412-MLI', 'phone': '+223 66 987 65 43'},
    {'name': 'Paul Biya', 'id': 'MG-1290-CMR', 'phone': '+237 69 555 44 33'},
    {'name': 'Fatou Ndiaye', 'id': 'MG-8841-CIV', 'phone': '+225 05 111 22 33'},
  ];

  @override
  void dispose() {
    _contactController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _validateAndProceed() {
    setState(() => _errorMessage = null);
    final contact = _contactController.text.trim();
    final amountStr = _amountController.text.trim();

    if (contact.isEmpty) {
      setState(() => _errorMessage = 'Veuillez saisir un destinataire (MÏÏghO ID ou Téléphone).');
      return;
    }

    final amount = int.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Veuillez saisir un montant valide supérieur à 0.');
      return;
    }

    if (amount > widget.wallet.availableBalance) {
      setState(() => _errorMessage = 'Solde insuffisant (${widget.wallet.availableBalance} ${widget.wallet.currency} disponible).');
      return;
    }

    setState(() => _step = 2);
  }

  void _confirmAndSend() {
    final contact = _contactController.text.trim();
    final amount = int.parse(_amountController.text.trim());
    final desc = _descController.text.trim();

    context.read<PayBloc>().add(
          SendMoneyEvent(
            toContact: contact,
            amount: amount,
            currency: widget.wallet.currency,
            description: desc.isNotEmpty ? desc : null,
          ),
        );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? MiighoColors.surface1 : MiighoColors.lightSurface1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
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
            const SizedBox(height: 16),

            // Titre & Indicateur
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MiighoColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, color: MiighoColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _step == 1 ? 'Envoyer de l\'argent' : 'Confirmer le transfert',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: MiighoColors.goldAlpha,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'SANDBOX',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: MiighoColors.gold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MiighoColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MiighoColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: MiighoColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: MiighoColors.error, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (_step == 1) ...[
              // Destinataire
              Text(
                'Destinataire (MÏÏghO ID ou Téléphone)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _contactController,
                style: TextStyle(color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary),
                decoration: InputDecoration(
                  hintText: 'Ex: MG-7731-SEN ou +221...',
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                  filled: true,
                  fillColor: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),

              const SizedBox(height: 10),

              // Contacts suggérés
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _suggestedContacts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final c = _suggestedContacts[index];
                    return ActionChip(
                      label: Text(c['name']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      avatar: const Icon(Icons.person, size: 14),
                      backgroundColor: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface2,
                      onPressed: () {
                        setState(() {
                          _contactController.text = c['id']!;
                        });
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Montant
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Montant à envoyer (${widget.wallet.currency})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                    ),
                  ),
                  Text(
                    'Solde: ${widget.wallet.availableBalance} ${widget.wallet.currency}',
                    style: const TextStyle(fontSize: 11, color: MiighoColors.gold, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: MiighoColors.primary,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  suffixText: widget.wallet.currency,
                  suffixStyle: const TextStyle(fontWeight: FontWeight.w700, color: MiighoColors.primary),
                  prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                  filled: true,
                  fillColor: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),

              const SizedBox(height: 8),

              // Chips de montant rapide
              Row(
                children: [1000, 5000, 10000, 20000].map((amt) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text('+$amt', style: const TextStyle(fontSize: 11)),
                      backgroundColor: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface2,
                      onPressed: () {
                        final cur = int.tryParse(_amountController.text) ?? 0;
                        _amountController.text = (cur + amt).toString();
                      },
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Description (optionnel)
              Text(
                'Note / Motif (Optionnel)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _descController,
                style: TextStyle(color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary),
                decoration: InputDecoration(
                  hintText: 'Ex: Remboursement déjeuner, loyer...',
                  filled: true,
                  fillColor: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _validateAndProceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MiighoColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Continuer vers le récapitulatif →', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ] else ...[
              // Étape 2: Confirmation & Récapitulatif
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Destinataire', style: TextStyle(color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary)),
                        Text(_contactController.text, style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary)),
                      ],
                    ),
                    const Divider(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Montant', style: TextStyle(color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary)),
                        Text(
                          '${_amountController.text} ${widget.wallet.currency}',
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: MiighoColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Frais de réseau', style: TextStyle(color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary)),
                        const Text('0 FCFA (Gratuit P2P)', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                      ],
                    ),
                    const Divider(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Nouveau solde estimé', style: TextStyle(color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary)),
                        Text(
                          '${widget.wallet.availableBalance - int.parse(_amountController.text)} ${widget.wallet.currency}',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: MiighoColors.gold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MiighoColors.primaryAlpha,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: MiighoColors.primaryLight, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Écriture comptable en partie double (Double-Entry Ledger). Clé d\'idempotence garantie.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _step = 1),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Modifier'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _confirmAndSend,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MiighoColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Confirmer & Envoyer ✓', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
