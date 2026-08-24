# MÏÏghO : Contrats API

Ce document décrit les spécifications des API REST et WebSocket pour MÏÏghO.

## 1. Conventions API

- **Base URL** : `https://api.miigho.com/api/v1`
- **Format** : Toutes les requêtes et réponses utilisent `application/json` (sauf l'upload de médias).
- **Authentification** : `Authorization: Bearer <access_token>`
- **Pagination** : Pagination par curseur. Paramètres `?cursor=xyz&limit=50`. Les réponses incluent un champ `next_cursor`.
- **Erreurs** : Format standard :
  ```json
  {
    "error": {
      "code": "VALIDATION_FAILED",
      "message": "Le numéro de téléphone est invalide.",
      "details": { "phone": "format_invalid" }
    }
  }
  ```

## 2. Auth Endpoints

### Demander OTP
`POST /auth/otp/send`
- **Auth Requis** : Non
- **Body** : `{ "phone_number": "+243xxxxxxxxx" }`
- **Response** : `200 OK` `{ "status": "sent", "expires_in": 120 }`

### Vérifier OTP
`POST /auth/otp/verify`
- **Auth Requis** : Non
- **Body** : `{ "phone_number": "+243xxxxxxxxx", "code": "123456", "device_id": "uuid" }`
- **Response** : `200 OK` `{ "access_token": "jwt...", "refresh_token": "opaque...", "is_new_user": false }`

### Refresh Token
`POST /auth/token/refresh`
- **Auth Requis** : Non (utilise le refresh_token en body)
- **Body** : `{ "refresh_token": "opaque..." }`
- **Response** : `200 OK` `{ "access_token": "jwt...", "refresh_token": "new_opaque..." }`

### Logout
`POST /auth/logout` (Logout device actuel)
`POST /auth/logout/all` (Logout toutes les sessions)
- **Auth Requis** : Oui

### Supprimer Compte
`DELETE /auth/account`
- **Auth Requis** : Oui

## 3. User Endpoints

### Profil Actuel
`GET /users/me`
- **Response** : `{ "id": "uuid", "phone_number": "...", "first_name": "...", "last_name": "...", "avatar_url": "...", "status_message": "..." }`

`PUT /users/me`
- **Body** : `{ "first_name": "...", "last_name": "...", "status_message": "..." }`

`PUT /users/me/avatar`
- **Body** : FormData avec fichier image.

### Profil Public
`GET /users/:id`
- **Response** : `{ "id": "uuid", "first_name": "...", "last_name": "...", "avatar_url": "...", "status_message": "..." }`

### Recherche
`GET /users/search?phone=+243...`
- **Response** : `{ "user": { ...profil } }`

## 4. Contact Endpoints

- `GET /contacts` : Récupère la liste des contacts (paginée).
- `POST /contacts/sync` : Body: `{ "phone_numbers": ["+123", "+456"] }`. Retourne les UUIDs et profils existants.
- `POST /contacts/:userId/block` : Bloquer un utilisateur.
- `DELETE /contacts/:userId/block` : Débloquer.
- `POST /contacts/:userId/favorite` : Mettre en favori.

## 5. Conversation Endpoints

- `GET /conversations` : Liste les conversations triées par activité récente.
- `POST /conversations` : Body `{ "type": "direct", "participants": ["uuid"] }` ou `{ "type": "group", "name": "...", "participants": ["uuid1", "uuid2"] }`.
- `GET /conversations/:id` : Détails (membres, métadonnées).
- `PUT /conversations/:id` : Mettre à jour groupe (nom, avatar).
- `DELETE /conversations/:id` : Supprimer (ou quitter) la conversation.

## 6. Message Endpoints (REST Fallback)
La messagerie se fait idéalement via WebSocket. Le REST est utilisé pour la pagination hors ligne ou comme fallback.

- `GET /conversations/:id/messages?cursor=&limit=`
- `POST /conversations/:id/messages` : Body `{ "type": "text", "content": "Hello", "reply_to": null }`
- `PUT /messages/:id` : Éditer un message.
- `DELETE /messages/:id` : Supprimer (soft delete ou retrait).
- `POST /messages/:id/reactions` : Body `{ "emoji": "👍" }`
- `DELETE /messages/:id/reactions/:emoji`

## 7. Group Endpoints

- `POST /groups` : Créer un groupe (identique à POST /conversations).
- `GET /groups/:id/members` : Lister les membres.
- `POST /groups/:id/members` : Ajouter des membres (Admin seulement).
- `DELETE /groups/:id/members/:userId` : Expulser.
- `PUT /groups/:id/members/:userId/role` : Assigner le rôle admin.
- `POST /groups/:id/leave` : Quitter le groupe.

## 8. Media Endpoints

### Obtenir une URL de téléchargement pré-signée
`POST /media/upload/request`
- **Body** : `{ "content_type": "image/jpeg", "size_bytes": 102400 }`
- **Response** : `{ "upload_url": "https://s3...", "media_id": "uuid", "expires_in": 3600 }`

### Confirmer l'upload
`POST /media/upload/complete`
- **Body** : `{ "media_id": "uuid" }`
- **Response** : `{ "status": "processing" }`

### Récupérer le média (si pas public)
`GET /media/:id`
- Redirige vers une URL pré-signée S3 en lecture.

## 9. Protocol WebSocket (WSS)

- **Endpoint** : `wss://api.miigho.com/ws`
- **Auth** : Query param ou initial frame avec le token.
- **Format** : Binaire encodé en **Protobuf**.

### Types de messages WSS :
1. `SendMessage` (Client -> Serveur) : Contient l'ID de la conversation, type, contenu (chiffré).
2. `MessageAck` (Serveur -> Client) : Accuse réception (attribue l'ID final au message ou confirme la persistance).
3. `TypingIndicator` (Client <-> Serveur) : Indicateur "en train de taper...".
4. `PresenceUpdate` (Client <-> Serveur) : Statut (en ligne, hors ligne, vu pour la dernière fois).
5. `MessageReaction` (Client <-> Serveur) : Ajout/Retrait d'emoji.
6. `ReadReceipt` (Client <-> Serveur) : Marquer un message comme "lu" ou "distribué" (double coche).
7. `NewMessage` (Serveur -> Client) : Distribution d'un message entrant.
8. `StatusUpdate` (Serveur -> Client) : Changement d'état d'un message (envoyé -> livré -> lu).
9. `Error` (Serveur -> Client) : Notification d'erreur WS.

### Heartbeat
Un mécanisme de **Ping/Pong** est requis toutes les 30 secondes. Si 3 pings sont manqués, la connexion se ferme, déclenchant la stratégie de reconnexion exponentielle sur le client Flutter.
