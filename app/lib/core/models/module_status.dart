import 'package:flutter/material.dart';
import '../theme/colors.dart';

enum ModuleStatus {
  active,
  beta,
  prototype,
  development,
  comingSoon;

  String get label {
    switch (this) {
      case ModuleStatus.active:
        return 'ACTIF';
      case ModuleStatus.beta:
        return 'BÊTA';
      case ModuleStatus.prototype:
        return 'PROTOTYPE';
      case ModuleStatus.development:
        return 'EN DÉVELOPPEMENT';
      case ModuleStatus.comingSoon:
        return 'BIENTÔT';
    }
  }

  Color get color {
    switch (this) {
      case ModuleStatus.active:
        return MiighoColors.statusActive;
      case ModuleStatus.beta:
        return MiighoColors.statusBeta;
      case ModuleStatus.prototype:
        return MiighoColors.statusPrototype;
      case ModuleStatus.development:
        return MiighoColors.statusDevelopment;
      case ModuleStatus.comingSoon:
        return MiighoColors.statusComingSoon;
    }
  }

  String get symbol {
    switch (this) {
      case ModuleStatus.active:
        return '●';
      case ModuleStatus.beta:
        return '◐';
      case ModuleStatus.prototype:
        return '◑';
      case ModuleStatus.development:
        return '○';
      case ModuleStatus.comingSoon:
        return '○';
    }
  }
}

class MiighoModuleInfo {
  final String id;
  final String name;
  final String code;
  final String descriptionKey;
  final IconData icon;
  final ModuleStatus status;
  final String route;
  final int phase;
  final bool isFeaturedInDashboard;

  const MiighoModuleInfo({
    required this.id,
    required this.name,
    required this.code,
    required this.descriptionKey,
    required this.icon,
    required this.status,
    required this.route,
    required this.phase,
    this.isFeaturedInDashboard = true,
  });

  static const List<MiighoModuleInfo> allModules = [
    MiighoModuleInfo(
      id: 'chat',
      name: 'MÏÏghO Chat',
      code: 'CHAT',
      descriptionKey: 'moduleChatDesc',
      icon: Icons.chat_bubble_outline_rounded,
      status: ModuleStatus.active,
      route: '/conversations',
      phase: 1,
    ),
    MiighoModuleInfo(
      id: 'pay',
      name: 'MÏÏghO Pay',
      code: 'PAY',
      descriptionKey: 'modulePayDesc',
      icon: Icons.account_balance_wallet_outlined,
      status: ModuleStatus.prototype,
      route: '/pay',
      phase: 2,
    ),
    MiighoModuleInfo(
      id: 'business',
      name: 'MÏÏghO Business',
      code: 'BIZ',
      descriptionKey: 'moduleBusinessDesc',
      icon: Icons.business_center_outlined,
      status: ModuleStatus.development,
      route: '/business',
      phase: 3,
    ),
    MiighoModuleInfo(
      id: 'market',
      name: 'MÏÏghO Market',
      code: 'MKT',
      descriptionKey: 'moduleMarketDesc',
      icon: Icons.storefront_outlined,
      status: ModuleStatus.comingSoon,
      route: '/market',
      phase: 4,
    ),
    MiighoModuleInfo(
      id: 'cloud',
      name: 'MÏÏghO Cloud',
      code: 'CLD',
      descriptionKey: 'moduleCloudDesc',
      icon: Icons.cloud_outlined,
      status: ModuleStatus.comingSoon,
      route: '/cloud',
      phase: 5,
    ),
    MiighoModuleInfo(
      id: 'media',
      name: 'MÏÏghO AI / MédIA',
      code: 'AI',
      descriptionKey: 'moduleMediaAIDesc',
      icon: Icons.auto_awesome_outlined,
      status: ModuleStatus.comingSoon,
      route: '/media',
      phase: 6,
    ),
    MiighoModuleInfo(
      id: 'dev',
      name: 'MÏÏghO Dev',
      code: 'DEV',
      descriptionKey: 'moduleDevDesc',
      icon: Icons.code_rounded,
      status: ModuleStatus.comingSoon,
      route: '/dev',
      phase: 7,
    ),
  ];
}
