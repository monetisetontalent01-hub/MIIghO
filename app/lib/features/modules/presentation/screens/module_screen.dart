import 'package:flutter/material.dart';
import '../../../../core/models/module_status.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/miigho_status_badge.dart';

class ModuleScreen extends StatelessWidget {
  final String moduleId;

  const ModuleScreen({super.key, required this.moduleId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final module = MiighoModuleInfo.allModules.firstWhere(
      (m) => m.id == moduleId,
      orElse: () => MiighoModuleInfo.allModules.first,
    );

    return Scaffold(
      backgroundColor: isDark ? MiighoColors.canvas : MiighoColors.lightCanvas,
      appBar: AppBar(
        title: Text(module.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: MiighoStatusBadge(status: module.status),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // En-tête Module
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: module.status.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: module.status.color.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(module.icon, color: module.status.color, size: 40),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              module.name,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: MiighoColors.primaryAlpha,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Phase ${module.phase} de la Roadmap MÏÏghO',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MiighoColors.primaryLight,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Carte Statut & Honnêteté de vision
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
                    const Icon(Icons.architecture_rounded, color: MiighoColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Architecture Cible & Vision',
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
                  _getModuleTargetArchitecture(module.id),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Fonctionnalités planifiées
          Text(
            'Fonctionnalités au programme :',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),

          ..._getModuleFeatures(module.id).map((feat) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface1,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.radio_button_unchecked_rounded, size: 16, color: MiighoColors.primaryLight),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        feat,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              )),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _getModuleTargetArchitecture(String id) {
    switch (id) {
      case 'business':
        return 'MÏÏghO Business est conçu comme une suite SaaS B2B souveraine intégrée à MÏÏghO Identity et au Ledger MÏÏghO Pay pour la facturation certifiée et les encaissements multidevises.';
      case 'market':
        return 'MÏÏghO Market est une marketplace panafricaine avec gestion des dépôts sous séquestre (Escrow) reliée aux comptes de passif du Ledger MÏÏghO Pay.';
      case 'cloud':
        return 'MÏÏghO Cloud est une infrastructure de stockage souveraine basée sur le protocole S3 (MinIO / Object Storage) et le chiffrement côté client.';
      case 'media':
        return 'MÏÏghO AI / MédIA représente la future couche d\'intelligence artificielle générative contextualisée pour les langues et réalités socio-économiques africaines.';
      case 'dev':
        return 'MÏÏghO Dev est la plateforme de développement exposant les APIs REST / gRPC v1, les SDKs mobiles et les webhooks pour les développeurs tiers.';
      default:
        return 'Module planifié dans la roadmap de l\'écosystème souverain MÏÏghO.';
    }
  }

  List<String> _getModuleFeatures(String id) {
    switch (id) {
      case 'business':
        return [
          'Émission et suivi de factures certifiées',
          'Catalogue de produits & gestion de stock',
          'QR Code de paiement marchand MÏÏghO Pay',
          'Rapports de ventes et export comptable',
          'Gestion des accès employés et rôles d\'équipe',
        ];
      case 'market':
        return [
          'Catalogue de produits & recherche géolocalisée',
          'Panier d\'achat & commande en un clic',
          'Paiement sécurisé avec séquestre Escrow',
          'Suivi de livraison et confirmation de réception',
          'Libération automatique des fonds après validation',
        ];
      case 'cloud':
        return [
          'Stockage de documents personnels et professionnels',
          'Partage sécurisé par lien avec date d\'expiration',
          'Chiffrement de bout en bout des fichiers sensibles',
          'Recherche et indexation intelligente',
          'Corbeille avec rétention et historique des versions',
        ];
      case 'media':
        return [
          'Assistant conversationnel généraliste',
          'Support des langues africaines (Swahili, Wolof, Yoruba, etc.)',
          'Assistant Business (aide à la rédaction de devis et factures)',
          'Assistant Dev (documentation interactive et code snippets)',
          'Modèles IA sécurisés et respectueux de la vie privée',
        ];
      case 'dev':
        return [
          'Documentation interactive des APIs /v1/identity, /v1/chat, /v1/pay',
          'Génération de clés d\'API Sandbox et Production',
          'SDKs Flutter, Go, TypeScript et Python',
          'Console de test et simulateur de Webhooks',
          'Logs d\'appels API et monitoring d\'usage',
        ];
      default:
        return ['Spécifications en cours de finalisation'];
    }
  }
}
