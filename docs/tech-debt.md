# Registre de la Dette Technique (MVP)

Ce document trace les raccourcis architecturaux pris pour le lancement rapide du MVP et le plan pour les résoudre.

| ID | Décision | Raison MVP | Impact | Risque | Plan de Migration | Priorité |
|---|---|---|---|---|---|---|
| TD-01 | Instance PostgreSQL unique | Simplicité de déploiement et de maintenance | Pas de haute disponibilité | Arrêt de service si crash | Mise en place d'un cluster HA (Patroni/Stolon) | Haute |
| TD-02 | Pas de chiffrement E2E | Complexité d'implémentation du protocole Signal | Messages lisibles par le backend | Fuite en cas de compromission serveur | Intégration de libsignal, déploiement Phase 2 | Haute |
| TD-03 | Monolithe binaire | Facilité de développement, de test et de CI/CD | Couplage au déploiement | Ralentissement des builds à grande échelle | Extraction progressive en microservices si trafic exigeant | Moyenne |
| TD-04 | Pas de ScyllaDB (PG pour les messages) | Limiter les technologies de stockage | Contention sur les écritures à très forte charge | Scalabilité limitée pour le chat massif | Migration de la table des messages vers ScyllaDB/Cassandra | Basse |
| TD-05 | Pas de fallback USSD/SMS | Focus sur l'app riche (data) | Exclut les feature phones (2G) | Perte d'adoption dans zones rurales | Intégration d'une gateway USSD | Moyenne |
| TD-06 | Pas d'intégration PSP (Interfaces only) | Produit messagerie prioritaire sur paiements | Pas de transactions réelles possibles | Aucun pour le chat | Implémenter les adaptateurs Stripe, Flutterwave, Paystack | Haute |
| TD-07 | Déploiement Mono-région | Coûts d'infrastructure réduits | Latence plus élevée pour certains pays | Mauvaise UX réseau | Déploiement multi-région, GSLB, Read-Replicas | Moyenne |
| TD-08 | Pas de CDN pour les médias | Réduire la surface d'infrastructure initiale | Lenteur au téléchargement d'images/vidéos | Frustration utilisateur | Configuration AWS CloudFront / Cloudflare devant MinIO | Haute |
| TD-09 | Pas de dashboard admin | Focus exclusif sur l'app client final | Gestion manuelle ou via requêtes SQL brutes | Erreurs humaines d'opérations | Création d'une interface React/Vue d'administration | Moyenne |
| TD-10 | Rate limiting basique via Valkey | Facilité de mise en œuvre | Vulnérable aux attaques volumétriques complexes | DoS par bots massifs | Mise en place d'un WAF cloud (AWS WAF, Cloudflare) | Moyenne |
| TD-11 | Authentification Téléphone uniquement | Standard de l'industrie locale pour le MVP | Friction de connexion sans biométrie | Phishing de SMS | Ajout du support Passkeys et biométrie (FIDO2) | Basse |
| TD-12 | Pas de pipeline de backup automatisé complet | Focus sur le code MVP | Données vulnérables en cas de corruption grave | Perte de données irréversible | Mise en place de scripts de backup quotidiens (S3, chiffrés) | Critique |
