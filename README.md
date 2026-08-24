# MÏÏghO - Écosystème Numérique Panafricain

MÏÏghO est une super-app innovante (messagerie, paiements, marketplace, cloud, IA) destinée au marché africain. Elle vise à unifier la communication, la finance et le commerce sous une même identité numérique sécurisée, performante et adaptée aux contraintes locales de connectivité.

## Architecture

Le backend est conçu comme un **monolithe modulaire** en **Go** reposant sur une Architecture Hexagonale et les principes du Domain-Driven Design (DDD). 
L'application client est construite avec **Flutter**.
- **Base de données** : PostgreSQL (ACID)
- **Cache & Présence** : Valkey
- **Stockage de médias** : MinIO
- **Bus d'événements** : NATS JetStream

Consultez le dossier `docs/` pour une vue détaillée de l'architecture et des spécifications de sécurité.

## Prérequis

- [Go](https://golang.org/doc/install) (1.22+)
- [Flutter](https://docs.flutter.dev/get-started/install) (3.x)
- [Docker & Docker Compose](https://docs.docker.com/get-docker/)
- Protobuf (`protoc` et les plugins Go associés)

## Démarrage Rapide

1. Copier le fichier d'environnement :
   ```bash
   cp .env.example .env
   ```

2. Démarrer l'infrastructure et le serveur en mode développement :
   ```bash
   make dev
   ```

3. Exécuter les migrations de base de données :
   ```bash
   make migrate-up
   ```

## Structure du Projet

- `backend/` : Code source Go (API, Domain, Infrastructure).
- `app/` : Code source Flutter/Dart.
- `proto/` : Définitions Protobuf pour les WebSockets et gRPC.
- `docs/` : Documentation technique et d'architecture.
- `deploy/` : Fichiers de déploiement (Dockerfiles, manifestes K8s).
- `migrations/` : Scripts de migration SQL.

## Contribution

Les guidelines de contribution seront ajoutées prochainement.

## Licence

Tous droits réservés. (Détails de licence à venir).
