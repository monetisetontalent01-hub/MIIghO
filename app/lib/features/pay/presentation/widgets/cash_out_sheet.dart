import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/colors.dart';
import '../bloc/pay_bloc.dart';
import '../../models/pay_models.dart';

class CashOutSheet extends StatefulWidget {
  final WalletSummary wallet;

  const CashOutSheet({super.key, required this.wallet});

  @override
  State<CashOutSheet> createState() => _CashOutSheetState();
}

class _CashOutSheetState extends State<CashOutSheet> {
  String _selectedProvider = 'wave';
  final _phoneController = TextEditingController(text: '+225 07 00 00 00 00');
  final _amountController = TextEditingController(text: '5000');
  String? _errorMessage;

  final List<Map<String, dynamic>> _providers = [
    {'id': 'wave', 'name': 'Wave CI / SN', 'icon': Icons.waves_rounded, 'color': Color(0xFF00A4FF)},
    {'id': 'orange_money', 'name': 'Orange Money', 'icon': Icons.circle, 'color': Color(0xFFFF7900)},
    {'id': 'mtn_momo', 'name': 'MTN MoMo', 'icon': Icons.phone_android_rounded, 'color': Color(0xFFFFCC00)},
    {'id': 'moov_money', 'name': 'Moov Money', 'icon': Icons.bolt_rounded, 'color': Color(0xFF005BA6)},
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submitCashOut() {
    setState(() => _errorMessage = null);
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Veuillez saisir un montant valide supérieur à 0.');
      return;
    }

    if (amount > widget.wallet.availableBalance) {
      setState(() => _errorMessage = 'Solde insuffisant (${widget.wallet.availableBalance} ${widget.wallet.currency} disponible).');
      return;
    }

    context.read<PayBloc>().add(
          CashOutEvent(
            provider: _selectedProvider,
            phoneNumber: _phoneController.text.trim(),
            amount: amount,
            currency: widget.wallet.currency,
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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MiighoColors.error.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_rounded, color: MiighoColors.error, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Retirer vers Mobile Money',
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
                  child: const Text('SANDBOX', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: MiighoColors.gold)),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: const TextStyle(color: MiighoColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
            ],

            Text(
              'Choisir l\'opérateur de retrait',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _providers.map((p) {
                final isSelected = _selectedProvider == p['id'];
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(p['icon'] as IconData, size: 16, color: isSelected ? Colors.white : p['color'] as Color),
                      const SizedBox(width: 6),
                      Text(p['name'] as String),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: MiighoColors.primary,
                  backgroundColor: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface2,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : (isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary),
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedProvider = p['id'] as String);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            Text(
              'Numéro Mobile Money destinataire',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                filled: true,
                fillColor: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Montant du retrait (${widget.wallet.currency})',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
                ),
                Text(
                  'Max: ${widget.wallet.availableBalance} ${widget.wallet.currency}',
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
                color: MiighoColors.error,
              ),
              decoration: InputDecoration(
                suffixText: widget.wallet.currency,
                prefixIcon: const Icon(Icons.arrow_circle_down_rounded, size: 20),
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
                onPressed: _submitCashOut,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MiighoColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Confirmer le retrait (Sandbox) ✓', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
