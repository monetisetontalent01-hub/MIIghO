# MÏÏghO : Flux Systèmes et Utilisateurs

Ce document illustre les principaux flux de l'écosystème MÏÏghO via des diagrammes de séquence Mermaid.

## 1. Inscription & Connexion

```mermaid
sequenceDiagram
    actor User
    participant App as Flutter App
    participant Auth as Auth API
    participant SMS as SMS Gateway
    
    User->>App: Saisit son numéro de téléphone
    App->>Auth: POST /auth/otp/send {phone}
    Auth->>SMS: Requête envoi SMS
    SMS-->>User: Reçoit le code (ex: 123456)
    Auth-->>App: 200 OK (OTP sent)
    User->>App: Saisit l'OTP
    App->>Auth: POST /auth/otp/verify {phone, code}
    Auth-->>App: 200 OK {access_token, refresh_token, is_new_user}
    
    alt is_new_user == true
        App->>User: Écran de création de profil
        User->>App: Remplit nom, avatar
        App->>Auth: PUT /users/me
    end
    App->>User: Affiche l'écran d'accueil
```

## 2. Envoi de message texte (Real-time)

```mermaid
sequenceDiagram
    actor Alice
    participant AppA as App (Alice)
    participant WS as WebSocket (Go)
    participant NATS as NATS JetStream
    participant DB as PostgreSQL
    participant AppB as App (Bob)
    actor Bob

    Alice->>AppA: Tape et envoie un message
    AppA->>AppA: Sauvegarde en SQLite (Statut: PENDING)
    AppA->>WS: Envoie frame Protobuf `SendMessage`
    WS->>DB: Sauvegarde le message (PARTITIONED)
    WS->>NATS: Publie event `message.sent`
    WS-->>AppA: `MessageAck` (Statut: SENT, coche unique)
    AppA->>AppA: MAJ SQLite (Statut: SENT)
    
    NATS-->>WS: Consomme event pour livraison
    WS->>AppB: Envoie frame `NewMessage`
    AppB->>AppB: Sauvegarde locale et affiche
    AppB-->>WS: Envoie frame `ReadReceipt` (Statut: DELIVERED)
    WS->>DB: Met à jour read_receipts
    WS->>AppA: Frame `StatusUpdate` (Statut: DELIVERED, double coche)
    AppB->>Bob: Notification ou mise à jour UI
    Bob->>AppB: Ouvre la conversation (lit le message)
    AppB-->>WS: Envoie `ReadReceipt` (Statut: READ)
    WS->>AppA: Frame `StatusUpdate` (Statut: READ, coche bleue)
```

## 3. Envoi de média (Image / Vidéo)

```mermaid
sequenceDiagram
    actor User
    participant App as Flutter App
    participant API as Media API
    participant MinIO as MinIO (S3)
    participant Worker as Media Worker

    User->>App: Sélectionne une image
    App->>App: Compression locale (Client-side)
    App->>API: POST /media/upload/request (taille, type)
    API-->>App: Retourne URL pré-signée S3 + media_id
    App->>MinIO: PUT binaire à l'URL pré-signée
    MinIO-->>App: 200 OK
    App->>API: POST /media/upload/complete {media_id}
    API->>Worker: Envoie tâche (Générer thumbnails, vérifier virus)
    Worker->>API: Tâche terminée
    App->>API: WebSocket `SendMessage` (inclut media_id en metadata)
```

## 4. Message Vocal

```mermaid
sequenceDiagram
    actor User
    participant App as Flutter App
    participant API as Media API
    participant S3 as MinIO

    User->>App: Maintient le bouton d'enregistrement
    App->>App: Enregistre et encode en Opus (.ogg)
    User->>App: Relâche le bouton
    App->>API: Demande d'URL d'upload
    API-->>App: Pré-signed URL
    App->>S3: Upload fichier vocal
    S3-->>App: Success
    App->>API: Notifie la complétion
    App->>API: WS `SendMessage` (type: AUDIO)
```

## 5. Synchronisation Offline

```mermaid
sequenceDiagram
    participant App as Flutter App
    participant DB as SQLite Local
    participant WS as WebSocket/API

    App->>App: L'app s'ouvre (sans internet)
    App->>DB: Lit les conversations/messages
    App->>User: Affiche l'UI locale
    
    User->>App: Envoie un message
    App->>DB: Insère (PENDING)
    
    Note over App, WS: Le réseau revient (Reconnexion)
    App->>WS: Connexion WSS
    App->>WS: Demande de synchro (last_sync_timestamp)
    WS-->>App: Envoie la liste des deltas (nouveaux messages)
    App->>DB: Applique les deltas
    App->>DB: Lit la file d'attente (messages PENDING)
    App->>WS: Envoie les messages PENDING (avec idempotency_key)
    WS-->>App: Confirme l'envoi
    App->>DB: Marque comme SENT
```

## 6. Réception de Notification Push

```mermaid
sequenceDiagram
    participant NATS
    participant NotifWorker as Notification Service
    participant FCM as Firebase/APNs
    participant OS as OS Mobile (Android/iOS)
    participant App as Flutter App

    NATS->>NotifWorker: Consomme `message.sent`
    NotifWorker->>NotifWorker: Vérifie si Bob est hors ligne
    NotifWorker->>FCM: POST Push Notification
    FCM->>OS: Délivre le push en arrière-plan
    OS->>OS: Affiche la notification (Badge/Bannière)
    actor Bob
    Bob->>OS: Tape sur la notification
    OS->>App: Lance l'app avec un deep link (conversation_id)
    App->>App: S'ouvre directement sur la conversation
```

## 7. Flux Futur : Paiement P2P (MÏÏghOPay)

```mermaid
sequenceDiagram
    actor Sender
    participant App
    participant Ledger as Ledger Core
    participant PSP as PSP Adapter (ex: Orange Money)
    actor Receiver

    Sender->>App: Envoie de l'argent (10$) à Receiver
    App->>Ledger: POST /payments/transfer {to, amount}
    Ledger->>Ledger: Vérifie le solde (SUM(CR)-SUM(DR))
    Ledger->>PSP: Requête d'initiation si funding externe requis
    PSP-->>Ledger: Webhook success
    Ledger->>Ledger: Création `journal_entry`
    Ledger->>Ledger: `ledger_postings`: DR Sender (-10), CR Receiver (+10)
    Ledger-->>App: Success
    Ledger->>Receiver: Notification "Vous avez reçu 10$"
```

## 8. Flux Futur : Chiffrement Bout-en-Bout (Signal Protocol)

```mermaid
sequenceDiagram
    actor Alice
    participant AppA as App Alice
    participant Server as Keyserver
    participant AppB as App Bob
    actor Bob

    Bob->>Server: Upload Pre-Key Bundle (Identity, Signed Pre-Key, One-Time Pre-Keys)
    Alice->>AppA: Veut écrire à Bob (premier message)
    AppA->>Server: Demande Pre-Key Bundle de Bob
    Server-->>AppA: Retourne Bundle
    AppA->>AppA: Protocole X3DH -> Génère clé partagée
    AppA->>AppA: Double Ratchet -> Chiffre le message
    AppA->>Server: Envoie Ciphertext (avec header X3DH)
    Server->>AppB: Distribue Ciphertext
    AppB->>AppB: Décapsule X3DH, dérive la clé, déchiffre
    AppB->>Bob: Affiche texte en clair
```
