import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/colors.dart';
import '../bloc/pay_bloc.dart';
import '../../models/pay_models.dart';

class PayQRSheet extends StatefulWidget {
  final WalletSummary wallet;
  final int initialTabIndex;

  const PayQRSheet({
    super.key,
    required this.wallet,
    this.initialTabIndex = 0,
  });

  @override
  State<PayQRSheet> createState() => _PayQRSheetState();
}

class _PayQRSheetState extends State<PayQRSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Scanner / Merchant tab state
  final _amountController = TextEditingController(text: '2500');
  String _selectedMerchant = 'Pharmacie Centrale Abidjan';
  String? _errorMessage;

  final List<Map<String, String>> _testMerchants = [
    {'name': 'Pharmacie Centrale Abidjan', 'id': 'MG-PHARM-CIV', 'code': 'miigho://pay?to=Pharmacie_Centrale_Abidjan&amount=2500'},
    {'name': 'Boutique Artisanat Sahel', 'id': 'MG-SAHEL-BFA', 'code': 'miigho://pay?to=Boutique_Artisanat_Sahel&amount=10000'},
    {'name': 'Supermarché Étoile Dakar', 'id': 'MG-ETOILE-SEN', 'code': 'miigho://pay?to=Supermarche_Etoile_Dakar&amount=15000'},
    {'name': 'Station TotalEnergies Cocody', 'id': 'MG-TOTAL-CIV', 'code': 'miigho://pay?to=Station_Total_Cocody&amount=5000'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submitQRPay() {
    setState(() => _errorMessage = null);
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Veuillez saisir un montant supérieur à 0.');
      return;
    }

    if (amount > widget.wallet.availableBalance) {
      setState(() => _errorMessage = 'Solde insuffisant (${widget.wallet.availableBalance} ${widget.wallet.currency} disponible).');
      return;
    }

    final merchantObj = _testMerchants.firstWhere((m) => m['name'] == _selectedMerchant);
    context.read<PayBloc>().add(
          QRPayEvent(
            qrData: merchantObj['code']!,
            amount: amount,
            currency: widget.wallet.currency,
            description: 'Paiement QR • $_selectedMerchant',
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
            const SizedBox(height: 14),

            // Tab bar
            Container(
              decoration: BoxDecoration(
                color: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: MiighoColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                tabs: const [
                  Tab(text: 'Mon QR Code (Recevoir)'),
                  Tab(text: 'Scanner pour Payer'),
                ],
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              height: 420,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Mon QR Code (Recevoir)
                  _buildReceiveTab(context, isDark),

                  // Tab 2: Scanner pour payer
                  _buildScanPayTab(context, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiveTab(BuildContext context, bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          'Présentez ce QR Code pour recevoir un paiement direct',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
        ),
        const SizedBox(height: 16),

        // QR Code Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.qr_code_2_rounded, size: 140, color: Colors.white),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.wallet.miighoId,
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF0F172A),
                  letterSpacing: 1.0,
                ),
              ),
              const Text(
                'Mamadou Koné • MÏÏghO Pay',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copier ID'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.wallet.miighoId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('MÏÏghO ID copié dans le presse-papiers')),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Partager'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MiighoColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lien de paiement MÏÏghO partagé (Sandbox)')),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScanPayTab(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          if (_errorMessage != null) ...[
            Text(_errorMessage!, style: const TextStyle(color: MiighoColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
          ],

          Text(
            'Sélectionnez un commerçant Sandbox à payer',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedMerchant,
                isExpanded: true,
                dropdownColor: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface1,
                items: _testMerchants.map((m) {
                  return DropdownMenuItem<String>(
                    value: m['name']!,
                    child: Text(
                      m['name']!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedMerchant = val;
                    });
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Montant à régler (${widget.wallet.currency})',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
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
              color: Color(0xFF3B82F6),
            ),
            decoration: InputDecoration(
              suffixText: widget.wallet.currency,
              prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
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
              onPressed: _submitQRPay,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Confirmer le paiement QR (Sandbox) ✓', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}
