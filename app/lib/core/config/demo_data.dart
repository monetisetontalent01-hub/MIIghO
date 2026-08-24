import 'package:flutter/material.dart';

class DemoUser {
  final String id;
  final String miighoId;
  final String displayName;
  final String phoneNumber;
  final String email;
  final String? avatarUrl;
  final String country;
  final String kycLevel;
  final bool isVerified;

  const DemoUser({
    required this.id,
    required this.miighoId,
    required this.displayName,
    required this.phoneNumber,
    required this.email,
    this.avatarUrl,
    required this.country,
    required this.kycLevel,
    required this.isVerified,
  });
}

class DemoTransaction {
  final String id;
  final String title;
  final String subtitle;
  final int amount; // En plus petite unité ou entier (FCFA)
  final String currency;
  final bool isCredit;
  final DateTime timestamp;
  final String type;
  final String status;
  final IconData icon;
  final Color iconColor;

  const DemoTransaction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.currency,
    required this.isCredit,
    required this.timestamp,
    required this.type,
    required this.status,
    required this.icon,
    required this.iconColor,
  });
}

class DemoDataProvider {
  static const bool isDemoMode = true;
  static const String environmentName = 'SANDBOX';

  // Demo User
  static const DemoUser currentUser = DemoUser(
    id: 'usr_demo_01',
    miighoId: 'MG-9824-CIV',
    displayName: 'Mamadou Koné',
    phoneNumber: '+225 07 00 00 00 00',
    email: 'mamadou.kone@miigho.africa',
    country: 'Côte d\'Ivoire 🇨🇮',
    kycLevel: 'Niveau 2 (Vérifié)',
    isVerified: true,
  );

  // Demo Wallet & Balance
  static const String defaultCurrency = 'FCFA';
  static const int availableBalance = 45000;
  static const int incomingMonthly = 1245000;
  static const int outgoingMonthly = 850000;
  static const int unreadMessageCount = 4;
  static const int pendingNotificationsCount = 2;

  // Demo Transactions (Sandbox)
  static List<DemoTransaction> getRecentTransactions() {
    final now = DateTime.now();
    return [
      DemoTransaction(
        id: 'tx_01',
        title: 'Recharge Wave CI',
        subtitle: 'Mobile Money • Sandbox',
        amount: 25000,
        currency: defaultCurrency,
        isCredit: true,
        timestamp: now.subtract(const Duration(hours: 3)),
        type: 'momo_cash_in',
        status: 'Complété (Sandbox)',
        icon: Icons.add_card_rounded,
        iconColor: const Color(0xFF10B981),
      ),
      DemoTransaction(
        id: 'tx_02',
        title: 'Transfert de Amina Diallo',
        subtitle: 'MÏÏghO Pay P2P',
        amount: 30000,
        currency: defaultCurrency,
        isCredit: true,
        timestamp: now.subtract(const Duration(days: 1)),
        type: 'p2p_transfer',
        status: 'Complété (Sandbox)',
        icon: Icons.arrow_downward_rounded,
        iconColor: const Color(0xFF3B82F6),
      ),
      DemoTransaction(
        id: 'tx_03',
        title: 'Commande Market (Escrow)',
        subtitle: 'Boutique Artisanat Sahel • En attente livraison',
        amount: 10000,
        currency: defaultCurrency,
        isCredit: false,
        timestamp: now.subtract(const Duration(days: 2)),
        type: 'marketplace_escrow',
        status: 'Fonds Séquestrés (Escrow)',
        icon: Icons.storefront_rounded,
        iconColor: const Color(0xFFF59E0B),
      ),
    ];
  }
}
