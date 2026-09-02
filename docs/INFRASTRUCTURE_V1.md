# MÏÏghO — ARCHITECTURE & SPÉCIFICATIONS INFRASTRUCTURE V1

**Version :** 1.0.0  
**Statut :** Staging V1 Validé / Production Readiness  
**Date :** 02 Septembre 2026  
**Branche cible :** `main`

---

## 1. PHASAGE & OBJECTIFS

L'infrastructure MÏÏghO est structurée en 5 étapes rigoureuses et étanches :

```
┌─────────────────────────┐
│ 1. PRÉPARATION INFRA    │ -> Dockerfile, configs cloud, adaptateurs DSN/TLS, CI/CD
└───────────┬─────────────┘
            ▼
┌─────────────────────────┐
│ 2. PROVISIONING SERVICES│ -> Railway, Supabase PG, Upstash Redis, Cloudflare R2, Cloudflare DNS, Vercel
└───────────┬─────────────┘
            ▼
┌─────────────────────────┐
│ 3. DÉPLOIEMENT STAGING  │ -> Injection secrets staging, exécution migrations, build Release Flutter
└───────────┬─────────────┘
            ▼
┌─────────────────────────┐
│ 4. VALIDATION STAGING   │ -> Tests E2E réels (+243, +225, WS, Ledger, R2, restart, failure)
└───────────┬─────────────┘
            ▼
┌─────────────────────────┐
│ 5. PRODUCTION READINESS │ -> Runbook, plans de reprise, audit secrets, checklist de mise en service
└─────────────────────────┘
```

> [!IMPORTANT]
> **Clarification de périmètre :** Cette mission valide l'infrastructure **Staging V1**. La mise en ligne de la production publique fera l'objet d'une procédure de promotion dédiée conforme au [DEPLOYMENT_RUNBOOK.md](./DEPLOYMENT_RUNBOOK.md).

---

## 2. ARCHITECTURE TECHNIQUE GLOBALE

```
                                  INTERNET
                                     │
                                     ▼
                           ┌───────────────────┐
                           │    CLOUDFLARE     │
                           │  DNS / TLS / WAF  │
                           └─────────┬─────────┘
                                     │
                    ┌────────────────┴────────────────┐
                    │ HTTPS                           │ WSS / HTTPS
                    ▼                                 ▼
         ┌─────────────────────┐           ┌────────────────────┐
         │       VERCEL        │           │      RAILWAY       │
         │ Flutter Web Release │           │  Go API + WS (P1)  │
         │ (staging.miigho.com)│           │ (api-staging.miigho│
         └─────────────────────┘           └──────────┬─────────┘
                                                      │
         ┌─────────────────────────┬──────────────────┴──────────────────┐
         │                         │                                     │
         ▼                         ▼                                     ▼
┌──────────────────┐     ┌──────────────────┐                  ┌───────────────────┐
│     SUPABASE     │     │     UPSTASH      │                  │       NATS        │
│ PostgreSQL Managé│     │   Redis/Valkey   │                  │ JetStream Events  │
│ (Migrations & DB)│     │  (OTP, Présence) │                  │ (Private Network) │
└──────────────────┘     └──────────────────┘                  └───────────────────┘
         │
         ▼
┌──────────────────┐
│  CLOUDFLARE R2   │
│  S3 Object Store │
│  (Médias, Docs)  │
└──────────────────┘
```

---

## 3. FOURNISSEURS CLOUD & RESPONSABILITÉS

### 3.1 Frontend — Vercel
- **Rôle :** Hébergement et distribution CDN du frontend Flutter Web compilé en mode Release.
- **Règles :**
  - Aucune URL codée en dur (`localhost:8080` strictement absent du build Release).
  - Injection explicite des variables obligatoires à la compilation :
    - `--dart-define=API_URL=https://api-staging.miigho.com/api/v1`
    - `--dart-define=WS_URL=wss://api-staging.miigho.com/ws`
    - `--dart-define=ENVIRONMENT=staging`
  - Routage SPA configuré via [vercel.json](../vercel.json).

### 3.2 Backend Core — Railway
- **Rôle :** Exécution du container Docker Go API + WebSocket Hub.
- **Règles :**
  - Utilise le [Dockerfile](../backend/Dockerfile) multi-stage validé (`golang:alpine` builder + `alpine:3.20` runtime non-root `appuser`).
  - Écoute dynamique sur le port `$PORT` injecté par Railway.
  - Déploiement automatique sécurisé via GitHub sur push `main`.

### 3.3 Base de données — Supabase PostgreSQL
- **Rôle :** PostgreSQL managé pour les données persistantes et le Financial Ledger.
- **Règles strictes :**
  - Utilisé **exclusivement comme moteur PostgreSQL relationnel**.
  - **Interdiction formelle** de remplacer le métier applicatif par Supabase Auth, Supabase Realtime ou Edge Functions.
  - Exécution séquentielle des migrations SQL existantes (`000001` à `000015`).
  - Les migrations financières `000008` à `000015` et le modèle Ledger double-entry sont **strictement immuables**.

### 3.4 Cache & Données Éphémères — Upstash Redis
- **Rôle :** Stockage ultra-rapide des sessions OTP, compteurs de Rate Limiting, statuts de présence temps réel et cache.
- **Règles :**
  - Connexion chiffrée TLS via `rediss://...`.
  - **Interdiction formelle** d'utiliser Redis comme source de vérité financière ou de stocker des soldes de portefeuilles.
  - En cas de panne temporaire du cache, le Financial Ledger et les transactions restent 100% cohérents et intègres dans PostgreSQL.

### 3.5 Event Bus — NATS JetStream
- **Rôle :** Courtier de messages asynchrones et bus d'événements de domaine (diffusion des événements de chat, notifications, etc.).
- **Règles :**
  - Déployé en tant que service privé sur le réseau interne Railway ou instance légère dédiée.
  - Mode JetStream activé pour la persistance des flux.

### 3.6 Stockage Objets — Cloudflare R2
- **Rôle :** Stockage distribué compatible S3 pour les avatars utilisateurs, médias de chat (photos, vidéos, audios) et documents.
- **Règles :**
  - Accès **uniquement côté backend** via l'API standard S3 (`pkg/storage/s3.go`).
  - Utilisation d'URLs présignées (`PresignedPutObject` et `PresignedGetObject`) pour les transferts directs.
  - **Aucune clé d'accès R2 n'est exposée dans le client Flutter**.

### 3.7 DNS, TLS & Protection — Cloudflare
- **Rôle :** Gestion DNS, terminaison TLS 1.3, certificats SSL automatiques et protection DDoS.
- **Routage :**
  - `staging.miigho.com` → CNAME Vercel (Frontend Staging)
  - `api-staging.miigho.com` → CNAME Railway (Backend Staging API & WebSocket)
  - `miigho.com` & `api.miigho.com` → Réservés pour la Production future

---

## 4. HIÉRARCHIE ET PRIORITÉ DES CONFIGURATIONS

Le backend Go résout les variables d'environnement selon une hiérarchie stricte sans ambiguïté :

| Domaine | Priorité 1 (Cloud / Managé) | Priorité 2 (Intermédiaire) | Priorité 3 (Fallback Dev) |
| :--- | :--- | :--- | :--- |
| **Port d'écoute** | `$PORT` (Railway / Cloud) | `$SERVER_PORT` | `8080` |
| **PostgreSQL** | `$DATABASE_URL` (Supabase Pooler) | `$DB_HOST`, `$DB_PORT`, etc. | `localhost:5432` |
| **Cache / Redis** | `$VALKEY_URL` (Upstash TLS) | `$REDIS_URL` | `$VALKEY_ADDR` (`localhost:6379`) |
| **Storage (R2)** | `$MINIO_ENDPOINT` (`*.r2.cloudflarestorage.com`) | S3 compatible endpoint | `localhost:9000` |
| **CORS** | `$CORS_ALLOWED_ORIGINS` (liste stricte) | URLs locales développement | `*` interdit en production |

---

## 5. DISTINCTION PROBES : /health VS /ready

Pour une observabilité cloud sans risque financier :

1. **`/health` (Liveness Probe) :**
   - **Objectif :** Indiquer si le processus Go est vivant et capable de traiter des cycles HTTP.
   - **Comportement :** Réponse HTTP 200 immédiate sans appel à des dépendances externes.
   ```json
   {"status":"ok","system":"MÏÏghO OS Core","version":"1.0.0","timestamp":"2026-09-02T07:00:00Z"}
   ```

2. **`/ready` (Readiness Probe) :**
   - **Objectif :** Indiquer si l'instance est prête à recevoir du trafic utilisateur (dépendances critiques joignables).
   - **Comportement :** Effectue un simple ping réseau sur PostgreSQL (`pgPool.Ping()`) et sur Valkey/Redis (`valkeyClient.HealthCheck()`).
   - **Règle absolue :** **0 transaction ou opération Ledger** n'est exécutée lors du check.
   ```json
   {
     "status": "ready",
     "system": "MÏÏghO OS Core",
     "checks": {
       "database": "ok",
       "cache": "ok"
     },
     "timestamp": "2026-09-02T07:00:00Z"
   }
   ```

---

## 6. MATRICE DES SECRETS & ISOLATION DES ENVIRONNEMENTS

| Clé / Secret | Local | Staging | Production |
| :--- | :--- | :--- | :--- |
| `SERVER_MODE` | `development` | `staging` / `production` | `production` |
| `AUTH_JWT_SECRET` | `secret` (dev) | Chaîne aléatoire 64 hex (Staging) | Chaîne aléatoire 64 hex dédiée (Prod) |
| `DATABASE_URL` | `postgres://miigho:miigho_secret@localhost:5432/miigho_dev` | Supabase Staging DSN (Pooler Transaction) | Supabase Production DSN (Dédié) |
| `VALKEY_URL` | `localhost:6379` | `rediss://default:token@...upstash.io:6379` | `rediss://default:token@...upstash.io:6379` (Dédié) |
| `NATS_URL` | `nats://localhost:4222` | `nats://nats.railway.internal:4222` | `nats://nats.railway.internal:4222` |
| `MINIO_ENDPOINT` | `localhost:9000` | `<account_id>.r2.cloudflarestorage.com` | `<account_id>.r2.cloudflarestorage.com` |
| `MINIO_ACCESS_KEY` | `admin` | Cloudflare R2 Access Key Staging | Cloudflare R2 Access Key Prod |
| `MINIO_SECRET_KEY` | `password123` | Cloudflare R2 Secret Key Staging | Cloudflare R2 Secret Key Prod |
| `MINIO_USE_SSL` | `false` | `true` | `true` |
| `CORS_ALLOWED_ORIGINS` | `http://localhost:3000,...` | `https://staging.miigho.com` | `https://miigho.com,https://www.miigho.com` |
| `SMS_PROVIDER` | `mock` | `africas_talking` (Sandbox) | `africas_talking` / `twilio` (Live) |
| `SMS_API_KEY` | *(vide)* | Clé API Staging | Clé API Production |

---

## 7. MODÈLE DE COÛTS RÉELS PAR PALIERS DE CHARGE

Basé sur les tarifs publics officiels en vigueur (Septembre 2026) :

| Composant | Fournisseur / Tier | Palier A (0 – 100 users) | Palier B (100 – 1 000 users) | Palier C (1 000 – 10 000 users) |
| :--- | :--- | :--- | :--- | :--- |
| **Backend & NATS** | **Railway** (Base $5 + vCPU/RAM) | $5,00 / mois | $15,00 / mois | $50,00 / mois |
| **PostgreSQL** | **Supabase** (Free Tier 500MB / Pro $25) | $0,00 (Free) | $25,00 / mois (Pro) | $25,00 / mois + $10 storage |
| **Cache & OTP** | **Upstash Redis** (10k cmd/j gratuites) | $0,00 (Free) | $3,00 / mois | $15,00 / mois |
| **Médias & Docs** | **Cloudflare R2** (10GB gratuits + $0.015/GB) | $0,00 (Free) | $1,00 / mois | $10,00 / mois |
| **DNS, WAF, CDN** | **Cloudflare** (Free Plan) | $0,00 | $0,00 | $20,00 / mois (Plan Pro optionnel) |
| **Frontend Web** | **Vercel** (Hobby Gratuit / Pro $20) | $0,00 (Hobby) | $0,00 (Hobby) | $20,00 / mois (Pro) |
| **SMS OTP** | **Africa's Talking / Twilio** (~$0.02/SMS) | $2,00 / mois | $25,00 / mois | $200,00 / mois |
| **TOTAL ESTIMÉ** | | **~$7,00 / mois** | **~$69,00 / mois** | **~$350,00 / mois** |

---

## 8. SÉCURITÉ & AUDIT ANTI-FUITE

1. **Scan de secrets :** Le fichier `.gitignore` protège rigoureusement `.env`, `.env.*`, `server.log`, les builds et les certificats locaux.
2. **Aucun secret dans le client Flutter :** Le bundle Web ne contient que les URL d'API publiques (`API_URL`, `WS_URL`). Les clés S3/R2, SMS, Base de données et PSP sont conservées exclusivement sur le serveur Railway.
3. **CORS strict :** Aucune requête avec origine sauvage `*` n'est acceptée en staging/production.
