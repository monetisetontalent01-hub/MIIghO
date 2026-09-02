# MÏÏghO — RUNBOOK OPÉRATIONNEL DE DÉPLOIEMENT STAGING & PRODUCTION

**Document :** Guide opérationnel et procédures d'exploitation  
**Version :** 1.0.0  
**Date :** 02 Septembre 2026

---

## 1. GUIDE OPÉRATIONNEL DE PROVISIONING (Étape par étape)

### 1.1 Base de données — Supabase PostgreSQL
1. Créer un projet Supabase dédié à l'environnement (`miigho-staging`).
2. Récupérer l'URL de connexion du **Transaction Connection Pooler** (port 6543) ou la connexion directe (port 5432).
3. Configurer les paramètres de connexion :
   - Format : `postgres://postgres.[PROJECT-REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres?sslmode=require`
4. Exécuter la séquence ordonnée des migrations existantes :
   ```bash
   export DATABASE_URL="postgres://postgres.[REF]:[PASS]@[HOST]:6543/postgres?sslmode=require"
   # Via l'outil de migration standard ou CLI migrate :
   migrate -path backend/migrations -database "$DATABASE_URL" up
   ```
5. Vérifier que les 15 migrations sont appliquées avec succès :
   - `000001_create_extensions`
   - `000002_create_users`
   - `000003_create_auth`
   - `000004_create_contacts`
   - `000005_create_conversations`
   - `000006_create_messages`
   - `000007_create_media`
   - `000008_create_ledger` **(Immuable - Double-entry Financial Core)**
   - `000009_harden_ledger_schema` **(Immuable)**
   - `000010_create_business_core` **(Immuable)**
   - `000011_create_merchant_payments` **(Immuable)**
   - `000012_create_refunds` **(Immuable)**
   - `000013_create_settlements` **(Immuable)**
   - `000014_create_fees` **(Immuable)**
   - `000015_create_psp_transactions` **(Immuable)**

### 1.2 Cache & Données Éphémères — Upstash Redis
1. Créer une base de données Redis managée (`miigho-staging-cache`) sur Upstash.
2. Activer TLS (obligatoire).
3. Récupérer l'URL de connexion chiffrée :
   - Format : `rediss://default:[TOKEN]@[ENDPOINT].upstash.io:6379`
4. Injecter dans la variable d'environnement `VALKEY_URL`.

### 1.3 Event Bus — NATS JetStream (Railway Private Service)
1. Dans le projet Railway Staging, ajouter un service depuis l'image Docker officielle `nats:2.10`.
2. Définir la commande de démarrage : `-js -m 8222` (JetStream activé).
3. Connecter le service sur le réseau privé Railway (`nats.railway.internal:4222`).
4. Définir `NATS_URL=nats://nats.railway.internal:4222` sur le service backend.

### 1.4 Stockage Objets — Cloudflare R2
1. Dans le dashboard Cloudflare, créer un bucket R2 nommé `miigho-media-staging`.
2. Générer un jeu de clés API R2 (S3 API tokens) avec droits de lecture/écriture.
3. Noter les identifiants :
   - `MINIO_ENDPOINT` : `<ACCOUNT_ID>.r2.cloudflarestorage.com`
   - `MINIO_ACCESS_KEY` : `<R2_ACCESS_KEY_ID>`
   - `MINIO_SECRET_KEY` : `<R2_SECRET_ACCESS_KEY>`
   - `MINIO_BUCKET_NAME` : `miigho-media-staging`
   - `MINIO_USE_SSL` : `true`

### 1.5 Backend API Core — Railway
1. Connecter le repository GitHub `projet-waza` à Railway.
2. Configurer le service backend avec le répertoire racine `/backend` (utilise [Dockerfile](../backend/Dockerfile)).
3. Injecter les variables d'environnement Staging dans le Dashboard Railway :
   - `SERVER_MODE=production` (ou `staging`)
   - `AUTH_JWT_SECRET=<SECRET_ALEATOIRE_64_HEX>`
   - `DATABASE_URL=<SUPABASE_POOLER_URL>`
   - `VALKEY_URL=<UPSTASH_REDISS_URL>`
   - `NATS_URL=nats://nats.railway.internal:4222`
   - `MINIO_ENDPOINT=<ACCOUNT_ID>.r2.cloudflarestorage.com`
   - `MINIO_ACCESS_KEY=<R2_KEY>`
   - `MINIO_SECRET_KEY=<R2_SECRET>`
   - `MINIO_BUCKET_NAME=miigho-media-staging`
   - `MINIO_USE_SSL=true`
   - `CORS_ALLOWED_ORIGINS=https://staging.miigho.com`
   - `SMS_PROVIDER=africas_talking` (ou sandbox)
   - `SMS_API_KEY=<KEY>`
4. Déployer et vérifier que Railway assigne le domaine interne/public et que `/health` et `/ready` retournent `HTTP 200`.

### 1.6 DNS & Routage — Cloudflare
1. Configurer l'enregistrement CNAME :
   - `api-staging.miigho.com` → CNAME vers l'URL Railway (`[service].up.railway.app`)
   - Activer le Proxy Cloudflare (nuage orange) pour TLS et protection DDoS.
   - S'assurer que les WebSockets sont activés (Cloudflare Network Settings).

### 1.7 Frontend Web — Vercel
1. Connecter le repository sur Vercel.
2. Configurer les paramètres de build :
   - **Framework Preset :** Other
   - **Build Command :** `cd app && flutter build web --release --dart-define=API_URL=https://api-staging.miigho.com/api/v1 --dart-define=WS_URL=wss://api-staging.miigho.com/ws --dart-define=ENVIRONMENT=staging`
   - **Output Directory :** `app/build/web`
3. Assigner le domaine personnalisé `staging.miigho.com`.

---

## 2. PROCÉDURES DE SAUVEGARDE & RESTAURATION POSTGRESQL

### 2.1 Procédure de Backup Quotidien / Avant Déploiement
```bash
# Sauvegarde intégrale de la base de données PostgreSQL
pg_dump "$DATABASE_URL" \
  --format=custom \
  --no-owner \
  --no-privileges \
  --file="miigho_backup_$(date +%Y%m%d_%H%M%S).dump"
```

### 2.2 Procédure de Restauration en Staging (Test de Restauration)
```bash
# Restauration dans une base de staging propre ou bac à sable
pg_restore \
  --dbname="$STAGING_DATABASE_URL" \
  --clean \
  --if-exists \
  --no-owner \
  "miigho_backup_YYYYMMDD_HHMMSS.dump"

# Vérification post-restauration de l'intégrité du Ledger
psql "$STAGING_DATABASE_URL" -c "
  SELECT count(*) as total_accounts FROM accounts;
  SELECT count(*) as total_transactions FROM transactions;
  SELECT count(*) as total_journal_entries FROM journal_entries;
"
```

---

## 3. GESTION DES ROLLBACKS : APPLICATIF VS MIGRATION DB

> [!CAUTION]
> **Règle vitale sur les rollbacks :** Ne jamais confondre un rollback applicatif et un rollback de base de données. Les tables financières du Ledger ne doivent jamais être tronquées ou supprimées à la légère.

### 3.1 Rollback Applicatif (Fréquent & Sans Risque DB)
- **Quand l'utiliser :** En cas de régression logicielle (bug d'affichage Flutter, erreur 500 sur un endpoint non-DB, etc.).
- **Procédure :**
  1. **Railway (Backend) :** Dans l'onglet *Deployments*, cliquer sur le déploiement précédent sain et choisir **Redeploy** (ou `git revert HEAD`).
  2. **Vercel (Frontend) :** Dans l'onglet *Deployments*, promouvoir l'instantinstané (Instant Rollback) de la version précédente en 1 clic.
  3. **Impact DB :** 0 modification sur la base de données.

### 3.2 Rollback de Migration DB (Exceptionnel & Hautement Contrôlé)
- **Quand l'utiliser :** Uniquement si une migration de structure DDL nouvellement appliquée échoue ou crée un blocage avant la mise en production de données réelles.
- **Règles :**
  - Les migrations financières `000008` à `000015` **sont immuables en production**.
  - Si un rollback est requis sur une migration non-financière en staging :
    ```bash
    # Revenir d'exactement 1 étape de migration
    migrate -path backend/migrations -database "$DATABASE_URL" down 1
    ```
  - En cas d'anomalie sur des données financières, **ne jamais exécuter un `DROP TABLE`** : appliquer une migration corrective additive en avant (*forward-only fix*).

---

## 4. CHECKLIST DE VALIDATION STAGING AVANT PROMOTION PRODUCTION

- [ ] **Probes :**
  - `GET https://api-staging.miigho.com/health` → HTTP 200 OK (`{"status":"ok"}`)
  - `GET https://api-staging.miigho.com/ready` → HTTP 200 OK (`{"status":"ready","checks":{"database":"ok","cache":"ok"}}`)
- [ ] **WebSocket :**
  - Connexion `wss://api-staging.miigho.com/ws?token=...` établie avec succès via Cloudflare WSS.
- [ ] **E2E Authentification :**
  - Envoi et validation OTP réels (+243 RDC et +225 Côte d'Ivoire).
  - Rotation de tokens JWT et rafraîchissement concurrent vérifiés.
- [ ] **E2E Chat & Médias :**
  - Échange de messages texte en direct A ↔ B.
  - Upload média vers Cloudflare R2 et téléchargement via URL signée.
- [ ] **Financial Ledger :**
  - Vérification des écritures en partie double et calcul des soldes à partir des écritures de journal (zéro corruption).
- [ ] **Résilience & Restart :**
  - Redémarrage du container Railway : reconnexion automatique du WebSocket client et continuité des données.
